#!/usr/bin/env python3
"""Run the available isolated regressions, with explicit skip reporting."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def suites():
    found = {path.stem: path for path in (ROOT / "tests").glob("*/*.py")}
    found.update({"clipboard_" + path.stem.removeprefix("test_"): path
                  for path in (ROOT / "clipboard/tests").glob("test_*.py")})
    return dict(sorted(found.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("names", nargs="*")
    parser.add_argument("--list", action="store_true", help="list available suites")
    parser.add_argument("--all", action="store_true", help="run every available suite (the default)")
    args = parser.parse_args()
    available = suites()
    if args.list:
        print("\n".join(available))
        return 0
    unknown = set(args.names) - available.keys()
    if unknown:
        parser.error("unknown suites: " + ", ".join(sorted(unknown)))
    names = list(available) if args.all or not args.names else args.names
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1",
               PYTHONPATH=str(ROOT / "tests") + os.pathsep + os.environ.get("PYTHONPATH", ""))
    passed, skipped, failed = [], [], []
    for name in names:
        try:
            result = subprocess.run([sys.executable, str(available[name])], cwd=ROOT,
                                    env=env, capture_output=True, text=True, timeout=60)
            output = result.stdout + result.stderr
            code = result.returncode
        except subprocess.TimeoutExpired:
            output, code = "Suite exceeded 60 seconds.", 124
        if code == 77:
            skipped.append(name)
            print(f"SKIP {name}: {output.strip()}", flush=True)
        elif code:
            failed.append(name)
            print(f"FAIL {name}\n{output}", flush=True)
        else:
            passed.append(name)
            print(f"PASS {name}", flush=True)
    print(f"{len(passed)} passed, {len(skipped)} skipped, {len(failed)} failed.")
    return int(bool(failed))


if __name__ == "__main__":
    sys.exit(main())
