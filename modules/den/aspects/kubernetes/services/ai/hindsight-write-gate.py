"""Per-bank token gate for hindsight-api 0.9.2 (an OperationValidatorExtension).

Loaded by upstream's extension loader (hindsight_api/extensions/loader.py) from
    HINDSIGHT_API_OPERATION_VALIDATOR_EXTENSION=hindsight_write_gate:WriteGate
    HINDSIGHT_API_OPERATION_VALIDATOR_BANKS={"den-law": {"gate_reads": true, "readers": ["vic"]}, ...}
    HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR=/etc/hindsight-write-gate/tokens
    HINDSIGHT_API_OPERATION_VALIDATOR_ADMIN_SHA256_FILE=/etc/hindsight-write-gate/admin/sha256
with one token file per gated bank in TOKENS_DIR, named after the bank, and one per
reader, named `<bank>.read.<reader>`.

A gated bank's writes pass only with that bank's own token or the admin token. A
bank with gate_reads also refuses every read without one of the two: recall,
reflect, every bank read, mental-model reads and every precheck, and it is left out
of the bank list. A reader's token admits that bank's reads and nothing else: on a
write it is refused like no key. A bank that is not configured is open. /health and /version reach
no hook and stay open. The two routes that call no hook at 0.9.2, mental-model
history (a read) and document import (a write), are wrapped at runtime so they do;
see _hook_unhooked_routes.

The admin token belongs to the control plane, which sits behind the gateway's
admin-only OIDC. This pod holds only its SHA-256, so the token itself lives in one
pod. Both comparisons are constant-time.

Startup refuses (the loader's ExtensionLoadError stops the server) on a malformed
BANKS, a gate_reads that is not a boolean, readers that are not a list of names, a
missing or empty token file, readers on a bank without gate_reads, or an
ADMIN_SHA256_FILE that is missing or not 64 hex digits.
"""

import functools
import hashlib
import hmac
import json
import logging
import re
from pathlib import Path

import hindsight_api.extensions.operation_validator as ov

logger = logging.getLogger(__name__)

# Pre-body prechecks that only read. Every other precheck operation is a write.
_READ_PRECHECKS = frozenset(
    {
        ov.PrecheckOperation.RECALL,
        ov.PrecheckOperation.REFLECT,
        ov.PrecheckOperation.DRY_RUN_EXTRACT,
    }
)


def _fail(msg: str):
    raise ValueError(f"bank gate: {msg}")


def _wrap(method: str, check):
    """Make MemoryEngine.<method> run `check` through the configured validator first.

    A runtime wrapper of an upstream method: re-check both targets at every
    hindsight upgrade. Startup refuses if the method is gone, rather than leaving
    its route ungated.
    """
    from hindsight_api.engine.memory_engine import MemoryEngine

    orig = getattr(MemoryEngine, method, None)
    if orig is None:
        _fail(f"MemoryEngine.{method} is gone; re-audit the unhooked routes")
    if getattr(orig, "_bank_gate", False):
        return

    @functools.wraps(orig)
    async def wrapped(self, bank_id, *args, **kwargs):
        if self._operation_validator is not None:
            await self._validate_operation(
                check(self._operation_validator, bank_id, args, kwargs)
            )
        return await orig(self, bank_id, *args, **kwargs)

    wrapped._bank_gate = True
    setattr(MemoryEngine, method, wrapped)


def _hook_unhooked_routes():
    """The two 0.9.2 routes that reach no validator hook, routed through one.

    GET …/mental-models/{id}/history (get_mental_model_history) returns a mental
    model's past content and calls only _authenticate_tenant: it now calls
    validate_mental_model_get, a read.

    POST …/document-transfer (import_documents_async) calls validate_create_bank
    only when the bank is missing, so an import into an existing bank was ungated:
    it now calls validate_retain with no contents, a write. The worker's
    _run_import_documents continues it under an internal context.
    """
    _wrap(
        "get_mental_model_history",
        lambda v, bank_id, args, kwargs: v.validate_mental_model_get(
            ov.MentalModelGetContext(
                bank_id=bank_id,
                mental_model_id=args[0] if args else kwargs["mental_model_id"],
                request_context=kwargs["request_context"],
            )
        ),
    )
    _wrap(
        "import_documents_async",
        lambda v, bank_id, args, kwargs: v.validate_retain(
            ov.RetainContext(
                bank_id=bank_id,
                contents=[],
                request_context=args[1] if len(args) > 1 else kwargs["request_context"],
            )
        ),
    )


class WriteGate(ov.OperationValidatorExtension):
    def __init__(self, config: dict[str, str]):
        super().__init__(config)
        _hook_unhooked_routes()
        try:
            banks = json.loads(config.get("banks") or "{}")
        except json.JSONDecodeError as e:
            _fail(f"BANKS is not JSON: {e}")
        if not isinstance(banks, dict):
            _fail("BANKS must be a JSON object of bank -> {gate_reads}")
        tokens_dir = config.get("tokens_dir")
        if banks and not tokens_dir:
            _fail("BANKS is set but TOKENS_DIR is not")
        self._tokens: dict[str, bytes] = {}
        self._read_tokens: dict[str, list[bytes]] = {}
        self._read_gated: set[str] = set()
        for bank, spec in banks.items():
            if not isinstance(spec, dict) or not isinstance(
                spec.get("gate_reads"), bool
            ):
                _fail(f"bank '{bank}' needs a boolean gate_reads")
            readers = spec.get("readers", [])
            if not isinstance(readers, list) or not all(
                isinstance(r, str) and re.fullmatch(r"[A-Za-z0-9_-]+", r)
                for r in readers
            ):
                _fail(f"bank '{bank}' readers must be a list of names")
            # A reader token on a bank whose reads are open would admit nothing new,
            # and reads it as configured access that is not there.
            if readers and not spec["gate_reads"]:
                _fail(f"bank '{bank}' has readers but does not gate reads")
            self._tokens[bank] = self._token(tokens_dir, bank, bank)
            self._read_tokens[bank] = [
                self._token(tokens_dir, f"{bank}.read.{r}", bank) for r in readers
            ]
            if spec["gate_reads"]:
                self._read_gated.add(bank)
        self._admin_sha256: bytes | None = None
        admin_file = config.get("admin_sha256_file")
        if admin_file:
            f = Path(admin_file)
            digest = f.read_text().strip().lower() if f.is_file() else ""
            if not re.fullmatch(r"[0-9a-f]{64}", digest):
                _fail(f"admin token digest at {f} is missing or not 64 hex digits")
            self._admin_sha256 = digest.encode()
        logger.info(
            f"bank gate: writes gated on {sorted(self._tokens)}, reads gated on "
            f"{sorted(self._read_gated)}, readers "
            f"{ {b: len(t) for b, t in self._read_tokens.items() if t} }, "
            f"admin token {'set' if self._admin_sha256 else 'unset'}"
        )

    @staticmethod
    def _token(tokens_dir: str, name: str, bank: str) -> bytes:
        f = Path(tokens_dir) / name
        if not f.is_file():
            _fail(f"no token file for gated bank '{bank}' at {f}")
        token = f.read_text().strip()
        if not token:
            _fail(f"empty token file for gated bank '{bank}' at {f}")
        return token.encode()

    def _admits(self, bank_id: str, key: str | None, read: bool) -> bool:
        # An empty key (`Authorization: Bearer `) is no key: it must not match the
        # digest of an empty admin token.
        if not key:
            return False
        if hmac.compare_digest(key.encode(), self._tokens[bank_id]):
            return True
        # Every reader token is compared, so the time taken does not say which matched.
        if read and sum(
            hmac.compare_digest(key.encode(), t) for t in self._read_tokens[bank_id]
        ):
            return True
        if self._admin_sha256 is None:
            return False
        return hmac.compare_digest(
            hashlib.sha256(key.encode()).hexdigest().encode(), self._admin_sha256
        )

    def _gate(self, bank_id: str, request_context, read: bool) -> ov.ValidationResult:
        # Worker and maintenance contexts carry internal=True and never come from a
        # transport (http.py and mcp.py build contexts from the Authorization header
        # only); the user-facing submission they continue was gated when it was made.
        if request_context.internal:
            return ov.ValidationResult.accept()
        if bank_id not in self._tokens:
            return ov.ValidationResult.accept()
        if read and bank_id not in self._read_gated:
            return ov.ValidationResult.accept()
        if self._admits(bank_id, request_context.api_key, read):
            return ov.ValidationResult.accept()
        kind = "read" if read else "write"
        return ov.ValidationResult.reject(
            f"bank '{bank_id}' is {kind}-gated: a valid bank token is required", 403
        )

    # Reads: open unless the bank gates reads.
    async def validate_recall(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=True)

    async def validate_reflect(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=True)

    async def validate_bank_read(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=True)

    async def validate_mental_model_get(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=True)

    async def precheck(self, ctx) -> ov.ValidationResult:
        return self._gate(
            ctx.bank_id, ctx.request_context, read=ctx.operation in _READ_PRECHECKS
        )

    async def filter_bank_list(self, ctx) -> ov.BankListResult:
        rc = ctx.request_context
        banks = [
            b
            for b in ctx.banks
            if rc.internal
            or b.get("bank_id") not in self._read_gated
            or self._admits(b["bank_id"], rc.api_key, read=True)
        ]
        return ov.BankListResult(banks=banks)

    # Writes: every write hook the 0.9.2 interface exposes.
    async def validate_retain(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=False)

    async def validate_bank_write(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=False)

    async def validate_create_bank(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=False)

    async def validate_consolidate(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=False)

    async def validate_mental_model_refresh(self, ctx) -> ov.ValidationResult:
        return self._gate(ctx.bank_id, ctx.request_context, read=False)
