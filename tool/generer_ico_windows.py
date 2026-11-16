"""Génère windows/runner/resources/app_icon.ico à partir de assets/icon.png,
avec des coins arrondis (rayon 25 %) sur fond transparent, comme Réviser et Cartable."""
from pathlib import Path
from PIL import Image, ImageDraw

RACINE = Path(__file__).resolve().parent.parent
SOURCE = RACINE / "assets" / "icon.png"
SORTIE = RACINE / "windows" / "runner" / "resources" / "app_icon.ico"
RAYON = 0.25
TAILLES = [16, 24, 32, 48, 64, 128, 256]


def arrondi(img, taille):
    f = 8  # suréchantillonnage pour lisser les bords
    g = taille * f
    masque = Image.new("L", (g, g), 0)
    ImageDraw.Draw(masque).rounded_rectangle((0, 0, g - 1, g - 1), radius=RAYON * g, fill=255)
    masque = masque.resize((taille, taille), Image.LANCZOS)
    out = img.convert("RGBA").resize((taille, taille), Image.LANCZOS)
    out.putalpha(masque)
    return out


if __name__ == "__main__":
    src = Image.open(SOURCE)
    images = [arrondi(src, t) for t in TAILLES]
    images[-1].save(SORTIE, format="ICO", sizes=[(t, t) for t in TAILLES],
                    append_images=images[:-1], bitmap_format="png")
    print("OK", SORTIE)
