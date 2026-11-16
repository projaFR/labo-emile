"""Compose toutes les icônes du Labo à partir de captures/_dessin.png
(produit par tool/generer_icone_test.dart) : fond en dégradé bleu avec reflet
net en haut à gauche et ombre en bas à droite (même construction que
tool/generer_icone.py de Réviser et Cartable : dégradé linéaire à 60°, puis
deux halos radiaux `max(0, 1-d)**2` composités par transparence), masque
squircle (n = 4,4, mesuré sur Réviser/Cartable), calque Android, web, .ico.
Teinte : Réviser 268,6 / Cartable 240,2 -> Labo 211,8 (même écart de -28,4).
Couleurs du dégradé et des halos : moyenne (en H,L,S) de celles de Réviser et
Cartable, ramenée à la teinte du Labo."""
import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

R = Path(__file__).resolve().parent.parent
N = 4.4          # exposant de la superellipse
PROP = 0.66      # taille du dessin / carré (largeur et hauteur ~62-66 %,
                 # comparable au livre de Réviser)
CY = 0.48        # centre vertical du dessin
HAUT = (101, 168, 243)   # bleu clair du dégradé (H 211,8 / L 0,674 / S 0,856)
BAS = (46, 122, 208)     # bleu foncé du dégradé (H 211,8 / L 0,498 / S 0,637)
OMBRE = (24, 67, 115)    # couleur du halo d'ombre (H 211,8 / L 0,272 / S 0,66)
BLANC = (255, 255, 255)
TAILLES_ICO = [16, 24, 32, 48, 64, 128, 256]


def degrade_lineaire(px, c1, c2, angle_deg=60):
    """Dégradé de c1 (début) à c2 (fin), même formule que generer_icone.py
    de Réviser/Cartable. Renvoie un tableau float (px, px, 3) dans [0, 1]."""
    y, x = np.mgrid[0:px, 0:px].astype(float)
    x, y = x / (px - 1), y / (px - 1)
    a = math.radians(angle_deg)
    dx, dy = math.cos(a), math.sin(a)
    u = ((x - .5) * dx + (y - .5) * dy) / (abs(dx) * .5 + abs(dy) * .5) * .5 + .5
    u = np.clip(u, 0, 1)[..., None]
    c1, c2 = np.array(c1) / 255, np.array(c2) / 255
    return c1 * (1 - u) + c2 * u


def halo(px, cx, cy, rayon, intensite):
    """Masque radial doux (même formule que Réviser/Cartable), 0..intensite."""
    y, x = np.mgrid[0:px, 0:px].astype(float)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / rayon
    return intensite * np.clip(1 - d, 0, 1) ** 2


TRAIT_CHUTE_PX = 8       # hauteur de la chute du trait, en px sur une image 1024
                         # (~0,8 % du carré ; mesuré sur Réviser/Cartable : pic
                         # sur 1-2 px à 256, donc ~4-8 px à 1024)
TRAIT_INTENSITE = 0.55   # poids max du mélange vers le blanc (pas une alpha,
                         # juste un mélange de couleur ; calibré pour donner
                         # un pic d'environ +60 à +80 par canal R/G/B, comme
                         # mesuré sur Réviser/Cartable)


def trait_lumiere(px):
    """Fin trait de lumière quasi blanc, pleinement opaque, qui suit le bord
    supérieur de la silhouette squircle (même exposant N que `masque`) et
    s'estompe vite vers le bas (chute nette, pas un halo diffus). Renvoie un
    masque d'intensité 0..1 en (px, px, 1)."""
    k = px / 1024
    chute = max(TRAIT_CHUTE_PX * k, 1e-6)
    y, x = np.mgrid[0:px, 0:px].astype(float)
    u = np.clip(np.abs((x + .5) / px * 2 - 1), 0, 1 - 1e-9)
    v_haut = (1 - u ** N) ** (1 / N)              # bord haut du squircle, coord. [-1,1]
    # -.5 : les pixels ont leur centre à y+.5 (même convention que `masque`)
    y_haut = (1 - v_haut) / 2 * px - .5            # bord haut en pixels (0 = haut de l'image)
    d = y - y_haut
    m = np.clip(1 - d / chute, 0, 1) ** 2
    m[d < 0] = 0
    m_img = Image.fromarray((m * 255 + .5).astype(np.uint8), "L")
    m_img = m_img.filter(ImageFilter.GaussianBlur(radius=max(0.8 * k, 0.3)))
    return (np.asarray(m_img).astype(float) / 255)[..., None]


def fond(px=1024):
    """Dégradé bleu (60°) + reflet net en haut à gauche + ombre en bas à
    droite, construits comme sur Réviser et Cartable (halo(250,160,760,.38)
    et halo(900,980,620,.30) sur une image 1024, mis à l'échelle de `px`),
    plus un fin trait de lumière sur le bord supérieur de la forme (comme
    mesuré sur les icônes compilées de Réviser et Cartable)."""
    k = px / 1024
    base = degrade_lineaire(px, HAUT, BAS, 60)
    lumiere = halo(px, 250 * k, 160 * k, 760 * k, 0.38)[..., None]
    ombre = halo(px, 900 * k, 980 * k, 620 * k, 0.30)[..., None]
    blanc, ombre_c = np.array(BLANC) / 255, np.array(OMBRE) / 255
    out = base * (1 - lumiere) + blanc * lumiere
    out = out * (1 - ombre) + ombre_c * ombre
    trait = trait_lumiere(px) * TRAIT_INTENSITE
    out = out * (1 - trait) + blanc * trait
    return Image.fromarray((np.clip(out, 0, 1) * 255 + .5).astype(np.uint8), "RGB")


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
