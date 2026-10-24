"""Pre-generate 44x44 icon thumbnails for instant UI rendering"""

import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcons_core

def generate_all():
    windows_dir = os.path.dirname(os.path.abspath(__file__))
    thumb_dir = os.path.join(windows_dir, "thumbnails")
    os.makedirs(thumb_dir, exist_ok=True)

    packs = mcons_core.load_all_packs()
    count = 0
    for p in packs:
        for i in p["icons"]:
            fname = f"{p['id']}_{os.path.splitext(i['file'])[0]}.png"
            tpath = os.path.join(thumb_dir, fname)
            if not os.path.exists(tpath):
                im = mcons_core.extract_image_from_svg(i["path"])
                if im:
                    im_thumb = im.resize((44, 44), Image.Resampling.LANCZOS)
                    im_thumb.save(tpath, format="PNG")
                    count += 1

    print(f"Generated {count} thumbnails in {thumb_dir}")

if __name__ == "__main__":
    generate_all()
