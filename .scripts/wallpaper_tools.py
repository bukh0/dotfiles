#!/usr/bin/env python3
import os
import shutil
import math
from PIL import Image, ImageOps
from typing import Dict, List, Optional, Tuple, Union


RGB = Tuple[int, int, int]
LAB = Tuple[float, float, float]
Palette = List[Tuple[RGB, float]]
Classification = Union[str, Dict[str, float]]

THEMES = [
    "catppuccin-mocha",
    "gruvbox",
    "tokyonight",
    "everforest",
    "material",
    "e-ink",
    "e-ink-dark",
    "uncategorized",
]

# These are deliberately broad theme profiles rather than exact color matches.
# A wallpaper is suitable when its background and visible accents agree with a
# profile; dark images without usable color evidence are not forced into one.
THEME_ANCHORS_RGB = {
    "tokyonight": {"bg": (26, 27, 38), "accents": [(122, 162, 247), (157, 124, 216)]},
    "everforest": {"bg": (45, 53, 59), "accents": [(167, 192, 128), (131, 192, 146)]},
    "gruvbox": {"bg": (40, 40, 40), "accents": [(254, 128, 25), (215, 153, 33)]},
    "catppuccin-mocha": {"bg": (30, 30, 46), "accents": [(203, 166, 247), (137, 180, 250)]},
    "material": {"bg": (18, 18, 18), "accents": [(187, 134, 252), (3, 218, 198)]},
}

ACCENT_CHROMA_FLOOR = 10.0
BACKGROUND_CHROMA_CEILING = 18.0
EINK_NEUTRAL_CHROMA_CEILING = 7.0
EINK_NEUTRAL_WEIGHT_MIN = 0.95
EINK_MAX_CHROMA_CEILING = 12.0
MIN_ACCENT_WEIGHT = 0.12
REJECT_THRESHOLD = 42.0


def rgb_to_lab(rgb: RGB) -> LAB:
    r, g, b = [channel / 255.0 for channel in rgb]
    r = ((r + 0.055) / 1.055) ** 2.4 if r > 0.04045 else r / 12.92
    g = ((g + 0.055) / 1.055) ** 2.4 if g > 0.04045 else g / 12.92
    b = ((b + 0.055) / 1.055) ** 2.4 if b > 0.04045 else b / 12.92

    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722)
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    fx = x ** (1 / 3) if x > 0.008856 else (7.787 * x) + (16 / 116)
    fy = y ** (1 / 3) if y > 0.008856 else (7.787 * y) + (16 / 116)
    fz = z ** (1 / 3) if z > 0.008856 else (7.787 * z) + (16 / 116)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


THEME_ANCHORS_LAB = {
    theme: {
        "bg": rgb_to_lab(data["bg"]),
        "accents": [rgb_to_lab(color) for color in data["accents"]],
    }
    for theme, data in THEME_ANCHORS_RGB.items()
}


def delta_e(first: LAB, second: LAB) -> float:
    return math.sqrt(sum((left - right) ** 2 for left, right in zip(first, second)))


def _chroma(lab: LAB) -> float:
    return math.hypot(lab[1], lab[2])


def extract_palette(image_path: str, num_colors: int = 12) -> Optional[Palette]:
    try:
        with Image.open(image_path) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            image.thumbnail((240, 240), Image.Resampling.BILINEAR)
            quantized = image.convert("P", palette=Image.Palette.ADAPTIVE, colors=num_colors)
            palette = quantized.getpalette()[: num_colors * 3]
            color_counts = sorted(
                quantized.getcolors() or [], reverse=True, key=lambda item: item[0]
            )
            total_pixels = sum(count for count, _ in color_counts)
            if not total_pixels:
                return None

            return [
                (
                    (
                        palette[index * 3],
                        palette[index * 3 + 1],
                        palette[index * 3 + 2],
                    ),
                    count / total_pixels,
                )
                for count, index in color_counts
            ]
    except (OSError, ValueError, IndexError):
        return None


def _background_lab(palette: Palette) -> LAB:
    neutral = [
        (rgb_to_lab(rgb), weight)
        for rgb, weight in palette
        if _chroma(rgb_to_lab(rgb)) <= BACKGROUND_CHROMA_CEILING
    ]
    if not neutral:
        return rgb_to_lab(max(palette, key=lambda item: item[1])[0])

    total_weight = sum(weight for _, weight in neutral)
    return tuple(
        sum(lab[index] * weight for lab, weight in neutral) / total_weight
        for index in range(3)
    )  # type: ignore[return-value]


def classify_wallpaper(image_path: str) -> Optional[Classification]:
    """Return an e-ink theme or per-theme suitability scores (lower is better)."""
    palette = extract_palette(image_path)
    if not palette:
        return None

    labs = [(rgb_to_lab(rgb), weight) for rgb, weight in palette]
    neutral_weight = sum(
        weight for lab, weight in labs if _chroma(lab) <= EINK_NEUTRAL_CHROMA_CEILING
    )
    max_chroma = max(_chroma(lab) for lab, _ in labs)
    dominant_lab, _ = max(labs, key=lambda item: item[1])

    if neutral_weight >= EINK_NEUTRAL_WEIGHT_MIN and max_chroma <= EINK_MAX_CHROMA_CEILING:
        return "e-ink" if dominant_lab[0] > 50.0 else "e-ink-dark"

    accent_weight = sum(weight for lab, weight in labs if _chroma(lab) >= ACCENT_CHROMA_FLOOR)
    if accent_weight < MIN_ACCENT_WEIGHT:
        return {"uncategorized": REJECT_THRESHOLD + 1.0}

    background = _background_lab(palette)
    scores: Dict[str, float] = {}
    for theme, anchors in THEME_ANCHORS_LAB.items():
        background_score = delta_e(background, anchors["bg"])

        accent_score = 0.0
        accent_total = 0.0
        for lab, weight in labs:
            chroma = _chroma(lab)
            if chroma < ACCENT_CHROMA_FLOOR:
                continue
            weighted_chroma = weight * chroma
            accent_score += min(delta_e(lab, anchor) for anchor in anchors["accents"]) * weighted_chroma
            accent_total += weighted_chroma
        accent_score = accent_score / accent_total if accent_total else REJECT_THRESHOLD

        # Penalize themes that only match the background when the image has
        # strong, conflicting accents.
        dominant_score = min(delta_e(dominant_lab, anchor) for anchor in anchors["accents"])
        scores[theme] = (
            background_score * 0.45
            + accent_score * 0.40
            + dominant_score * 0.15
        )

    return scores


def suitable_themes(
    classification: Optional[Classification],
    tolerance: float = 0.05,
) -> List[Tuple[str, float]]:
    """Convert a classification into stable copy targets for a sorter."""
    if not classification:
        return []
    if isinstance(classification, str):
        return [(classification, 0.0)]

    best_score = min(classification.values())
    if best_score > REJECT_THRESHOLD:
        return [("uncategorized", best_score)]

    cutoff = best_score * (1.0 + tolerance)
    return sorted(
        ((theme, score) for theme, score in classification.items() if score <= cutoff),
        key=lambda item: item[1],
    )


# Shared file operations for the three historical entry points.
import argparse
import hashlib
import json
import tempfile
import fcntl
from pathlib import Path

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def atomic_bytes(destination, content, mode=0o644):
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix="." + destination.name + ".", dir=destination.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(content)
        os.chmod(temporary, mode)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def archive(path, root):
    directory = root / "Deletions"
    directory.mkdir(exist_ok=True)
    target = directory / path.name
    number = 0
    while target.exists():
        number += 1
        target = directory / f"{path.stem} ({number}){path.suffix}"
    shutil.move(str(path), target)
    print(f"Archived {path.name} -> {target}")


def remove_duplicates(files, root, dry_run=False):
    """Only identical file contents qualify; perceptual hashes can collide."""
    seen = {}
    retained = []
    for path in files:
        fingerprint = digest(path)
        if fingerprint in seen:
            print(f"Duplicate: {path.name} (same contents as {seen[fingerprint].name})")
            if not dry_run:
                archive(path, root)
        else:
            seen[fingerprint] = path
            retained.append(path)
    return retained


def smart_upscale(path, root, scale=2.0):
    """Bounded, atomic, opt-in resizing; animated originals remain intact."""
    path = Path(path)
    if not math.isfinite(scale) or scale <= 1:
        return None
    with Image.open(path) as original:
        if getattr(original, "n_frames", 1) > 1:
            return None
        image = ImageOps.exif_transpose(original)
        width, height = image.size
        factor = min(scale, 1920 / width, 1080 / height)
        if factor <= 1:
            return None
        size = (max(1, int(width * factor)), max(1, int(height * factor)))
        backups = root / ".originals_backup"
        backups.mkdir(exist_ok=True)
        backup = backups / f"{path.stem}-{digest(path)[:16]}{path.suffix}"
        if not backup.exists():
            shutil.copy2(path, backup)
        fd, temporary = tempfile.mkstemp(prefix=".upscale-", suffix=path.suffix, dir=path.parent)
        os.close(fd)
        try:
            resized = image.resize(size, Image.Resampling.LANCZOS)
            options = {"quality": 95} if original.format in {"JPEG", "WEBP"} else {}
            resized.save(temporary, format=original.format, **options)
            os.chmod(temporary, path.stat().st_mode & 0o777)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return (width, height, *size)


def process_directory(root, *, deduplicate=False, upscale=False, dry_run=False, sync=False):
    root = Path(root).expanduser().resolve()
    if not root.is_dir():
        raise ValueError(f"Wallpaper directory does not exist: {root}")
    manifest_path = root / ".wallpaper-index.json"
    if manifest_path.exists():
        state = json.loads(manifest_path.read_text())
        if not isinstance(state, dict) or not isinstance(state.get("copies", {}), dict) or not isinstance(state.get("upscaled", {}), dict):
            raise ValueError("Invalid wallpaper index; restore it before continuing")
    else:
        state = {}
    copies = state.setdefault("copies", {})
    resized = state.setdefault("upscaled", {})
    files = sorted(p for p in root.iterdir() if p.is_file() and not p.is_symlink() and p.suffix.lower() in IMAGE_EXTENSIONS)
    if deduplicate:
        files = remove_duplicates(files, root, dry_run)
    desired = set()
    unreadable = set()
    names = {p.name for p in files}
    for path in files:
        if upscale and resized.get(path.name) != digest(path):
            if dry_run:
                print(f"Would check upscale: {path.name}")
            elif smart_upscale(path, root):
                resized[path.name] = digest(path)
        result = classify_wallpaper(str(path))
        if result is None:
            unreadable.add(path.name)
            print(f"Cannot classify: {path.name}; retaining existing copies")
            continue
        fingerprint = digest(path)
        for theme, _ in suitable_themes(result):
            relative = f"{theme}/{path.name}"
            desired.add(relative)
            target = root / relative
            # An existing theme image may have been curated by hand.
            if target.exists():
                existing = digest(target)
                if existing == fingerprint:
                    continue
                if copies.get(relative) != existing:
                    print(f"Preserving independently edited image: {relative}")
                    continue
            print(f"Copy: {path.name} -> {theme}")
            if not dry_run:
                atomic_bytes(target, path.read_bytes(), path.stat().st_mode & 0o777)
                copies[relative] = fingerprint
    for relative, fingerprint in list(copies.items()):
        path = Path(relative)
        # Index entries are data, never arbitrary paths to remove.
        if path.is_absolute() or len(path.parts) != 2 or path.parts[0] not in THEMES:
            continue
        if relative in desired or path.name in unreadable:
            continue
        if path.name not in names and not sync:
            continue
        target = root / path
        if target.is_file() and not target.is_symlink() and digest(target) == fingerprint:
            print(f"Stale generated copy: {relative}")
            if not dry_run:
                archive(target, root)
        if not dry_run:
            del copies[relative]
    if not dry_run:
        atomic_bytes(manifest_path, (json.dumps(state, indent=2) + "\n").encode())


def main(sync=False):
    parser = argparse.ArgumentParser(description="Classify wallpapers without deleting originals or overwriting curated images.")
    parser.add_argument("--directory", type=Path, default=Path.home() / "Pictures/Wallpapers")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--deduplicate", action="store_true", help="archive exact duplicate files in Deletions/")
    parser.add_argument("--upscale", action="store_true", help="resize static images up to 1920x1080, preserving backups")
    args = parser.parse_args()
    # Dry runs are read-only and must work for read-only wallpaper libraries.
    if args.dry_run:
        try:
            process_directory(args.directory, deduplicate=args.deduplicate, upscale=args.upscale,
                              dry_run=True, sync=sync)
        except (OSError, ValueError) as error:
            parser.exit(1, f"Wallpaper operation failed: {error}\n")
        return
    # Keep coordination state outside the image library. All entry points
    # hash the same canonical path and hold the same lock.
    lock_root = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    lock_root.mkdir(parents=True, exist_ok=True)
    lock_name = hashlib.sha256(str(args.directory.expanduser().resolve()).encode()).hexdigest()
    try:
        with open(lock_root / f"wallpaper-tools-{lock_name}.lock", "a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            process_directory(args.directory, deduplicate=args.deduplicate, upscale=args.upscale,
                              dry_run=args.dry_run, sync=sync)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Wallpaper operation failed: {error}\n")
