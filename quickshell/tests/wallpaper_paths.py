"""Managed wallpaper folders cannot redirect writes outside the wallpaper root."""
import importlib.util
import os
from pathlib import Path
import tempfile
from unittest.mock import patch

source = Path(os.environ.get("REVIEW_SCRIPTS_DIR", str(Path.home() / ".scripts"))) / "wallpaper_tools.py"
spec = importlib.util.spec_from_file_location("wallpaper_tools", source)
tools = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tools)

with tempfile.TemporaryDirectory() as directory:
    base = Path(directory)
    root = base / "walls"
    root.mkdir()
    outside = base / "outside"
    outside.mkdir()
    (outside / "keep.jpg").write_bytes(b"unchanged")
    for name in [tools.THEMES[0], "Deletions", ".originals_backup"]:
        link = root / name
        link.symlink_to(outside, target_is_directory=True)
        try:
            tools.process_directory(root, sync=True, deduplicate=True, upscale=True)
            raise AssertionError("symlinked managed directory accepted")
        except ValueError as error:
            assert "symlink" in str(error)
        link.unlink()
        assert (outside / "keep.jpg").read_bytes() == b"unchanged"
        assert not (root / ".wallpaper-index.json").exists()
    theme = root / tools.THEMES[0]
    theme.mkdir()
    (root / "keep.jpg").write_bytes(b"new image")
    (theme / "keep.jpg").symlink_to(outside / "keep.jpg")
    with patch.object(tools, "classify_wallpaper", return_value={}), patch.object(
            tools, "suitable_themes", return_value=[(tools.THEMES[0], 0)]):
        tools.process_directory(root)
    assert (theme / "keep.jpg").is_symlink()
    assert (outside / "keep.jpg").read_bytes() == b"unchanged"
print("PASS wallpaper directory containment and curated file symlinks")
