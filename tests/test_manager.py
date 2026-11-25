"""Offline unit tests; never install packages or run an upstream program."""
import hashlib
import io
import json
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "runtime"))
import manager


class ManagerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.base = mock.patch.object(manager, "BASE", self.root / "managed")
        self.src = mock.patch.object(manager, "SOURCES", self.root / "sources")
        self.base.start()
        self.src.start()
        self.addCleanup(self.base.stop)
        self.addCleanup(self.src.stop)

    def make_release(self, name, directory, previous=""):
        parent = manager.owned(name)
        target = parent / directory
        target.mkdir(parents=True)
        (parent / "current.json").write_text(json.dumps({
            "directory": directory, "previous": previous,
            "commit": directory.split("-")[1], "name": name
        }))
        return target

    def test_catalog_all_twelve(self):
        rows = manager.catalog()
        self.assertEqual(len(rows), 12)
        self.assertEqual(sum(row["recipe"] for row in rows.values()), 3)
        self.assertFalse(any(row["managed"] for row in rows.values()))

    def test_invalid_project(self):
        with self.assertRaises(ValueError):
            manager.slug("../../other")

    def test_rollback_and_removal_preserve_other_files(self):
        first = "release-aaaaaaaaaaaa-1"
        second = "release-bbbbbbbbbbbb-2"
        self.make_release("Noctalia", first)
        self.make_release("Noctalia", second, first)
        other = manager.owned("Noctalia") / "personal.txt"
        other.write_text("keep")
        manager.rollback("Noctalia")
        self.assertEqual(manager.metadata("Noctalia")["directory"], first)
        manager.remove("Noctalia")
        self.assertTrue(other.is_file())
        self.assertIsNone(manager.metadata("Noctalia"))

    def test_bad_manifest_path_rejected(self):
        parent = manager.owned("Noctalia")
        parent.mkdir(parents=True)
        (parent / "current.json").write_text(json.dumps({"directory": "../../escape"}))
        self.assertIsNone(manager.metadata("Noctalia"))

    def test_source_does_not_count_as_installed(self):
        (manager.SOURCES / "serpantinum" / ".git").mkdir(parents=True)
        row = manager.catalog()["Serpantinum"]
        self.assertTrue(row["source"])
        self.assertFalse(row["managed"])

    def test_backend_checksum_and_exact_member(self):
        repo = self.root / "repo"
        (repo / "nix").mkdir(parents=True)
        (repo / "nix/core.nix").write_text('version = "0.8.0";')
        dest = self.root / "bin"
        dest.mkdir()
        archive = self.root / "fixture.tar.gz"
        payload = b"fixture binary"
        with tarfile.open(archive, "w:gz") as tar:
            for name, data in [("usr/bin/serpantinum-core", payload), ("../../escape", b"no")]:
                item = tarfile.TarInfo(name)
                item.size = len(data)
                tar.addfile(item, io.BytesIO(data))
        blob = archive.read_bytes()
        digest = hashlib.sha256(blob).hexdigest()

        def download(url, path, *args):
            if url.endswith("SHA256SUMS"):
                path.write_text(digest + "  serpantinum-core-0.8.0-x86_64-linux.tar.gz\n")
            else:
                path.write_bytes(blob)

        with mock.patch.object(manager, "get", side_effect=download):
            manager.backend(repo, "core", dest, self.root)
        self.assertEqual((dest / "serpantinum-core").read_bytes(), payload)
        self.assertFalse((self.root.parent / "escape").exists())
        with mock.patch.object(manager, "get", side_effect=lambda url, path, *a: path.write_bytes(b"bad")):
            with self.assertRaisesRegex(RuntimeError, "Checksum mismatch"):
                manager.backend(repo, "core", dest, self.root)

    def test_failed_install_preserves_manifest(self):
        old = "release-aaaaaaaaaaaa-1"
        self.make_release("Noctalia", old)
        manager.BASE.mkdir(parents=True, exist_ok=True)

        def clone(name, target):
            target.mkdir()
            return "b" * 40

        disk = mock.Mock(free=10 * 1024**3)
        with mock.patch.object(manager, "ensure_deps"), \
             mock.patch.object(manager.shutil, "disk_usage", return_value=disk), \
             mock.patch.object(manager, "clone", side_effect=clone), \
             mock.patch.object(manager, "run", side_effect=RuntimeError("build failed")):
            with self.assertRaisesRegex(RuntimeError, "build failed"):
                manager.install("Noctalia")
        self.assertEqual(manager.metadata("Noctalia")["directory"], old)
        self.assertEqual(len(list(manager.owned("Noctalia").glob("release-*"))), 1)


if __name__ == "__main__":
    unittest.main()
