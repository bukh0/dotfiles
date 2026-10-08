#!/usr/bin/env python3
"""Small byte-safe cliphist bridge. Clipboard content never enters a shell command."""
import base64
import codecs
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def run(args, *, stderr=subprocess.PIPE, **kwargs):
    try:
        return subprocess.run(args, check=True, stderr=stderr, timeout=12, **kwargs)
    except FileNotFoundError:
        raise RuntimeError(f"Required command is missing: {args[0]}") from None
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"{args[0]} took too long. Try again.") from None
    except subprocess.CalledProcessError:
        # Never include process output: it may contain clipboard contents.
        raise RuntimeError(f"{args[0]} could not complete the action. The entry may have expired.") from None


def identifier(value):
    if not re.fullmatch(r"[0-9]+", value):
        raise RuntimeError("Invalid clipboard entry.")
    return value


def image_type(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp"
    # "BM" alone also matches ordinary text such as "BMW" or "BMI".
    # BMP has reserved zero fields and a recognised DIB header length.
    if (len(data) >= 18 and data.startswith(b"BM") and data[6:10] == b"\0" * 4
            and int.from_bytes(data[14:18], "little") in (12, 16, 40, 52, 56, 64, 108, 124)):
        return "image/bmp"
    if data.startswith((b"II*\0", b"MM\0*")):
        return "image/tiff"
    return ""


def active_window():
    try:
        return json.loads(run(["hyprctl", "-j", "activewindow"], stdout=subprocess.PIPE).stdout)
    except (RuntimeError, ValueError):
        return {}


def entries():
    # cliphist 0.7 uses id + preview; don't require newer metadata flags.
    db = Path(os.environ.get("CLIPHIST_DB_PATH", str(Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "cliphist/db")))
    try:
        output = run(["cliphist", "-preview-width", "1000", "list"], stdout=subprocess.PIPE).stdout
    except RuntimeError:
        config = Path(os.environ.get("CLIPHIST_CONFIG_PATH", str(Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "cliphist/config")))
        if not db.exists() and not config.exists():
            return []
        raise
    result = []
    for line in output.decode("utf-8", "replace").splitlines():
        entry_id, sep, label = line.partition("\t")
        if not sep or not entry_id.isdecimal():
            continue
        binary = label.startswith("[[ binary data")
        kind = "image" if binary and re.search(r"\b(png|jpe?g|gif|webp|bmp|tiff?)\b", label, re.I) else "file" if binary else "text"
        if kind == "text" and re.match(r"^https?://\S+$", label.strip()):
            kind = "link"
        result.append({"id": entry_id, "label": label, "kind": kind})
    return result


def decode(entry_id, stream):
    run(["cliphist", "decode", identifier(entry_id)], stdout=stream)
    stream.seek(0)


def preview(entry_id):
    with tempfile.TemporaryFile(buffering=0) as stream:
        decode(entry_id, stream)
        size = os.fstat(stream.fileno()).st_size
        head = stream.read(32)
        mime = image_type(head)
        stream.seek(0)
        if mime:
            # Bound the JSON payload; copying still reads the untouched original.
            if size <= 256 * 1024:
                return {"image": f"data:{mime};base64," + base64.b64encode(stream.read()).decode(), "text": "", "size": size, "mime": mime}
            try:
                with tempfile.TemporaryDirectory(prefix="qs-clipboard-preview-") as directory:
                    target = Path(directory) / "preview.jpg"
                    run(["vipsthumbnail", "--vips-concurrency=1", "--size", "1024x768>",
                         "--path", str(target).replace("%", "%%") + "[Q=80,keep=none]", "--",
                         f"/proc/self/fd/{stream.fileno()}"],
                        pass_fds=(stream.fileno(),), stdout=subprocess.DEVNULL)
                    with target.open("rb") as thumbnail:
                        data = thumbnail.read(512 * 1024 + 1)
                    if len(data) > 512 * 1024:
                        raise RuntimeError("Preview exceeds payload limit")
                return {"image": "data:image/jpeg;base64," + base64.b64encode(data).decode(), "text": "", "size": size, "mime": mime}
            except (RuntimeError, OSError):
                return {"image": "", "text": "Image preview unavailable. You can still copy or paste it.", "size": size, "mime": mime}
        data = stream.read(32768)
        try:
            value = data.decode("utf-8")
        except UnicodeDecodeError:
            value = data.decode("utf-8", "replace")
        if b"\0" in data:
            value = "Binary content. Copy or paste to use this entry."
        elif size > len(data):
            value += "\n\n… Preview shortened; copying preserves the complete entry."
        return {"image": "", "text": value, "size": size, "mime": "text/plain"}


def copy(entry_id):
    with tempfile.TemporaryFile(buffering=0) as stream:
        decode(entry_id, stream)
        mime = image_type(stream.read(32))
        if not mime:
            # Validate incrementally: preserve binary data and avoid a second
            # full-size allocation for large text entries.
            stream.seek(0)
            decoder = codecs.getincrementaldecoder("utf-8")()
            try:
                while chunk := stream.read(65536):
                    if b"\0" in chunk:
                        break
                    decoder.decode(chunk)
                else:
                    decoder.decode(b"", final=True)
                    mime = "text/plain;charset=utf-8"
            except UnicodeDecodeError:
                pass
        stream.seek(0)
        args = ["wl-copy"] + (["--type", mime] if mime else [])
        # The background Wayland owner retains stderr after the parent exits.
        # A PIPE here makes communicate() wait for clipboard ownership to end.
        # Exit status still reports startup errors without capturing contents.
        run(args, stdin=stream, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {}


def paste(address):
    if not address:
        raise RuntimeError("Copied. No window was focused when the clipboard opened. Select a window and press Ctrl+V to paste.")
    current = active_window()
    if current.get("address") != address:
        raise RuntimeError("Copied. Focus changed, so automatic paste was skipped. Press Ctrl+V to paste.")
    terminal = re.search(r"kitty|alacritty|foot|wezterm|ghostty|konsole|term", current.get("class", ""), re.I)
    keys = ["wtype", "-M", "ctrl"]
    if terminal:
        keys += ["-M", "shift"]
    keys += ["-k", "v"]
    if terminal:
        keys += ["-m", "shift"]
    run(keys + ["-m", "ctrl"], stdout=subprocess.DEVNULL)
    return {}


def main(args):
    action = args[0]
    if action == "list":
        return {"entries": entries()}
    if action == "context":
        return {"address": active_window().get("address", "")}
    if action == "preview":
        return preview(args[1])
    if action == "copy":
        return copy(args[1])
    if action == "paste":
        return paste(args[1])
    if action == "delete":
        run(["cliphist", "delete"], input=(identifier(args[1]) + "\n").encode(), stdout=subprocess.DEVNULL)
        return {}
    if action == "wipe":
        run(["cliphist", "wipe"], stdout=subprocess.DEVNULL)
        return {}
    raise RuntimeError("Unknown clipboard action.")


if __name__ == "__main__":
    try:
        response = main(sys.argv[1:])
    except (RuntimeError, OSError, IndexError) as error:
        response = {"error": str(error)}
    print(json.dumps(response, ensure_ascii=True))
