"""Self-test for `update` (ImageManager.update_one), with skopeo and nix mocked."""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from oci_image_updater.images import manager as manager_mod
from oci_image_updater.images import updater as updater_mod
from oci_image_updater.images.manager import ImageManager

OLD = "sha256:" + "a" * 64
NEW = "sha256:" + "b" * 64


def write(root: Path, pinned: bool) -> Path:
    f = root / "images" / "sini" / "xmsg" / "default.nix"
    f.parent.mkdir(parents=True)
    f.write_text("{}\n")
    return f


def metadata(pinned: bool) -> dict:
    return {
        "sini": {
            "xmsg": {
                "imageName": "ghcr.io/sini/xmsg",
                "imageTag": "sha-old",
                "imageDigest": OLD,
                "imageHash": "sha256-old=",
                "arch": "amd64",
                "os": "linux",
                "pinned": pinned,
            }
        }
    }


class UpdateOne(unittest.TestCase):
    def run_update(self, pinned, remote, tag=None, path="sini/xmsg", dry_run=False):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            f = write(root, pinned)
            seen = {}

            def digest(name, t, arch, os):
                seen["tag"] = t
                return remote

            with (
                mock.patch.object(
                    manager_mod.NixUtils,
                    "get_images_metadata",
                    return_value=metadata(pinned),
                ),
                mock.patch.object(
                    updater_mod.ImageUpdater, "check_remote_digest", side_effect=digest
                ),
                mock.patch.object(
                    updater_mod.NixUtils,
                    "prefetch_docker",
                    return_value={"hash": "sha256-new="},
                ),
            ):
                op = ImageManager(".", root, dry_run=dry_run).update_one(path, tag=tag)
            return op, f.read_text(), seen

    def test_new_digest_written(self):
        op, text, _ = self.run_update(False, NEW)
        self.assertTrue(op.updated)
        self.assertIn(NEW, text)
        self.assertIn('imageTag = "sha-old"', text)

    def test_tag_moves_and_resolves_at_new_tag(self):
        _, text, seen = self.run_update(False, NEW, tag="sha-new")
        self.assertEqual(seen["tag"], "sha-new")
        self.assertIn('imageTag = "sha-new"', text)
        self.assertIn(NEW, text)

    def test_tag_change_written_even_if_digest_same(self):
        op, text, _ = self.run_update(False, OLD, tag="sha-new")
        self.assertTrue(op.updated)
        self.assertIn('imageTag = "sha-new"', text)

    def test_pinned_named_image_updates_and_stays_pinned(self):
        op, text, _ = self.run_update(True, NEW)
        self.assertTrue(op.updated)
        self.assertIn("pinned = true", text)

    def test_up_to_date_writes_nothing(self):
        op, text, _ = self.run_update(False, OLD)
        self.assertFalse(op.updated)
        self.assertEqual(text, "{}\n")

    def test_dry_run_writes_nothing(self):
        op, text, _ = self.run_update(False, NEW, dry_run=True)
        self.assertTrue(op.updated)
        self.assertEqual(text, "{}\n")

    def test_unknown_path_raises_with_known_list(self):
        with self.assertRaises(KeyError) as cm:
            self.run_update(False, NEW, path="sini/nope")
        self.assertIn("sini/xmsg", str(cm.exception))


if __name__ == "__main__":
    unittest.main()
