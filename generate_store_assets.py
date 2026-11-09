import os
from PIL import Image, ImageDraw, ImageFont

def generate_store_assets():
    out_dir = "store_assets"
    os.makedirs(out_dir, exist_ok=True)
    font_bold = "C:/Windows/Fonts/segoeuib.ttf"
    font_reg = "C:/Windows/Fonts/segoeui.ttf"

    base_icon_path = "assets/icon/app_icon.png"
    if os.path.exists(base_icon_path):
        base_icon = Image.open(base_icon_path).convert("RGBA")
        base_icon.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(out_dir, "icon_512.png"), "PNG")

    # Feature Graphic 1024x500
    w_feat, h_feat = 1024, 500
    feat = Image.new("RGBA", (w_feat, h_feat), (11, 15, 25, 255))
    fdraw = ImageDraw.Draw(feat)
    if os.path.exists(base_icon_path):
        ic = Image.open(base_icon_path).convert("RGBA").resize((320, 320), Image.Resampling.LANCZOS)
        feat.paste(ic, (80, 90), ic)

    f_title = ImageFont.truetype(font_bold, 46)
    f_sub = ImageFont.truetype(font_reg, 22)
    f_tag = ImageFont.truetype(font_bold, 16)
    fdraw.text((440, 105), "BÓVEDA SOLAR 3D • SOMBRAS • PANELES FV", font=f_tag, fill=(245, 158, 11, 255))
    fdraw.text((440, 145), "SUNPATH AR PRO", font=f_title, fill=(248, 250, 252, 255))
    fdraw.text((440, 215), "Trayectoria Solar & Lunar 100% Offline", font=f_sub, fill=(203, 213, 225, 255))
    fdraw.text((440, 250), "Hora Dorada, Inclinación FV & Reportes PDF", font=f_sub, fill=(148, 163, 184, 255))
    feat.save(os.path.join(out_dir, "feature_graphic_1024x500.png"), "PNG")

    screens = [
        ("1_boveda_solar_3d.png", "BÓVEDA SOLAR 3D", "Trayectoria Solar & Brújula AR", "Posición exacta del Sol, Azimut y Elevación sin internet"),
        ("2_calculo_sombras_fv.png", "SOMBRAS & PANELES FV", "Proyección e Inclinación Óptima", "Calcula sombras de obstáculos y separación entre filas solares"),
        ("3_efemerides_hora_dorada.png", "HORA DORADA & EFEMÉRIDES", "Fotografía, Arquitectura y Campo", "Amanecer, Cenit, Atardecer, Solsticios y Fase Lunar"),
        ("4_reporte_solar_pdf.png", "REPORTES TÉCNICOS PDF", "Estudios Firmados Listos para Obra", "Exporta informes ejecutivos en Español, Inglés y Portugués"),
    ]

    for fname, tag, title, sub in screens:
        img = Image.new("RGBA", (1080, 1920), (11, 15, 25, 255))
        d = ImageDraw.Draw(img)
        ft_tag = ImageFont.truetype(font_bold, 28)
        ft_title = ImageFont.truetype(font_bold, 56)
        ft_sub = ImageFont.truetype(font_reg, 30)
        d.text((70, 90), tag, font=ft_tag, fill=(245, 158, 11, 255))
        d.text((70, 140), title, font=ft_title, fill=(248, 250, 252, 255))
        d.text((70, 220), sub, font=ft_sub, fill=(148, 163, 184, 255))
        d.rounded_rectangle([80, 320, 1000, 1840], radius=50, fill=(22, 31, 48, 255), outline=(245, 158, 11, 180), width=4)
        d.ellipse([290, 520, 790, 1020], outline=(56, 189, 248, 200), width=5)
        d.arc([310, 540, 770, 1000], start=190, end=350, fill=(245, 158, 11, 255), width=12)
        d.rounded_rectangle([140, 1100, 940, 1340], radius=24, fill=(15, 23, 42, 255), outline=(36, 48, 70, 255), width=2)
        d.text((180, 1140), "Elevación Solar: 62.4°  |  Azimut: 204.5°", font=ft_sub, fill=(245, 158, 11, 255))
        d.text((180, 1210), "Inclinación FV Óptima: 34.0°  |  Sombra: 1.56 m", font=ft_sub, fill=(0, 230, 118, 255))
        img.save(os.path.join(out_dir, fname), "PNG")

    print("Generated all store_assets for SunPathAR")

if __name__ == "__main__":
    generate_store_assets()
