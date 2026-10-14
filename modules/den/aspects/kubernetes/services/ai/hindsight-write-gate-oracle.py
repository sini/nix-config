"""Oracle for hindsight-write-gate.py, run against hindsight-api-slim at v0.9.2.

Drives every mutating bank route of the real FastAPI app (create_app) over a real
MemoryEngine (mock LLM, constant embeddings, a Postgres with pgvector), with the gate
loaded by upstream's own loader from HINDSIGHT_API_OPERATION_VALIDATOR_*.

  a  every mutating route on a gated bank: no key and another bank's key are refused
     by the gate, the bank's own key is not
  b  recall, reflect and every GET route on a gated bank pass without a key
  c  every mutating route on an ungated bank passes the gate without a key
  d  a gated bank whose token file is empty or missing stops the loader and the
     `hindsight-api` entrypoint; valid files load

Run (no live server; DATABASE_URL is a throwaway local Postgres with pgvector):
  HINDSIGHT_API_DATABASE_URL=postgresql://... \
    <venv with hindsight-api-slim==0.9.2>/bin/python hindsight-write-gate-oracle.py <dir holding hindsight_write_gate.py>
Exit 0 iff every cell passes.
"""

import asyncio
import collections
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

GATE_DIR = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(GATE_DIR))

TOKENS = {
    "genie": "tok-genie-0123456789abcdef",
    "genie-memory": "tok-genie-memory-fedcba9876543210",
}
GATED, OTHER, OPEN = "genie", "genie-memory", "den-law"
REFUSAL = "write-gated"

tokdir = Path(tempfile.mkdtemp(prefix="hswg-tokens-"))
for bank, tok in TOKENS.items():
    (tokdir / bank).write_text(tok + "\n")
GATE_ENV = {
    "HINDSIGHT_API_OPERATION_VALIDATOR_EXTENSION": "hindsight_write_gate:WriteGate",
    "HINDSIGHT_API_OPERATION_VALIDATOR_BANKS": ",".join(TOKENS),
    "HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR": str(tokdir),
}
os.environ.update(GATE_ENV)
os.environ.setdefault("HINDSIGHT_API_CONSOLIDATION_RECONCILE_INTERVAL_SECONDS", "0")
os.environ.setdefault("HINDSIGHT_API_MENTAL_MODEL_REFRESH_TICK_SECONDS", "0")
os.environ.setdefault("HINDSIGHT_API_LLM_TRACE_RETENTION_DAYS", "-1")
# As deployed: document import reaches no write hook on an existing bank, so it is off.
os.environ.setdefault("HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API", "false")

import httpx
from hindsight_api import MemoryEngine, RequestContext
from hindsight_api.api import create_app
from hindsight_api.engine.cross_encoder import RRFPassthroughCrossEncoder
from hindsight_api.engine.embeddings import Embeddings
from hindsight_api.engine.query_analyzer import DateparserQueryAnalyzer
from hindsight_api.engine.task_backend import SyncTaskBackend
from hindsight_api.extensions import OperationValidatorExtension
from hindsight_api.extensions.loader import ExtensionLoadError, load_extension


class ConstEmbeddings(Embeddings):
    provider_name = "const"
    dimension = 384

    async def initialize(self):
        pass

    def encode(self, texts):
        return [[(i % 7 + 1) / 10.0 for i in range(384)] for _ in texts]


FAILS: list[str] = []
COUNTS: dict[str, int] = {}


def cell(name, ok, detail=""):
    COUNTS[name] = COUNTS.get(name, 0) + 1
    if not ok:
        FAILS.append(f"{name}: {detail}")
        print(f"FAIL {name}: {detail}")


def refused(r):
    # Closed by configuration (the deployment sets the import API off) or by upstream
    # (the deprecated entity route answers 410 to everyone).
    if r.status_code == 404 and "Document import API is disabled" in r.text:
        return True
    if r.status_code == 410:
        return True
    # The gate's reason, whatever status the route maps it to: the webhook routes do not
    # catch OperationValidationError and answer 500, with nothing written.
    return r.status_code >= 400 and REFUSAL in r.text


def hdr(tok):
    return {"Authorization": f"Bearer {tok}"} if tok else {}


ARCHIVE: dict[str, bytes] = {}


async def export_archive(mem):
    """A real transfer archive: one document exported from an ungated scratch bank."""
    rc = RequestContext()
    src = "hswg-transfer-src"
    await mem.retain_async(
        bank_id=src, content="Erin builds boats.", document_id="t1", request_context=rc
    )
    sub = await mem.submit_export_documents_async(src, rc)
    st = await mem.get_operation_status(src, sub["operation_id"], request_context=rc)
    ARCHIVE["zip"] = await mem._file_storage.retrieve(
        st["result_metadata"]["storage_key"]
    )
    await mem.delete_bank(src, request_context=rc)


async def fixture(c, bank, tok):
    """Create the bank and one of every object a write route can name. Returns path params."""
    h = hdr(tok)
    ids = {"entity_id": "e0"}
    (await c.put(f"/v1/default/banks/{bank}", json={}, headers=h)).raise_for_status()
    (
        await c.post(
            f"/v1/default/banks/{bank}/memories",
            json={
                "items": [
                    {"content": "Alice moved to Paris in 2020.", "document_id": "doc1"}
                ]
            },
            headers=h,
        )
    ).raise_for_status()
    ids["document_id"] = "doc1"
    # An editable unit: PATCH refuses observations.
    items = []
    for t in ("world", "experience"):
        items += (
            await c.get(f"/v1/default/banks/{bank}/memories/list?type={t}", headers=h)
        ).json()["items"]
    ids["memory_id"] = items[0]["id"]
    r = await c.post(
        f"/v1/default/banks/{bank}/directives",
        json={"name": "d", "content": "be brief"},
        headers=h,
    )
    r.raise_for_status()
    ids["directive_id"] = r.json()["id"]
    r = await c.post(
        f"/v1/default/banks/{bank}/mental-models",
        json={"name": "m", "source_query": "where is alice"},
        headers=h,
    )
    r.raise_for_status()
    mms = (await c.get(f"/v1/default/banks/{bank}/mental-models", headers=h)).json()
    ids["mental_model_id"] = mms["items"][0]["id"]
    r = await c.post(
        f"/v1/default/banks/{bank}/knowledge-base/folders",
        json={"name": "f"},
        headers=h,
    )
    r.raise_for_status()
    ids["node_id"] = r.json()["id"]
    r = await c.post(
        f"/v1/default/banks/{bank}/webhooks",
        json={"url": "https://example.com/hook"},
        headers=h,
    )
    r.raise_for_status()
    ids["webhook_id"] = r.json()["id"]
    r = await c.post(
        f"/v1/default/banks/{bank}/memories",
        json={"items": [{"content": "Bob lives in Rome."}], "async": True},
        headers=h,
    )
    r.raise_for_status()
    ids["operation_id"] = r.json()["operation_id"]
    return ids


BODIES = {
    ("POST", "/memories/dry-run-extract"): {"content": "x"},
    ("PATCH", "/memories/{memory_id}"): {"text": "y"},
    ("POST", "/mental-models"): {"name": "m2", "source_query": "q"},
    ("PATCH", "/mental-models/{mental_model_id}"): {"name": "m3"},
    ("POST", "/knowledge-base/folders"): {"name": "f2"},
    ("POST", "/knowledge-base/pages"): {"name": "p", "source_query": "q"},
    ("PATCH", "/knowledge-base/nodes/{node_id}"): {"name": "f3"},
    ("POST", "/directives"): {"name": "d2", "content": "c"},
    ("PATCH", "/directives/{directive_id}"): {"content": "c2"},
    ("PATCH", "/documents/{document_id}"): {"tags": ["t"]},
    ("PUT", "/profile"): {
        "disposition": {"skepticism": 3, "literalism": 3, "empathy": 3}
    },
    ("POST", "/background"): {"content": "bg"},
    ("PUT", ""): {"mission": "m"},
    ("PATCH", ""): {"mission": "m"},
    ("PATCH", "/config"): {"updates": {"retain_mission": "x"}},
    ("POST", "/consolidate"): {},
    ("POST", "/webhooks"): {"url": "https://example.com/hook2"},
    ("PATCH", "/webhooks/{webhook_id}"): {"url": "https://example.com/hook3"},
    ("POST", "/memories"): {"items": [{"content": "Carol likes tea."}]},
    ("POST", "/import"): {
        "version": "1",
        "bank": {"retain_mission": "x"},
        "directives": [{"name": "d9", "content": "c"}],
    },
    ("POST", "/memories/recall"): {"query": "alice"},
    ("POST", "/reflect"): {"query": "alice"},
}

# Routes whose effect is a read, so they are not write-gated (b covers them).
# dry-run-refresh is not here: it reaches only validate_mental_model_refresh, the hook the
# real refresh uses, so it is gated with it.
READ_POSTS = {
    "/memories/recall",
    "/reflect",
    "/memories/dry-run-extract",
    "/health/llm",
    "/document-transfer/export",
}
# Mutating routes closed to every caller, keyed or not: document import by the deployment's
# HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API=false, the entity route by upstream (410).
CLOSED = {"/document-transfer", "/entities/{entity_id}/regenerate"}


async def call(c, verb, suffix, bank, ids, tok):
    url = f"/v1/default/banks/{bank}" + suffix.format_map(
        collections.defaultdict(lambda: "x0", ids)
    ).replace("{document_id:path}", ids["document_id"])
    h = hdr(tok)
    if suffix == "/document-transfer":
        return await c.post(
            url, files={"file": ("t.zip", ARCHIVE["zip"], "application/zip")}, headers=h
        )
    if suffix == "/files/retain":
        return await c.post(
            url,
            files={"files": ("a.txt", b"Dana plays chess.", "text/plain")},
            data={"request": json.dumps({"files_metadata": [{}]})},
            headers=h,
        )
    body = BODIES.get((verb, suffix))
    return await c.request(verb, url, json=body, headers=h)


def bank_routes(app):
    out = []
    pre = "/v1/default/banks/{bank_id}"
    for r in app.routes:
        p = getattr(r, "path", "")
        if not p.startswith(pre):
            continue
        for m in sorted(getattr(r, "methods", ()) or ()):
            if m in ("HEAD", "OPTIONS"):
                continue
            out.append(
                (m, p[len(pre) :].replace("{document_id:path}", "{document_id}"))
            )
    return out


async def engine(db_url):
    mem = MemoryEngine(
        db_url=db_url,
        memory_llm_provider="mock",
        memory_llm_api_key="",
        memory_llm_model="mock",
        embeddings=ConstEmbeddings(),
        cross_encoder=RRFPassthroughCrossEncoder(),
        query_analyzer=DateparserQueryAnalyzer(),
        pool_min_size=1,
        pool_max_size=10,
        run_migrations=True,
        task_backend=SyncTaskBackend(),
    )
    await mem.initialize()
    return mem


async def routes_cells():
    gate = load_extension("OPERATION_VALIDATOR", OperationValidatorExtension)
    assert gate is not None and type(gate).__name__ == "WriteGate", gate
    mem = await engine(os.environ["HINDSIGHT_API_DATABASE_URL"])
    await export_archive(mem)
    mem._operation_validator = gate
    app = create_app(mem, initialize_memory=False)
    routes = bank_routes(app)
    writes = [(v, s) for v, s in routes if v != "GET" and s not in READ_POSTS]
    gets = [(v, s) for v, s in routes if v == "GET"]
    print(
        f"routes: bank-scoped={len(routes)} write={len(writes)} read-post={len(READ_POSTS)} get={len(gets)}"
    )
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://t"
    ) as c:
        for b in (GATED, OTHER, OPEN):
            await c.delete(f"/v1/default/banks/{b}", headers=hdr(TOKENS.get(b)))

        # a: gated bank, one fresh fixture per route so a destructive call cannot mask the next
        for verb, suffix in writes:
            ids = await fixture(c, GATED, TOKENS[GATED])
            for label, tok in (("none", None), ("other", TOKENS[OTHER])):
                r = await call(c, verb, suffix, GATED, ids, tok)
                cell(
                    "a.refused",
                    refused(r),
                    f"{verb} {suffix} key={label} -> {r.status_code} {r.text[:160]}",
                )
            r = await call(c, verb, suffix, GATED, ids, TOKENS[GATED])
            print(
                f"own-key {r.status_code} {verb} {suffix}"
                + (f" {r.text[:120]}" if r.status_code >= 400 else "")
            )
            if suffix in CLOSED:
                cell(
                    "a.closed",
                    refused(r),
                    f"{verb} {suffix} key=own -> {r.status_code} {r.text[:160]}",
                )
            else:
                cell(
                    "a.allowed",
                    not refused(r),
                    f"{verb} {suffix} key=own -> {r.status_code} {r.text[:160]}",
                )
            await c.delete(f"/v1/default/banks/{GATED}", headers=hdr(TOKENS[GATED]))

        # b: reads on the gated bank need no key
        ids = await fixture(c, GATED, TOKENS[GATED])
        r = await call(c, "POST", "/memories/recall", GATED, ids, None)
        cell(
            "b.recall",
            r.status_code == 200,
            f"recall -> {r.status_code} {r.text[:160]}",
        )
        for verb, suffix in gets + [("POST", s) for s in sorted(READ_POSTS)]:
            r = await call(c, verb, suffix, GATED, ids, None)
            cell(
                "b.read",
                REFUSAL not in r.text,
                f"{verb} {suffix} -> {r.status_code} {r.text[:160]}",
            )
        await c.delete(f"/v1/default/banks/{GATED}", headers=hdr(TOKENS[GATED]))

        # c: an ungated bank takes every write without a key
        for verb, suffix in writes:
            try:
                ids = await fixture(c, OPEN, None)
            except httpx.HTTPStatusError as e:
                cell(
                    "c.open",
                    False,
                    f"fixture on {OPEN}: {e.response.status_code} {e.response.text[:160]}",
                )
                continue
            r = await call(c, verb, suffix, OPEN, ids, None)
            if suffix in CLOSED:
                cell(
                    "c.closed",
                    refused(r),
                    f"{verb} {suffix} -> {r.status_code} {r.text[:160]}",
                )
            else:
                cell(
                    "c.open",
                    not refused(r),
                    f"{verb} {suffix} -> {r.status_code} {r.text[:160]}",
                )
            await c.delete(f"/v1/default/banks/{OPEN}")
        ids = await fixture(c, OPEN, None)
        r = await call(c, "POST", "/memories", OPEN, ids, None)
        cell(
            "c.retain",
            r.status_code == 200,
            f"retain -> {r.status_code} {r.text[:160]}",
        )
        await c.delete(f"/v1/default/banks/{OPEN}")
    await mem.close()
    return writes


def startup_cells():
    def load(env):
        saved = dict(os.environ)
        os.environ.update(env)
        try:
            load_extension("OPERATION_VALIDATOR", OperationValidatorExtension)
            return None
        except ExtensionLoadError as e:
            return str(e)
        finally:
            os.environ.clear()
            os.environ.update(saved)

    cell("d.valid-loads", load({}) is None, "valid token files refused to load")
    empty = Path(tempfile.mkdtemp(prefix="hswg-empty-"))
    (empty / "genie").write_text("\n")
    (empty / "genie-memory").write_text("x\n")
    err = load({"HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR": str(empty)})
    cell("d.empty-refused", err is not None, "empty token file loaded")
    missing = Path(tempfile.mkdtemp(prefix="hswg-missing-"))
    (missing / "genie").write_text("x\n")
    err = load({"HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR": str(missing)})
    cell("d.missing-refused", err is not None, "missing token file loaded")

    # The real entrypoint: `hindsight-api` must exit non-zero on the empty file.
    exe = Path(sys.executable).with_name("hindsight-api")
    env = dict(
        os.environ,
        PYTHONPATH=str(GATE_DIR),
        HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR=str(empty),
    )
    p = subprocess.run(
        [str(exe)], env=env, capture_output=True, text=True, timeout=120, check=False
    )
    cell(
        "d.entrypoint-refuses",
        p.returncode != 0 and "empty token file" in (p.stdout + p.stderr),
        f"rc={p.returncode} tail={(p.stdout + p.stderr)[-300:]}",
    )


async def main():
    writes = await routes_cells()
    startup_cells()
    print("cells:", json.dumps(COUNTS, sort_keys=True))
    print(f"write routes covered: {len(writes)}")
    print(f"FAILED {len(FAILS)}" if FAILS else "ALL PASS")
    sys.exit(1 if FAILS else 0)


asyncio.run(main())
