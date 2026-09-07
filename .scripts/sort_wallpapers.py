#!/usr/bin/env python3
import os
import shutil
import math
import imagehash
from PIL import Image

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
THEMES = ["catppuccin-mocha", "gruvbox", "tokyonight", "everforest", "material", "e-ink", "e-ink-dark"]

THEME_PALETTES = {
    "e-ink": [(232, 228, 216), (200, 200, 200), (250, 250, 250)],
    "e-ink-dark": [(24, 24, 24), (92, 92, 92), (74, 74, 74)],
    "tokyonight": [(26, 27, 38), (122, 162, 247), (86, 95, 137)],
    "everforest": [(43, 51, 57), (167, 192, 128), (127, 187, 179)],
    "gruvbox": [(40, 40, 40), (254, 128, 25), (215, 153, 33)],
    "catppuccin-mocha": [(30, 30, 46), (203, 166, 247), (243, 139, 168)],
    "material": [(18, 18, 18), (187, 134, 252), (3, 218, 198)]
}

def color_distance(c1, c2):
    return math.sqrt((c1[0] - c2[0])**2 + (c1[1] - c2[1])**2 + (c1[2] - c2[2])**2)

def get_dominant_color(image_path):
    try:
        img = Image.open(image_path).resize((150, 150)).convert("RGB")
        img_quant = img.quantize(colors=1).convert("RGB")
        return img_quant.getpixel((0, 0))
    except Exception:
        return None

def classify_image(image_path):
    dom_color = get_dominant_color(image_path)
    if not dom_color:
        return None

    best_theme = None
    min_dist = float('inf')

    for theme, colors in THEME_PALETTES.items():
        for target_color in colors:
            dist = color_distance(dom_color, target_color)
            if dist < min_dist:
                min_dist = dist
                best_theme = theme

    return best_theme

def remove_duplicates(files):
    print("Phase 1: Scanning for visual duplicates...")
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
                        resolution = img.width * img.height
                    return (resolution, os.path.getsize(p))
                except:
                    return (0, 0)
            
            paths.sort(key=get_quality)
            best_image = paths.pop() 
            
            for duplicate in paths:
                print(f"  Deleted lower quality: {os.path.basename(duplicate)} -> Kept: {os.path.basename(best_image)}")
                os.remove(duplicate)
                deleted_files.add(os.path.basename(duplicate))
                
    return [f for f in files if f not in deleted_files]

def main():
    for theme in THEMES:
        os.makedirs(os.path.join(WALLPAPER_DIR, theme), exist_ok=True)

    valid_exts = ('.jpg', '.jpeg', '.png', '.webp', '.gif')
    files = [f for f in os.listdir(WALLPAPER_DIR) 
             if f.lower().endswith(valid_exts) and os.path.isfile(os.path.join(WALLPAPER_DIR, f))]

    # Run the deduplication pass
    files = remove_duplicates(files)

    print(f"\nPhase 2: Categorizing {len(files)} unique images...")
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
            else:
                pass 

    print(f"\nOperation complete. Copied {copied_count} new wallpapers to theme folders.")

if __name__ == "__main__":
    main()
