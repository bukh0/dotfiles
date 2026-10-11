"""Regression checks for the curated wallpaper preset list and entry points."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
import wallpaper_tools as wallpapers


class WallpaperThemeTests(unittest.TestCase):
    def make_wallpaper(self, root, theme):
        profile = wallpapers.THEME_ANCHORS_RGB[theme]
        image = Image.new("RGB", (120, 100), profile["bg"])
        draw = ImageDraw.Draw(image)
        for index, color in enumerate(profile["accents"]):
            draw.rectangle((index * 40, 60, index * 40 + 39, 99), fill=color)
        path = root / f"{theme}.png"
        image.save(path)
        return path

    def snapshot(self, root):
        return {str(p.relative_to(root)): p.read_bytes() if p.is_file() else None
                for p in root.rglob("*")}

    def test_new_classic_palettes(self):
        with tempfile.TemporaryDirectory() as directory:
            for theme in ("dracula", "nord", "solarized-dark"):
                with self.subTest(theme=theme):
                    path = self.make_wallpaper(Path(directory), theme)
                    targets = wallpapers.suitable_themes(wallpapers.classify_wallpaper(str(path)))
                    self.assertEqual([name for name, _ in targets], [theme])

    def test_retained_profiles_and_monochrome(self):
        self.assertEqual(set(wallpapers.THEMES), {
            "catppuccin-mocha", "dracula", "nord", "gruvbox", "everforest",
            "tokyonight", "solarized-dark", "e-ink", "e-ink-dark", "uncategorized",
        })
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "neutral.png"
            for gray, expected in ((240, "e-ink"), (20, "e-ink-dark")):
                Image.new("RGB", (32, 32), (gray,) * 3).save(path)
                self.assertEqual(wallpapers.classify_wallpaper(str(path)), expected)

    def test_entry_points_preserve_library(self):
        for script in ("wallpaper_manager.py", "sort_wallpapers.py", "pywal-generate.py"):
            with self.subTest(script=script), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / "wallpapers"
                root.mkdir()
                for theme in ("dracula", "nord", "solarized-dark"):
                    self.make_wallpaper(root, theme)
                # Retired folders and their index entries must not be pruned,
                # even by the manager's sync mode.
                retired = root / "material" / "old.png"
                retired.parent.mkdir()
                Image.new("RGB", (8, 8), "red").save(retired)
                index = {"copies": {"material/old.png": wallpapers.digest(retired)}}
                (root / ".wallpaper-index.json").write_text(json.dumps(index))
                curated = root / "nord" / "nord.png"
                curated.parent.mkdir()
                Image.new("RGB", (8, 8), "white").save(curated)
                before = self.snapshot(root)
                env = dict(os.environ, XDG_CACHE_HOME=str(Path(directory) / "cache"))
                command = [sys.executable, str(SCRIPTS / script), "--directory", str(root)]
                subprocess.run(command + ["--dry-run"], env=env, check=True, capture_output=True)
                self.assertEqual(self.snapshot(root), before)
                subprocess.run(command, env=env, check=True, capture_output=True)
                for relative, contents in before.items():
                    if contents is not None and relative != ".wallpaper-index.json":
                        self.assertEqual((root / relative).read_bytes(), contents)
                for theme in ("dracula", "solarized-dark"):
                    self.assertEqual((root / theme / f"{theme}.png").read_bytes(),
                                     (root / f"{theme}.png").read_bytes())
                updated = json.loads((root / ".wallpaper-index.json").read_text())
                self.assertEqual(updated["copies"]["material/old.png"],
                                 index["copies"]["material/old.png"])


if __name__ == "__main__":
    unittest.main()
