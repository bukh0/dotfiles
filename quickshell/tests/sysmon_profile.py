"""Validate profile output from the built sysmon against malformed cache state."""
import os
from pathlib import Path
import selectors
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="qs-sysmon-profile-") as directory:
    state = Path(directory) / "perf-mode"
    cases = [(None, "auto"), ("", "auto"), (" \t\n", "auto"),
             ("powersave\n", "powersave"), ("performance", "performance"),
             ("auto\n", "auto"), ("invalid\n", "auto"),
             ("performance garbage\n", "auto"), (" performance\n", "auto")]
    for contents, expected in cases:
        if contents is not None:
            state.write_text(contents)
        process = subprocess.Popen([str(ROOT / "native/sysmon"), "none"],
                                   env=dict(os.environ, XDG_CACHE_HOME=directory),
                                   stdout=subprocess.PIPE, text=True)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                assert selector.select(4), "sysmon did not produce a sample"
                fields = process.stdout.readline().rstrip("\n").split("\x1f")
                assert len(fields) == 11 and fields[-1] == expected, (contents, fields)
        finally:
            process.terminate()
            process.wait(timeout=5)
print("PASS sysmon missing, empty, valid, unterminated and malformed profile state")
