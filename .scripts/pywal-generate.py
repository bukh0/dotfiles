#!/usr/bin/env python3
import os
import shutil
import math
import imagehash
from PIL import Image

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
THEMES = ["catppuccin-mocha", "gruvbox", "tokyonight", "everforest", "material", "e-ink", "e-ink-dark"]

# Define your upper limits. Images at or above this resolution will NOT be upscaled.
MAX_WIDTH = 1920
MAX_HEIGHT = 1080

def rgb_to_lab(rgb):
    r, g, b = [x / 255.0 for x in rgb]
    r = ((r + 0.055) / 1.055) ** 2.4 if r > 0.04045 else r / 12.92
    g = ((g + 0.055) / 1.055) ** 2.4 if g > 0.04045 else g / 12.92
    b = ((b + 0.055) / 1.055) ** 2.4 if b > 0.04045 else b / 12.92

    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883

    fx = x ** (1/3) if x > 0.008856 else (7.787 * x) + (16 / 116)
    fy = y ** (1/3) if y > 0.008856 else (7.787 * y) + (16 / 116)
    fz = z ** (1/3) if z > 0.008856 else (7.787 * z) + (16 / 116)

    L = (116 * fy) - 16
    a = 500 * (fx - fy)
    b_val = 200 * (fy - fz)
    return (L, a, b_val)

def delta_e(lab1, lab2):
    return math.sqrt((lab1[0] - lab2[0])**2 + (lab1[1] - lab2[1])**2 + (lab1[2] - lab2[2])**2)

THEME_LAB = {
    "tokyonight": [rgb_to_lab((122, 162, 247)), rgb_to_lab((157, 124, 216)), rgb_to_lab((26, 27, 38))],
    "everforest": [rgb_to_lab((167, 192, 128)), rgb_to_lab((131, 192, 146)), rgb_to_lab((45, 53, 59))],
    "gruvbox":    [rgb_to_lab((254, 128, 25)),  rgb_to_lab((215, 153, 33)),  rgb_to_lab((40, 40, 40))],
    "catppuccin-mocha": [rgb_to_lab((203, 166, 247)), rgb_to_lab((137, 180, 250)), rgb_to_lab((30, 30, 46))],
    "material":   [rgb_to_lab((187, 134, 252)), rgb_to_lab((3, 218, 198)),   rgb_to_lab((18, 18, 18))]
}

def smart_upscale(image_path, scale=2.0):
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            if width >= MAX_WIDTH or height >= MAX_HEIGHT:
                return None

            new_width = int(width * scale)
            new_height = int(height * scale)
            upscaled = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            upscaled.save(image_path, quality=95)
            return (os.path.basename(image_path), width, height, new_width, new_height)
    except Exception as e:
        print(f"  Error upscaling {os.path.basename(image_path)}: {e}")
        return None

def extract_palette(image_path, num_colors=6):
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
    avg_lightness = 0.0
    for rgb, weight in palette:
        L, a, b = rgb_to_lab(rgb)
        chroma = math.sqrt(a**2 + b**2)
        avg_chroma += chroma * weight
        avg_lightness += L * weight

    if avg_chroma < 12.0:
        return "e-ink" if avg_lightness > 50.0 else "e-ink-dark"

    theme_scores = {theme: 0.0 for theme in THEME_LAB}
    for rgb, weight in palette:
        L, a, b = rgb_to_lab(rgb)
        chroma = math.sqrt(a**2 + b**2)
        pixel_weight = weight * (1.0 + (chroma / 25.0))

        for theme, target_labs in THEME_LAB.items():
            min_dist = min(delta_e((L, a, b), t_lab) for t_lab in target_labs)
            theme_scores[theme] += min_dist * pixel_weight

    return min(theme_scores, key=theme_scores.get)

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
    files = [f for f in os.listdir(WALLPAPER_DIR) 
             if f.lower().endswith(valid_exts) and os.path.isfile(os.path.join(WALLPAPER_DIR, f))]

    # Step 1: Upscale low-res master images & track them
    print("Checking and upscaling low-resolution master images...")
    upscaled_log = []
    for f in files:
        file_path = os.path.join(WALLPAPER_DIR, f)
        result = smart_upscale(file_path, scale=2.0)
        if result:
            upscaled_log.append(result)

    if upscaled_log:
        print(f"\n--- Upscaling Summary ({len(upscaled_log)} images upscaled) ---")
        for name, ow, oh, nw, nh in upscaled_log:
            print(f"  [+] {name}: {ow}x{oh}  --->  {nw}x{nh}")
        print("-" * 50)
    else:
        print("  No images required upscaling (all met the resolution threshold).")

    # Step 2: Run deduplication
    files = remove_duplicates(files)

    # Step 3: Categorize and copy into theme directories
    print(f"\nPhase 2: Categorizing {len(files)} wallpapers with CIELAB perception...")
    copied_count = 0
    
    for f in files:
        file_path = os.path.join(WALLPAPER_DIR, f)
        assigned_theme = classify_image(file_path)

        if assigned_theme:
            dest_path = os.path.join(WALLPAPER_DIR, assigned_theme, f)
            if not os.path.exists(dest_path):
                shutil.copy2(file_path, dest_path)
                print(f"  Copied -> [{assigned_theme}] {f}")
                copied_count += 1

    print(f"\nOperation complete. Processed and sorted {copied_count} wallpapers.")

if __name__ == "__main__":
    main()
