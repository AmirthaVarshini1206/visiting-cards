from pathlib import Path
import os
import glob

BASE_DIR = Path("e:\\visiting card").resolve()
INPUT_FOLDER = BASE_DIR / "visiting_cards"

print(f"Current Working Directory: {os.getcwd()}")
print(f"BASE_DIR: {BASE_DIR}")
print(f"INPUT_FOLDER: {INPUT_FOLDER}")
print(f"Exists: {INPUT_FOLDER.exists()}")
if INPUT_FOLDER.exists():
    print(f"Is Dir: {INPUT_FOLDER.is_dir()}")
    files = list(INPUT_FOLDER.glob("*"))
    print(f"Files in input folder: {len(files)}")
    match = list(INPUT_FOLDER.glob("*.jpeg"))
    print(f"JPEG matches: {len(match)}")
    
    # Check casing extensions
    extensions = ["*.jpg", "*.jpeg", "*.png", "*.heic", "*.JPG", "*.JPEG", "*.PNG"]
    image_files = set()
    for ext in extensions:
        found = list(INPUT_FOLDER.glob(ext))
        print(f"Extension {ext}: {len(found)}")
        image_files.update(found)
    print(f"Total image files found: {len(image_files)}")
