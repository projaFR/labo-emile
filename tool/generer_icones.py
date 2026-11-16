"""Compose toutes les icônes du Labo à partir de captures/_dessin.png
(produit par tool/generer_icone_test.dart) : fond en dégradé bleu, reflet,
masque squircle (n = 4,4, mesuré sur Réviser/Cartable), calque Android, web, .ico.
Teinte : Réviser 268,6 / Cartable 240,2 -> Labo 211,8 (même écart de -28,4)."""
import colorsys
from pathlib import Path
import numpy as np
from PIL import Image

R = Path(__file__).resolve().parent.parent
N = 4.4          # exposant de la superellipse
PROP = 0.60      # taille du dessin / carré
CY = 0.48        # centre vertical du dessin
HUE = 211.8
TAILLES_ICO = [16, 24, 32, 48, 64, 128, 256]


def hls(h, l, s):
    return np.array(colorsys.hls_to_rgb(h / 360, l, s))


def fond(px=1024):
    """Dégradé mesuré sur Cartable (L,S aux 4 coins), teinte du Labo, reflet en haut."""
    y, x = np.mgrid[0:px, 0:px] / (px - 1)
    def bil(tl, tr, bl, br):
        return (tl * (1 - x) + tr * x) * (1 - y) + (bl * (1 - x) + br * x) * y
    L = bil(.745, .595, .55, .435)
    S = bil(.77, .68, .63, .58)
    H = HUE + 3.0 * (x * .5 + y * .5) - 1.5   # dérive de teinte de Cartable (+3 deg)
    # reflet doux en haut à gauche (comme Réviser et Cartable)
    d = np.sqrt(((x - .25) / .6) ** 2 + ((y - .05) / .5) ** 2)
    L = L + .09 * np.clip(1 - d, 0, 1) ** 1.5
    out = np.zeros((px, px, 3))
    f = np.vectorize(colorsys.hls_to_rgb)
    r, g, b = f(H / 360, np.clip(L, 0, 1), np.clip(S, 0, 1))
    out[..., 0], out[..., 1], out[..., 2] = r, g, b
    return Image.fromarray((out * 255 + .5).astype(np.uint8), "RGB")


def masque(px):
    f = 4
    g = px * f
    y, x = np.mgrid[0:g, 0:g]
    u = np.abs((x + .5) / g * 2 - 1)
    v = np.abs((y + .5) / g * 2 - 1)
    m = ((u ** N + v ** N) <= 1).astype(np.uint8) * 255
    return Image.fromarray(m, "L").resize((px, px), Image.LANCZOS)


def dessin_place(prop, cy, rayon_max=None):
    d = Image.open(R / "captures" / "_dessin.png").convert("RGBA")
    a = np.array(d)[..., 3]
    ys, xs = np.where(a > 8)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    d = d.crop((x0, y0, x1 + 1, y1 + 1))
    w, h = d.size
    if rayon_max is None:
        s = prop * 1024 / max(w, h)
    else:
        s = 1.0
    toile = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    while True:
        dd = d.resize((round(w * s), round(h * s)), Image.LANCZOS)
        t = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        t.alpha_composite(dd, (512 - dd.width // 2, round(cy * 1024) - dd.height // 2))
        if rayon_max is None:
            return t, 0
        aa = np.array(t)[..., 3]
        yy, xx = np.where(aa > 8)
        dist = np.sqrt((xx - 512) ** 2 + (yy - 512) ** 2).max()
        if dist <= rayon_max:
            return t, dist
        s *= 0.99


def main():
    bg = fond()
    bg.save(R / "assets" / "icon_bg.png")
    dess, _ = dessin_place(PROP, CY)
    plein = bg.convert("RGBA")
    plein.alpha_composite(dess)
    plein.convert("RGB").save(R / "assets" / "icon.png")
    # calque Android : cercle de 60 % (<= 307 px), centré sur le carré
    fg, dist = dessin_place(None, .5, rayon_max=300)
    fg.save(R / "assets" / "icon_foreground.png")
    print("distance max calque Android :", round(float(dist), 1), "px / 307")
    # web : carré plein masquable (le lanceur masque) ; icônes « any » avec squircle
    for t in (192, 512):
        plein.convert("RGB").resize((t, t), Image.LANCZOS).save(R / "web" / "icons" / f"Icon-maskable-{t}.png")
        arr = plein.resize((t, t), Image.LANCZOS)
        arr.putalpha(masque(t))
        arr.save(R / "web" / "icons" / f"Icon-{t}.png")
    fav = plein.resize((48, 48), Image.LANCZOS)
    fav.putalpha(masque(48))
    fav.save(R / "web" / "favicon.png")
    # Windows
    imgs = []
    for t in TAILLES_ICO:
        im = plein.resize((t, t), Image.LANCZOS)
        im.putalpha(masque(t))
        imgs.append(im)
    sortie = R / "windows" / "runner" / "resources" / "app_icon.ico"
    imgs[-1].save(sortie, format="ICO", sizes=[(t, t) for t in TAILLES_ICO],
                  append_images=imgs[:-1], bitmap_format="png")
    # version 1024 squircle pour la comparaison
    sq = plein.copy(); sq.putalpha(masque(1024))
    sq.save(R / "captures" / "_labo_squircle.png")
    print("OK")


if __name__ == "__main__":
    main()
