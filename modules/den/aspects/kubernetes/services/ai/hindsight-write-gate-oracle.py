"""Oracle for hindsight-write-gate.py (the bank gate), run against hindsight-api-slim 0.9.2.

Drives every bank route of the real FastAPI app (create_app) and every tool of the
real MCP server over a real MemoryEngine (mock LLM, constant embeddings, a Postgres
with pgvector), with the gate loaded by upstream's own loader from
HINDSIGHT_API_OPERATION_VALIDATOR_*.

Banks: genie and genie-memory gate writes; den-law gates reads and writes and has one
reader; open-bank is not configured. ADMIN is the control plane's token; the gate
holds its SHA-256. READER is den-law's reader token, which admits reads only.

  a  every write route on genie, document import included: no key and another
     bank's key are refused; genie's own key and the admin key are not; every write
     route on den-law refuses the reader key
  r  den-law: every route (write, read, GET), a chunk read by id and the bank list
     refuse no key and another bank's key, and admit den-law's key, the admin key and
     the reader key
  b  recall, reflect and every read route on genie pass without a key
  c  every write route on the unconfigured bank passes without a key
  m  MCP: every tool on /mcp/den-law/ refuses no key and another bank's key and admits
     den-law's and the admin key; the reader key is admitted by read tools only; /mcp/genie/ recall needs no key; the multi-bank
     /mcp/ endpoint refuses den-law recall and hides den-law from list_banks
  d  startup refuses a malformed BANKS, a non-boolean gate_reads, bad readers, readers
     on a bank without gate_reads, an empty or missing token or reader file, a bad admin digest, or a wrapped engine method that is gone; the
     `hindsight-api` entrypoint refuses too

Run (no live server; DATABASE_URL is a throwaway local Postgres with pgvector):
  HINDSIGHT_API_DATABASE_URL=postgresql://... \
    <venv with hindsight-api-slim==0.9.2>/bin/python hindsight-write-gate-oracle.py <dir holding hindsight_write_gate.py>
Exit 0 iff every cell passes.
"""

import asyncio
import collections
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

GATE_DIR = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(GATE_DIR))

TOKENS = {
    "genie": "tok-genie-0123456789abcdef",
    "genie-memory": "tok-genie-memory-fedcba9876543210",
    "den-law": "tok-den-law-00112233445566778899",
}
BANKS = {
    "genie": {"gate_reads": False},
    "genie-memory": {"gate_reads": False},
    "den-law": {"gate_reads": True, "readers": ["vic"]},
}
READER = "tok-den-law-reader-vic-445566778899"
READER_FILE = "den-law.read.vic"
ADMIN = "tok-admin-aabbccddeeff00112233"
GATED, OTHER, LAW, OPEN = "genie", "genie-memory", "den-law", "open-bank"
REFUSAL = "-gated: a valid bank token is required"

tokdir = Path(tempfile.mkdtemp(prefix="hswg-tokens-"))
for bank, tok in TOKENS.items():
    (tokdir / bank).write_text(tok + "\n")
(tokdir / READER_FILE).write_text(READER + "\n")
admin_file = Path(tempfile.mkdtemp(prefix="hswg-admin-")) / "sha256"
admin_file.write_text(hashlib.sha256(ADMIN.encode()).hexdigest() + "\n")
GATE_ENV = {
    "HINDSIGHT_API_OPERATION_VALIDATOR_EXTENSION": "hindsight_write_gate:WriteGate",
    "HINDSIGHT_API_OPERATION_VALIDATOR_BANKS": json.dumps(BANKS),
    "HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR": str(tokdir),
    "HINDSIGHT_API_OPERATION_VALIDATOR_ADMIN_SHA256_FILE": str(admin_file),
}
os.environ.update(GATE_ENV)
os.environ.setdefault("HINDSIGHT_API_CONSOLIDATION_RECONCILE_INTERVAL_SECONDS", "0")
os.environ.setdefault("HINDSIGHT_API_MENTAL_MODEL_REFRESH_TICK_SECONDS", "0")
os.environ.setdefault("HINDSIGHT_API_LLM_TRACE_RETENTION_DAYS", "-1")
# As deployed: document import is on (upstream's default). The gate wraps it so it is a
# token-gated write like any other; it is one of the `writes` below.
os.environ.setdefault("HINDSIGHT_API_ENABLE_DOCUMENT_IMPORT_API", "true")

import httpx
from hindsight_api import MemoryEngine, RequestContext
from hindsight_api.api import create_app
from hindsight_api.engine.cross_encoder import RRFPassthroughCrossEncoder
from hindsight_api.engine.embeddings import Embeddings
from hindsight_api.engine.query_analyzer import DateparserQueryAnalyzer
from hindsight_api.engine.task_backend import SyncTaskBackend
from hindsight_api.extensions import OperationValidatorExtension
from hindsight_api.extensions.loader import ExtensionLoadError, load_extension
from mcp.client.session import ClientSession
from mcp.client.streamable_http import streamable_http_client


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


def closed(r):
    # Closed to every caller by configuration (a route the deployment or upstream
    # leaves disabled answers 404 "... is disabled") or by upstream (the deprecated
    # entity route answers 410).
    return (r.status_code == 404 and "is disabled" in r.text) or r.status_code == 410


def refused(r):
    if closed(r):
        return True
    # The gate's reason, whatever status the route maps it to: the webhook routes do not
    # catch OperationValidationError and answer 500, with nothing written.
    return r.status_code >= 400 and REFUSAL in r.text


def hdr(tok):
    # "" sends `Authorization: Bearer ` (an empty key); None sends no header.
    return {} if tok is None else {"Authorization": f"Bearer {tok}"}


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
    ids = {"entity_id": str(uuid.uuid4())}
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
    ("POST", "/health/llm"): None,
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
# Mutating routes closed to every caller, keyed or not: the entity route, by upstream (410).
CLOSED = {"/entities/{entity_id}/regenerate"}


async def call(c, verb, suffix, bank, ids, tok):
    url = f"/v1/default/banks/{bank}" + suffix.format_map(
        collections.defaultdict(lambda: "x0", ids)
    ).replace("{document_id:path}", ids["document_id"])
    h = hdr(tok)
    if verb == "POST" and suffix == "/document-transfer":
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
    if suffix == "/knowledge-base/search":
        url += "?q=alice"
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


def _dummy(schema):
    t = schema.get("type")
    if t is None and "anyOf" in schema:
        t = next(
            (a.get("type") for a in schema["anyOf"] if a.get("type") != "null"),
            "string",
        )
    return {"integer": 1, "number": 1, "boolean": False, "array": [], "object": {}}.get(
        t, "x0"
    )


def _text(result):
    parts = [getattr(x, "text", "") for x in result.content]
    if getattr(result, "structuredContent", None):
        parts.append(json.dumps(result.structuredContent))
    return " ".join(parts)


async def mcp_session(http, url, fn):
    async with (
        streamable_http_client(url, http_client=http) as (rd, wr, _),
        ClientSession(rd, wr) as session,
    ):
        await session.initialize()
        return await fn(session)


async def mcp_cells(mem, ids):
    app = create_app(mem, mcp_api_enabled=True, initialize_memory=False)
    async with app.router.lifespan_context(app):

        def client(tok):
            return httpx.AsyncClient(
                transport=httpx.ASGITransport(app=app),
                base_url="http://t",
                headers=hdr(tok),
                timeout=120,
            )

        async with client(None) as http:
            tools = await mcp_session(
                http, f"http://t/mcp/{LAW}/", lambda s: s.list_tools()
            )
        tools = tools.tools
        print(f"mcp: /mcp/{LAW}/ tools={len(tools)}")
        cell("m.tools", len(tools) > 0, "no MCP tools listed")
        # Each tool's kind, from the no-key row (which runs first): the gate names a
        # write refusal as such. The reader row is judged against this, never against
        # its own response, which says nothing once a reader is wrongly admitted.
        writes_tool: dict[str, bool] = {}
        for label, tok, want_refused in (
            ("none", None, True),
            ("other", TOKENS[GATED], True),
            ("own", TOKENS[LAW], False),
            ("admin", ADMIN, False),
            ("reader", READER, None),
        ):
            async with client(tok) as http:
                for t in tools:
                    props = t.inputSchema.get("properties", {})
                    args = {
                        k: ids[k] if k in ids else _dummy(props[k])
                        for k in t.inputSchema.get("required", [])
                    }
                    if t.name == "update_knowledge_node":
                        args["name"] = "renamed"
                    if (
                        t.name in ("delete_bank", "clear_memories")
                        and want_refused is False
                    ):
                        continue  # would empty the fixture for the later tools
                    res = await mcp_session(
                        http,
                        f"http://t/mcp/{LAW}/",
                        lambda s, n=t.name, a=args: s.call_tool(n, a),
                    )
                    out = _text(res)
                    if label == "none":
                        writes_tool[t.name] = "write-gated" in out
                    # The reader is refused exactly the tools no-key is refused as writes.
                    expect = (
                        writes_tool[t.name] if want_refused is None else want_refused
                    )
                    cell(
                        f"m.law.{label}",
                        (REFUSAL in out) == expect,
                        f"/mcp/{LAW}/ {t.name} key={label} -> {out[:160]}",
                    )

        async with client(None) as http:
            res = await mcp_session(
                http,
                f"http://t/mcp/{GATED}/",
                lambda s: s.call_tool("recall", {"query": "alice"}),
            )
            out = _text(res)
            cell(
                "m.genie.recall-open",
                REFUSAL not in out and not res.isError,
                f"/mcp/{GATED}/ recall -> {out[:160]}",
            )
            res = await mcp_session(
                http,
                "http://t/mcp/",
                lambda s: s.call_tool("recall", {"query": "alice", "bank_id": LAW}),
            )
            out = _text(res)
            cell(
                "m.multi.recall-refused",
                REFUSAL in out,
                f"/mcp/ recall bank_id={LAW} -> {out[:160]}",
            )
            res = await mcp_session(
                http, "http://t/mcp/", lambda s: s.call_tool("list_banks", {})
            )
            out = _text(res)
            cell(
                "m.multi.list-hidden",
                LAW not in out and GATED in out,
                f"/mcp/ list_banks -> {out[:200]}",
            )


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
        for b in (GATED, OTHER, LAW, OPEN):
            await c.delete(f"/v1/default/banks/{b}", headers=hdr(ADMIN))

        # a and r(write): one fresh fixture per credential that may mutate, so a
        # destructive call cannot mask the next
        for bank, cellp, other in (
            (GATED, "a", TOKENS[LAW]),
            (LAW, "r.write", TOKENS[GATED]),
        ):
            for verb, suffix in writes:
                ids = await fixture(c, bank, TOKENS[bank])
                refusals = [("none", None), ("other", other)]
                if bank == LAW:
                    refusals.append(("reader", READER))
                for label, tok in refusals:
                    r = await call(c, verb, suffix, bank, ids, tok)
                    cell(
                        f"{cellp}.refused",
                        refused(r),
                        f"{bank} {verb} {suffix} key={label} -> {r.status_code} {r.text[:160]}",
                    )
                for label, tok in (("own", TOKENS[bank]), ("admin", ADMIN)):
                    if label == "admin":
                        await c.delete(f"/v1/default/banks/{bank}", headers=hdr(ADMIN))
                        ids = await fixture(c, bank, TOKENS[bank])
                    r = await call(c, verb, suffix, bank, ids, tok)
                    if label == "own":
                        print(
                            f"own-key {r.status_code} {bank} {verb} {suffix}"
                            + (f" {r.text[:120]}" if r.status_code >= 400 else "")
                        )
                    name = f"{cellp}.closed" if suffix in CLOSED else f"{cellp}.{label}"
                    cell(
                        name,
                        refused(r) if suffix in CLOSED else not refused(r),
                        f"{bank} {verb} {suffix} key={label} -> {r.status_code} {r.text[:160]}",
                    )
                await c.delete(f"/v1/default/banks/{bank}", headers=hdr(ADMIN))

        reads = gets + [("POST", s) for s in sorted(READ_POSTS)]

        # r(read): every read route on den-law, and the two non-bank routes that read
        # a bank's content by id
        ids = await fixture(c, LAW, TOKENS[LAW])
        chunks = (
            await c.get(
                f"/v1/default/banks/{LAW}/documents/doc1/chunks", headers=hdr(ADMIN)
            )
        ).json()
        chunk_id = (chunks.get("items") or chunks.get("chunks") or [{}])[0].get(
            "chunk_id"
        )
        cell("r.fixture", chunk_id is not None, f"no chunk id in {str(chunks)[:160]}")
        for label, tok, want_refused in (
            ("none", None, True),
            ("empty", "", True),
            ("other", TOKENS[GATED], True),
            ("own", TOKENS[LAW], False),
            ("admin", ADMIN, False),
            ("reader", READER, False),
        ):
            for verb, suffix in reads:
                r = await call(c, verb, suffix, LAW, ids, tok)
                ok = refused(r) if want_refused else REFUSAL not in r.text
                cell(
                    f"r.read.{label}",
                    ok,
                    f"{LAW} {verb} {suffix} key={label} -> {r.status_code} {r.text[:160]}",
                )
            r = await c.get(f"/v1/default/chunks/{chunk_id}", headers=hdr(tok))
            cell(
                f"r.read.{label}",
                (REFUSAL in r.text) == want_refused,
                f"GET /v1/default/chunks/<den-law chunk> key={label} -> {r.status_code} {r.text[:160]}",
            )
            listed = [
                b["bank_id"]
                for b in (await c.get("/v1/default/banks", headers=hdr(tok))).json()[
                    "banks"
                ]
            ]
            cell(
                f"r.list.{label}",
                (LAW in listed) != want_refused,
                f"bank list key={label} -> {listed}",
            )
        await c.delete(f"/v1/default/banks/{LAW}", headers=hdr(ADMIN))

        # b: reads on genie need no key
        ids = await fixture(c, GATED, TOKENS[GATED])
        r = await call(c, "POST", "/memories/recall", GATED, ids, None)
        cell(
            "b.recall",
            r.status_code == 200,
            f"recall -> {r.status_code} {r.text[:160]}",
        )
        for verb, suffix in reads:
            r = await call(c, verb, suffix, GATED, ids, None)
            cell(
                "b.read",
                REFUSAL not in r.text,
                f"{verb} {suffix} -> {r.status_code} {r.text[:160]}",
            )
        await c.delete(f"/v1/default/banks/{GATED}", headers=hdr(ADMIN))

        # c: an unconfigured bank takes every write without a key
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

        # m: the MCP transport
        law_ids = await fixture(c, LAW, TOKENS[LAW])
        await fixture(c, GATED, TOKENS[GATED])
    await mcp_cells(mem, law_ids)
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app), base_url="http://t"
    ) as c:
        for b in (GATED, LAW):
            await c.delete(f"/v1/default/banks/{b}", headers=hdr(ADMIN))
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

    cell("d.valid-loads", load({}) is None, "valid configuration refused to load")

    def tokens(**over):
        d = Path(tempfile.mkdtemp(prefix="hswg-d-"))
        for bank, tok in {**TOKENS, READER_FILE: READER, **over}.items():
            if tok is not None:
                (d / bank).write_text(tok)
        return str(d)

    td = "HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR"
    bk = "HINDSIGHT_API_OPERATION_VALIDATOR_BANKS"
    empty = tokens(**{"den-law": "\n"})
    bad_admin = Path(tempfile.mkdtemp(prefix="hswg-a-")) / "sha256"
    bad_admin.write_text("not-a-digest\n")
    for name, env in (
        ("d.empty-refused", {td: empty}),
        ("d.missing-refused", {td: tokens(**{"genie-memory": None})}),
        ("d.bad-json-refused", {bk: "genie,den-law"}),
        (
            "d.bad-gate-reads-refused",
            {bk: json.dumps({**BANKS, "den-law": {"gate_reads": "yes"}})},
        ),
        ("d.reader-missing-refused", {td: tokens(**{READER_FILE: None})}),
        ("d.reader-empty-refused", {td: tokens(**{READER_FILE: "\n"})}),
        (
            "d.bad-readers-refused",
            {
                bk: json.dumps(
                    {**BANKS, "den-law": {"gate_reads": True, "readers": "vic"}}
                )
            },
        ),
        (
            "d.reader-path-refused",
            {
                bk: json.dumps(
                    {**BANKS, "den-law": {"gate_reads": True, "readers": ["../x"]}}
                )
            },
        ),
        (
            "d.readers-open-reads-refused",
            {
                bk: json.dumps(
                    {**BANKS, "genie": {"gate_reads": False, "readers": ["vic"]}}
                )
            },
        ),
        (
            "d.bad-admin-refused",
            {"HINDSIGHT_API_OPERATION_VALIDATOR_ADMIN_SHA256_FILE": str(bad_admin)},
        ),
    ):
        err = load(env)
        cell(name, err is not None, f"{name}: loaded")

    # An empty key must not match even an admin digest of the empty string.
    empty_digest = Path(tempfile.mkdtemp(prefix="hswg-e-")) / "sha256"
    empty_digest.write_text(hashlib.sha256(b"").hexdigest())
    saved = dict(os.environ)
    os.environ["HINDSIGHT_API_OPERATION_VALIDATOR_ADMIN_SHA256_FILE"] = str(
        empty_digest
    )
    try:
        g = load_extension("OPERATION_VALIDATOR", OperationValidatorExtension)
        cell(
            "d.empty-key-refused",
            not g._admits(LAW, "", True),
            "an empty key was admitted",
        )
    finally:
        os.environ.clear()
        os.environ.update(saved)

    # Each wrapped engine method, removed: startup refuses rather than leave its route
    # ungated. Fresh interpreters, so the wrappers this process installed do not count.
    for method in ("get_mental_model_history", "import_documents_async"):
        probe = (
            "import sys; sys.path.insert(0, sys.argv[1]);"
            "from hindsight_api.engine.memory_engine import MemoryEngine;"
            f"delattr(MemoryEngine, '{method}');"
            "from hindsight_api.extensions import OperationValidatorExtension as O;"
            "from hindsight_api.extensions.loader import load_extension;"
            "load_extension('OPERATION_VALIDATOR', O)"
        )
        p = subprocess.run(
            [sys.executable, "-c", probe, str(GATE_DIR)],
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        cell(
            "d.missing-method-refused",
            p.returncode != 0 and f"MemoryEngine.{method} is gone" in p.stderr,
            f"{method} removed: rc={p.returncode} tail={p.stderr[-200:]}",
        )

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
