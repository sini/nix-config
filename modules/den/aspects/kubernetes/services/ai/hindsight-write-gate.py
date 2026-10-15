"""Per-bank token gate for hindsight-api 0.9.2 (an OperationValidatorExtension).

Loaded by upstream's extension loader (hindsight_api/extensions/loader.py) from
    HINDSIGHT_API_OPERATION_VALIDATOR_EXTENSION=hindsight_write_gate:WriteGate
    HINDSIGHT_API_OPERATION_VALIDATOR_BANKS={"genie": {"gate_reads": false}, ...}
    HINDSIGHT_API_OPERATION_VALIDATOR_TOKENS_DIR=/etc/hindsight-write-gate/tokens
    HINDSIGHT_API_OPERATION_VALIDATOR_ADMIN_SHA256_FILE=/etc/hindsight-write-gate/admin/sha256
with one token file per gated bank in TOKENS_DIR, named after the bank.

A gated bank's writes pass only with that bank's own token or the admin token. A
bank with gate_reads also refuses every read without one of the two: recall,
reflect, every bank read, mental-model reads and every precheck, and it is left out
of the bank list. A bank that is not configured is open. /health and /version reach
no hook and stay open. The one read route that calls no hook (mental-model history)
is wrapped to call validate_mental_model_get; see _hook_unhooked_reads.

The admin token belongs to the control plane, which sits behind the gateway's
admin-only OIDC. This pod holds only its SHA-256, so the token itself lives in one
pod. Both comparisons are constant-time.

Startup refuses (the loader's ExtensionLoadError stops the server) on a malformed
BANKS, a gate_reads that is not a boolean, a missing or empty token file, or an
ADMIN_SHA256_FILE that is missing or not 64 hex digits.
"""

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


def _hook_unhooked_reads():
    """Route the one 0.9.2 read that calls no validator hook through validate_mental_model_get.

    GET …/mental-models/{id}/history returns a mental model's past content and calls
    only _authenticate_tenant (memory_engine.py get_mental_model_history), so without
    this a read-gated bank's mental models would be readable with no token. Wrapped
    once, here, so every transport reaches it; refuses to start if the method is gone.
    """
    from hindsight_api.engine.memory_engine import MemoryEngine

    orig = getattr(MemoryEngine, "get_mental_model_history", None)
    if orig is None:
        _fail(
            "MemoryEngine.get_mental_model_history is gone; re-audit the unhooked reads"
        )
    if getattr(orig, "_bank_gate", False):
        return

    async def get_mental_model_history(
        self, bank_id, mental_model_id, *, request_context
    ):
        if self._operation_validator is not None:
            await self._validate_operation(
                self._operation_validator.validate_mental_model_get(
                    ov.MentalModelGetContext(
                        bank_id=bank_id,
                        mental_model_id=mental_model_id,
                        request_context=request_context,
                    )
                )
            )
        return await orig(
            self, bank_id, mental_model_id, request_context=request_context
        )

    get_mental_model_history._bank_gate = True
    MemoryEngine.get_mental_model_history = get_mental_model_history


class WriteGate(ov.OperationValidatorExtension):
    def __init__(self, config: dict[str, str]):
        super().__init__(config)
        _hook_unhooked_reads()
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
        self._read_gated: set[str] = set()
        for bank, spec in banks.items():
            if not isinstance(spec, dict) or not isinstance(
                spec.get("gate_reads"), bool
            ):
                _fail(f"bank '{bank}' needs a boolean gate_reads")
            f = Path(tokens_dir) / bank
            if not f.is_file():
                _fail(f"no token file for gated bank '{bank}' at {f}")
            token = f.read_text().strip()
            if not token:
                _fail(f"empty token file for gated bank '{bank}' at {f}")
            self._tokens[bank] = token.encode()
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
            f"{sorted(self._read_gated)}, admin token {'set' if self._admin_sha256 else 'unset'}"
        )

    def _admits(self, bank_id: str, key: str | None) -> bool:
        if key is None:
            return False
        if hmac.compare_digest(key.encode(), self._tokens[bank_id]):
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
        if self._admits(bank_id, request_context.api_key):
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
            or self._admits(b["bank_id"], rc.api_key)
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
