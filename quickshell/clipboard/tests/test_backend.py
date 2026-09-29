#!/usr/bin/env python3
"""Isolated integration tests with a real cliphist database and mock Wayland tools."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("backend", ROOT / "backend.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class ClipboardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="clipboard-test-")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.old = os.environ.copy()
        self.addCleanup(self.restore)
        os.environ.update(CLIPHIST_DB_PATH=str(self.path / "db"), CLIPHIST_CONFIG_PATH=str(self.path / "config"),
                          XDG_CACHE_HOME=str(self.path), TEST_ROOT=str(self.path),
                          PATH=str(self.path) + os.pathsep + os.environ["PATH"])
        (self.path / "wl-copy").write_text("#!/usr/bin/env python3\nimport os, pathlib, sys\np = pathlib.Path(os.environ['TEST_ROOT'])\n(p/'copied').write_bytes(sys.stdin.buffer.read())\n(p/'mime').write_text(' '.join(sys.argv[1:]))\n")
        (self.path / "hyprctl").write_text("#!/usr/bin/env python3\nimport os, pathlib\nprint((pathlib.Path(os.environ['TEST_ROOT'])/'window').read_text())\n")
        (self.path / "wtype").write_text("#!/usr/bin/env python3\nimport os, pathlib, sys\n(pathlib.Path(os.environ['TEST_ROOT'])/'keys').write_text(' '.join(sys.argv[1:]))\n")
        for name in ("wl-copy", "hyprctl", "wtype"):
            (self.path / name).chmod(0o755)

    def restore(self):
        os.environ.clear()
        os.environ.update(self.old)

    def store(self, value):
        subprocess.run(["cliphist", "store"], input=value, check=True, capture_output=True)
        return backend.entries()[0]["id"]

    def test_exact_text_and_no_shell_execution(self):
        value = b"  first\n\n\tsecond\n$(touch /tmp/clipboard-injection) `echo nope`\n"
        entry = self.store(value)
        self.assertEqual(backend.preview(entry)["text"], value.decode())
        backend.copy(entry)
        self.assertEqual((self.path / "copied").read_bytes(), value)

    def test_image(self):
        value = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6VZkAAAAASUVORK5CYII=")
        entry = self.store(value)
        self.assertEqual(backend.entries()[0]["kind"], "image")
        self.assertTrue(backend.preview(entry)["image"].startswith("data:image/png;base64,"))
        backend.copy(entry)
        self.assertEqual((self.path / "copied").read_bytes(), value)
        self.assertEqual((self.path / "mime").read_text(), "--type image/png")

    def test_background_clipboard_owner_does_not_block(self):
        entry = self.store(b"copied by a background owner")
        owner = self.path / "wl-copy"
        owner.write_text("""#!/usr/bin/env python3
import os, pathlib, sys, time
p = pathlib.Path(os.environ['TEST_ROOT'])
(p/'copied').write_bytes(sys.stdin.buffer.read())
if os.fork(): os._exit(0)
# Model wl-copy's daemon: stdin/stdout are closed, stderr stays inherited.
os.close(0)
os.close(1)
time.sleep(2)
os._exit(0)
""")
        original_run = subprocess.run
        def bounded_run(*args, **kwargs):
            kwargs["timeout"] = 0.8
            return original_run(*args, **kwargs)
        with mock.patch.object(backend.subprocess, "run", side_effect=bounded_run):
            backend.copy(entry)
        self.assertEqual((self.path / "copied").read_bytes(), b"copied by a background owner")

    def test_copy_failure_is_still_reported(self):
        entry = self.store(b"do not lose failure reporting")
        (self.path / "wl-copy").write_text("#!/bin/sh\nexit 1\n")
        with self.assertRaisesRegex(RuntimeError, "wl-copy could not complete"):
            backend.copy(entry)

    def test_delete_and_wipe(self):
        self.store(b"keep this")
        entry = self.store(b"delete this")
        backend.main(["delete", entry])
        self.assertEqual(len(backend.entries()), 1)
        self.assertEqual(backend.entries()[0]["label"], "keep this")
        backend.main(["wipe"])
        self.assertEqual(backend.entries(), [])

    def test_missing_and_invalid_entry_never_copy(self):
        self.store(b"something")
        for entry in ("9999999", "1; echo secret", "-1"):
            with self.assertRaises(RuntimeError):
                backend.copy(entry)
        self.assertFalse((self.path / "copied").exists())

    def test_new_database(self):
        self.assertEqual(backend.entries(), [])

    def test_large_preview_preserves_copy(self):
        value = ("some text with unicode →\n" * 5000).encode()
        entry = self.store(value)
        self.assertLess(len(backend.preview(entry)["text"]), 34000)
        backend.copy(entry)
        self.assertEqual((self.path / "copied").read_bytes(), value)

    def test_focus_guard_and_terminal_paste(self):
        (self.path / "window").write_text(json.dumps({"address": "0xabc", "class": "kitty"}))
        with self.assertRaises(RuntimeError):
            backend.paste("0xother")
        self.assertFalse((self.path / "keys").exists())
        backend.paste("0xabc")
        self.assertIn("-M shift", (self.path / "keys").read_text())
        (self.path / "window").write_text(json.dumps({"address": "0xabc", "class": "firefox"}))
        backend.paste("0xabc")
        self.assertNotIn("shift", (self.path / "keys").read_text())


if __name__ == "__main__":
    unittest.main()
