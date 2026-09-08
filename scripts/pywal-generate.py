#!/usr/bin/env python3
import os
import shutil
import math
import imagehash
from PIL import Image

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
THEMES = ["catppuccin-mocha", "gruvbox", "tokyonight", "everforest", "material",
          "e-ink", "e-ink-dark", "uncategorized"]

# Upper resolution limits. Images at or above this will NOT be upscaled.
MAX_WIDTH = 1920
MAX_HEIGHT = 1080

# --- Classification tuning ---
BG_WEIGHT = 0.65
ACCENT_WEIGHT = 0.35
ACCENT_CHROMA_FLOOR = 8.0
EINK_CHROMA_THRESHOLD = 10.0       # Tightened average grayscale detection
EINK_MAX_CHROMA_CEILING = 22.0     # Hard limit to reject colorful outliers
REJECT_THRESHOLD = 45.0
MATCH_TOLERANCE = 0.12

ORIGINALS_BACKUP_DIR = os.path.join(WALLPAPER_DIR, ".originals_backup")


def rgb_to_lab(rgb):
    r, g, b = [x / 255.0 for x in rgb]
    r = ((r + 0.055) / 1.055) ** 2.4 if r > 0.04045 else r / 12.92
    g = ((g + 0.055) / 1.055) ** 2.4 if g > 0.04045 else g / 12.92
    b = ((b + 0.055) / 1.055) ** 2.4 if b > 0.04045 else b / 12.92

    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    fx = x ** (1 / 3) if x > 0.008856 else (7.787 * x) + (16 / 116)
    fy = y ** (1 / 3) if y > 0.008856 else (7.787 * y) + (16 / 116)
    fz = z ** (1 / 3) if z > 0.008856 else (7.787 * z) + (16 / 116)

    L = (116 * fy) - 16
    a = 500 * (fx - fy)
    b_val = 200 * (fy - fz)
    return (L, a, b_val)


def delta_e(lab1, lab2):
    return math.sqrt((lab1[0] - lab2[0]) ** 2 + (lab1[1] - lab2[1]) ** 2 + (lab1[2] - lab2[2]) ** 2)


THEME_ANCHORS_RGB = {
    "tokyonight":       {"bg": (26, 27, 38),   "accents": [(122, 162, 247), (157, 124, 216)]},
    "everforest":       {"bg": (45, 53, 59),   "accents": [(167, 192, 128), (131, 192, 146)]},
    "gruvbox":          {"bg": (40, 40, 40),   "accents": [(254, 128, 25),  (215, 153, 33)]},
    "catppuccin-mocha": {"bg": (30, 30, 46),   "accents": [(203, 166, 247), (137, 180, 250)]},
    "material":         {"bg": (18, 18, 18),   "accents": [(187, 134, 252), (3, 218, 198)]},
}

THEME_ANCHORS_LAB = {
    theme: {
        "bg": rgb_to_lab(data["bg"]),
        "accents": [rgb_to_lab(c) for c in data["accents"]],
    }
    for theme, data in THEME_ANCHORS_RGB.items()
}


def smart_upscale(image_path, scale=2.0):
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            if width >= MAX_WIDTH or height >= MAX_HEIGHT:
                return None

            new_width = int(width * scale)
            new_height = int(height * scale)

            os.makedirs(ORIGINALS_BACKUP_DIR, exist_ok=True)
            backup_path = os.path.join(ORIGINALS_BACKUP_DIR, os.path.basename(image_path))
            if not os.path.exists(backup_path):
                shutil.copy2(image_path, backup_path)

            upscaled = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            
            # Prevent pillow warnings by dropping quality kwarg for PNGs
            if img.format == 'PNG':
                upscaled.save(image_path)
            else:
                upscaled.save(image_path, quality=95)
                
            return (os.path.basename(image_path), width, height, new_width, new_height)
    except Exception as e:
        print(f"  Error upscaling {os.path.basename(image_path)}: {e}")
        return None


def extract_palette(image_path, num_colors=8):
    try:
        with Image.open(image_path) as img:
            img = img.resize((160, 160)).convert("P", palette=Image.ADAPTIVE, colors=num_colors)
            palette = img.getpalette()[:num_colors * 3]
            color_counts = sorted(img.getcolors(), reverse=True, key=lambda x: x[0])
            total_pixels = sum(count for count, _ in color_counts)

            colors = []
            for count, idx in color_counts:
                r = palette[idx * 3]
                g = palette[idx * 3 + 1]
                b = palette[idx * 3 + 2]
                weight = count / total_pixels
                colors.append(((r, g, b), weight))
            return colors
    except Exception:
        return None


def classify_image(image_path):
    palette = extract_palette(image_path)
    if not palette:
        return None

    avg_chroma = 0.0
    max_chroma = 0.0
    highest_weight = 0.0
    dom_lightness = 0.0

    for rgb, weight in palette:
        L, a, b = rgb_to_lab(rgb)
        chroma = math.sqrt(a ** 2 + b ** 2)
        
        avg_chroma += chroma * weight
        
        if chroma > max_chroma:
            max_chroma = chroma
            
        if weight > highest_weight:
            highest_weight = weight
            dom_lightness = L

    # Re-applied tight e-ink logic
    if avg_chroma < EINK_CHROMA_THRESHOLD and max_chroma < EINK_MAX_CHROMA_CEILING:
        return "e-ink" if dom_lightness > 50.0 else "e-ink-dark"

    dom_rgb, _ = max(palette, key=lambda p: p[1])
    dom_lab = rgb_to_lab(dom_rgb)

    scores = {}
    for theme, anchors in THEME_ANCHORS_LAB.items():
        bg_delta = delta_e(dom_lab, anchors["bg"])

        accent_delta_total = 0.0
        accent_weight_total = 0.0
        for rgb, weight in palette:
            L, a, b = rgb_to_lab(rgb)
            chroma = math.sqrt(a ** 2 + b ** 2)
            if chroma < ACCENT_CHROMA_FLOOR:
                continue
            w = weight * chroma
            min_d = min(delta_e((L, a, b), t) for t in anchors["accents"])
            accent_delta_total += min_d * w
            accent_weight_total += w

        accent_delta = (accent_delta_total / accent_weight_total) if accent_weight_total > 0 else bg_delta
        scores[theme] = BG_WEIGHT * bg_delta + ACCENT_WEIGHT * accent_delta

    return scores


def remove_duplicates(files):
    print("\nPhase 1: Scanning for visual duplicates...")
    hashes = {}
    deleted_files = set()

    for f in files:
        path = os.path.join(WALLPAPER_DIR, f)
        try:
            with Image.open(path) as img:
                h = str(imagehash.phash(img))
                if h in hashes:
                    hashes[h].append(path)
                else:
                    hashes[h] = [path]
        except Exception as e:
            print(f"  Skipping {f} for hash: {e}")

    for h, paths in hashes.items():
        if len(paths) > 1:
            def get_quality(p):
                try:
                    with Image.open(p) as img:
                        return (img.width * img.height, os.path.getsize(p))
                except Exception:
                    return (0, 0)

            paths.sort(key=get_quality)
            best_image = paths.pop()

            for duplicate in paths:
                print(f"  Deleted duplicate: {os.path.basename(duplicate)} -> Kept: {os.path.basename(best_image)}")
                os.remove(duplicate)
                deleted_files.add(os.path.basename(duplicate))

    return [f for f in files if f not in deleted_files]


def main():
    for theme in THEMES:
        os.makedirs(os.path.join(WALLPAPER_DIR, theme), exist_ok=True)

    valid_exts = ('.jpg', '.jpeg', '.png', '.webp')
    
    # Capture only top-level files, avoiding the generated theme directories
    files = [f for f in os.listdir(WALLPAPER_DIR)
             if f.lower().endswith(valid_exts) and os.path.isfile(os.path.join(WALLPAPER_DIR, f))]

    # Run deduplication BEFORE upscaling to save processing time
    files = remove_duplicates(files)

    print("\nPhase 2: Checking and upscaling low-resolution master images...")
    upscaled_log = []
    for f in files:
        file_path = os.path.join(WALLPAPER_DIR, f)
        result = smart_upscale(file_path, scale=2.0)
        if result:
            upscaled_log.append(result)

    if upscaled_log:
        print(f"\n--- Upscaling Summary ({len(upscaled_log)} images upscaled) ---")
        for name, ow, oh, nw, nh in upscaled_log:
            print(f"  [+] {name}: {ow}x{oh}  --->  {nw}x{nh}  (original backed up)")
        print("-" * 50)
    else:
        print("  No images required upscaling (all met the resolution threshold).")

    print(f"\nPhase 3: Categorizing {len(files)} wallpapers with CIELAB perception...")
    copied_count = 0

    for f in files:
        file_path = os.path.join(WALLPAPER_DIR, f)
        result = classify_image(file_path)

        if result is None:
            continue

        if isinstance(result, str):
            targets = [(result, 0.0)]
        else:
            best_score = min(result.values())
            if best_score > REJECT_THRESHOLD:
                targets = [("uncategorized", best_score)]
            else:
                cutoff = best_score * (1 + MATCH_TOLERANCE)
                targets = [(t, s) for t, s in result.items() if s <= cutoff]

        for theme, score in targets:
            dest_path = os.path.join(WALLPAPER_DIR, theme, f)
            if not os.path.exists(dest_path):
                shutil.copy2(file_path, dest_path)
                tag = f" (ΔE {score:.1f})" if score else ""
                print(f"  Copied -> [{theme}] {f}{tag}")
                copied_count += 1

    print(f"\nOperation complete. Processed and sorted {copied_count} wallpaper placements.")


if __name__ == "__main__":
    main()
