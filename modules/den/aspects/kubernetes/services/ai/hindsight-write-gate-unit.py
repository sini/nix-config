"""Hermetic policy tests, not a substitute for the pinned-upstream route oracle.

The tiny upstream interface stand-ins below exercise this gate's credential and
hook decisions without a database or an installed hindsight package. The route
oracle separately verifies that the real upstream transports reach these hooks.

    python3 hindsight-write-gate-unit.py
"""

import asyncio
import hashlib
import importlib.util
import json
import sys
import tempfile
import types
import unittest
from dataclasses import dataclass
from enum import Enum
from pathlib import Path


class PrecheckOperation(Enum):
    RECALL = "recall"
    REFLECT = "reflect"
    DRY_RUN_EXTRACT = "dry_run_extract"
    RETAIN = "retain"


@dataclass
class ValidationResult:
    allowed: bool

    @classmethod
    def accept(cls):
        return cls(True)

    @classmethod
    def reject(cls, _reason, _status):
        return cls(False)


class OperationValidatorExtension:
    def __init__(self, _config):
        pass


class MemoryEngine:
    async def get_mental_model_history(self, *_args, **_kwargs):
        pass

    async def import_documents_async(self, *_args, **_kwargs):
        pass


for name in (
    "hindsight_api",
    "hindsight_api.extensions",
    "hindsight_api.extensions.operation_validator",
    "hindsight_api.engine",
    "hindsight_api.engine.memory_engine",
):
    sys.modules[name] = types.ModuleType(name)
ov = sys.modules["hindsight_api.extensions.operation_validator"]
ov.PrecheckOperation = PrecheckOperation
ov.ValidationResult = ValidationResult
ov.OperationValidatorExtension = OperationValidatorExtension
ov.BankListResult = types.SimpleNamespace
ov.MentalModelGetContext = types.SimpleNamespace
ov.RetainContext = types.SimpleNamespace
sys.modules["hindsight_api.engine.memory_engine"].MemoryEngine = MemoryEngine
spec = importlib.util.spec_from_file_location(
    "hindsight_write_gate", Path(__file__).with_name("hindsight-write-gate.py")
)
gate_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate_module)

# Deliberately fake, non-production fixtures. Never generate or read real secrets.
OWNER = "fixture-den-law-owner"
WRITER = "fixture-den-law-artemis"
READER = "fixture-den-law-vic"
OTHER = "fixture-other-bank-owner"
ADMIN = "fixture-cp-admin"


class GateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name, value in {
            "den-law": OWNER,
            "den-law.read.vic": READER,
            "den-law.write.artemis": WRITER,
            "genie": OTHER,
        }.items():
            (self.root / name).write_text(value + "\n")
        self.admin_file = self.root / "admin.sha256"
        self.admin_file.write_text(hashlib.sha256(ADMIN.encode()).hexdigest())
        self.banks = {
            "den-law": {"gate_reads": True, "readers": ["vic"], "writers": ["artemis"]},
            "genie": {"gate_reads": False},
        }

    def gate(self, **config):
        return gate_module.WriteGate(
            {
                "banks": json.dumps(self.banks),
                "tokens_dir": str(self.root),
                "admin_sha256_file": str(self.admin_file),
                **config,
            }
        )

    @staticmethod
    def context(key, bank="den-law", internal=False, **fields):
        return types.SimpleNamespace(
            bank_id=bank,
            request_context=types.SimpleNamespace(api_key=key, internal=internal),
            **fields,
        )

    def test_full_writer_admitted_by_every_read_and_write_hook(self):
        gate = self.gate()
        hooks = [n for n in vars(type(gate)) if n.startswith("validate_")]
        self.assertEqual(len(hooks), 9)
        for hook in hooks:
            with self.subTest(hook=hook):
                result = asyncio.run(getattr(gate, hook)(self.context(WRITER)))
                self.assertTrue(result.allowed)
        for operation in PrecheckOperation:
            with self.subTest(operation=operation):
                result = asyncio.run(
                    gate.precheck(self.context(WRITER, operation=operation))
                )
                self.assertTrue(result.allowed)

    def test_reader_remains_read_only(self):
        gate = self.gate()
        self.assertTrue(asyncio.run(gate.validate_recall(self.context(READER))).allowed)
        for hook in (
            "validate_retain",
            "validate_bank_write",
            "validate_create_bank",
            "validate_consolidate",
            "validate_mental_model_refresh",
        ):
            with self.subTest(hook=hook):
                self.assertFalse(
                    asyncio.run(getattr(gate, hook)(self.context(READER))).allowed
                )
        self.assertFalse(
            asyncio.run(
                gate.precheck(self.context(READER, operation=PrecheckOperation.RETAIN))
            ).allowed
        )

    def test_writer_cannot_access_another_bank(self):
        gate = self.gate()
        self.assertFalse(
            asyncio.run(gate.validate_retain(self.context(WRITER, "genie"))).allowed
        )
        for bank in ("genie", "unconfigured"):
            for hook in ("validate_recall", "validate_retain"):
                with self.subTest(bank=bank, hook=hook):
                    self.assertFalse(
                        asyncio.run(
                            getattr(gate, hook)(self.context(WRITER, bank))
                        ).allowed
                    )
        # Omitting the credential still reaches open banks. The fixed-bank
        # adapter and effective network policy remain independent boundaries.
        self.assertTrue(
            asyncio.run(gate.validate_recall(self.context(None, "genie"))).allowed
        )
        self.assertTrue(
            asyncio.run(
                gate.validate_retain(self.context(None, "unconfigured"))
            ).allowed
        )

    def test_writer_visible_in_bank_list(self):
        gate = self.gate()
        ctx = self.context(WRITER, banks=[{"bank_id": "den-law"}, {"bank_id": "genie"}])
        self.assertEqual(
            asyncio.run(gate.filter_bank_list(ctx)).banks, [{"bank_id": "den-law"}]
        )
        ctx.request_context.api_key = OTHER
        self.assertEqual(
            asyncio.run(gate.filter_bank_list(ctx)).banks, [{"bank_id": "genie"}]
        )

    def test_existing_credentials_and_internal_context_unchanged(self):
        gate = self.gate()
        for key in (OWNER, ADMIN):
            self.assertTrue(
                asyncio.run(gate.validate_retain(self.context(key))).allowed
            )
        for key in (None, "", OTHER, READER):
            self.assertFalse(
                asyncio.run(gate.validate_retain(self.context(key))).allowed
            )
        self.assertTrue(
            asyncio.run(gate.validate_retain(self.context(None, internal=True))).allowed
        )
        self.assertTrue(
            asyncio.run(
                gate.validate_retain(self.context(None, "unconfigured"))
            ).allowed
        )

    def test_legacy_config_without_writers(self):
        self.banks["den-law"].pop("writers")
        gate = self.gate()
        self.assertFalse(
            asyncio.run(gate.validate_retain(self.context(WRITER))).allowed
        )
        self.assertTrue(asyncio.run(gate.validate_retain(self.context(OWNER))).allowed)
        self.assertTrue(asyncio.run(gate.validate_recall(self.context(READER))).allowed)

    def test_writer_rotation_leaves_owner_and_reader_unchanged(self):
        (self.root / "den-law.write.artemis").write_text("fixture-rotated-writer")
        gate = self.gate()
        self.assertFalse(
            asyncio.run(gate.validate_retain(self.context(WRITER))).allowed
        )
        self.assertTrue(
            asyncio.run(
                gate.validate_retain(self.context("fixture-rotated-writer"))
            ).allowed
        )
        self.assertTrue(asyncio.run(gate.validate_retain(self.context(OWNER))).allowed)
        self.assertTrue(asyncio.run(gate.validate_recall(self.context(READER))).allowed)

    def test_writer_revocation_leaves_owner_and_reader_unchanged(self):
        self.banks["den-law"]["writers"] = []
        gate = self.gate()
        self.assertFalse(
            asyncio.run(gate.validate_recall(self.context(WRITER))).allowed
        )
        self.assertTrue(asyncio.run(gate.validate_retain(self.context(OWNER))).allowed)
        self.assertTrue(asyncio.run(gate.validate_recall(self.context(READER))).allowed)

    def test_missing_or_empty_writer_refuses_startup(self):
        path = self.root / "den-law.write.artemis"
        path.unlink()
        with self.assertRaisesRegex(ValueError, "no token file"):
            self.gate()
        for value in ("", "\n", "  "):
            path.write_text(value)
            with (
                self.subTest(value=value),
                self.assertRaisesRegex(ValueError, "empty token file"),
            ):
                self.gate()

    def test_malformed_writer_names_refuse_startup(self):
        for writers in (
            "artemis",
            {},
            None,
            [1],
            [""],
            ["../escape"],
            ["x/y"],
            ["x.y"],
            ["artemis", "artemis"],
        ):
            self.banks["den-law"]["writers"] = writers
            with self.subTest(writers=writers), self.assertRaises(ValueError):
                self.gate()

    def test_multiple_writer_credentials_admitted(self):
        self.banks["den-law"]["writers"].append("second")
        (self.root / "den-law.write.second").write_text("fixture-second")
        gate = self.gate()
        for key in (WRITER, "fixture-second"):
            self.assertTrue(
                asyncio.run(gate.validate_retain(self.context(key))).allowed
            )


if __name__ == "__main__":
    unittest.main()
