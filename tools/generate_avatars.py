import math
from PIL import Image, ImageDraw

def create_gradient(size, c1, c2):
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        t = y / float(size)
        r = int(c1[0] * (1 - t) + c2[0] * t)
        g = int(c1[1] * (1 - t) + c2[1] * t)
        b = int(c1[2] * (1 - t) + c2[2] * t)
        for x in range(size):
            base.putpixel((x, y), (r, g, b, 255))
    return base

def draw_avatar(cfg, filename):
    S = 1024
    img = create_gradient(S, cfg['bg1'], cfg['bg2'])
    draw = ImageDraw.Draw(img)

    # Circular mask for avatar background
    mask = Image.new("L", (S, S), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse((20, 20, S - 20, S - 20), fill=255)

    # Inner illustration canvas
    char_img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(char_img)

    skin = cfg['skin']
    hair_color = cfg['hair']
    clothes = cfg['clothes']
    gender = cfg.get('gender', 'm')
    has_beard = cfg.get('beard', False)
    has_glasses = cfg.get('glasses', False)
    has_steth = cfg.get('steth', False)
    hair_style = cfg.get('hair_style', 'short')

    cx, cy = S // 2, S // 2

    # 1. Back hair (for long hair / bun)
    if hair_style in ['long', 'ponytail', 'bun']:
        if hair_style == 'bun':
            cdraw.ellipse((cx - 160, cy - 360, cx + 160, cy - 140), fill=hair_color)
        else:
            cdraw.ellipse((cx - 240, cy - 200, cx + 240, cy + 300), fill=hair_color)

    # 2. Shoulders / Clothes
    cdraw.ellipse((cx - 380, cy + 220, cx + 380, cy + 800), fill=clothes)
    
    # Collar / Neckline
    neck_color = (max(0, skin[0] - 25), max(0, skin[1] - 25), max(0, skin[2] - 25), 255)
    cdraw.rectangle((cx - 80, cy + 120, cx + 80, cy + 280), fill=neck_color)

    # Clothes V-neck / Collar
    cdraw.polygon([(cx - 70, cy + 260), (cx + 70, cy + 260), (cx, cy + 360)], fill=skin)
    
    # 3. White Doctor Coat / Stethoscope
    if has_steth:
        # Coat lapels
        cdraw.polygon([(cx - 300, cy + 300), (cx - 90, cy + 340), (cx - 140, cy + 600), (cx - 360, cy + 600)], fill=(245, 248, 252, 255))
        cdraw.polygon([(cx + 300, cy + 300), (cx + 90, cy + 340), (cx + 140, cy + 600), (cx + 360, cy + 600)], fill=(245, 248, 252, 255))
        # Stethoscope tubes
        steth_color = (51, 65, 85, 255)
        cdraw.arc((cx - 120, cy + 180, cx + 120, cy + 420), start=0, end=180, fill=steth_color, width=22)
        cdraw.ellipse((cx - 30, cy + 410, cx + 30, cy + 470), fill=(148, 163, 184, 255))
        cdraw.ellipse((cx - 18, cy + 422, cx + 18, cy + 458), fill=(203, 213, 225, 255))

    # 4. Head / Face
    cdraw.ellipse((cx - 180, cy - 220, cx + 180, cy + 200), fill=skin)

    # Ears
    cdraw.ellipse((cx - 210, cy - 40, cx - 160, cy + 60), fill=skin)
    cdraw.ellipse((cx + 160, cy - 40, cx + 210, cy + 60), fill=skin)

    # Beard
    if has_beard:
        cdraw.ellipse((cx - 170, cy - 20, cx + 170, cy + 220), fill=hair_color)
        cdraw.ellipse((cx - 130, cy - 20, cx + 130, cy + 160), fill=skin)

    # 5. Eyes & Eyebrows
    eye_color = (30, 41, 59, 255)
    eye_y = cy - 20
    # Left eye
    cdraw.ellipse((cx - 100, eye_y - 18, cx - 50, eye_y + 18), fill=eye_color)
    cdraw.ellipse((cx - 85, eye_y - 12, cx - 65, eye_y + 2), fill=(255, 255, 255, 255))
    # Right eye
    cdraw.ellipse((cx + 50, eye_y - 18, cx + 100, eye_y + 18), fill=eye_color)
    cdraw.ellipse((cx + 65, eye_y - 12, cx + 85, eye_y + 2), fill=(255, 255, 255, 255))

    # Eyebrows
    brow_color = (max(0, hair_color[0] - 20), max(0, hair_color[1] - 20), max(0, hair_color[2] - 20), 255)
    cdraw.arc((cx - 110, eye_y - 65, cx - 40, eye_y - 25), start=200, end=340, fill=brow_color, width=14)
    cdraw.arc((cx + 40, eye_y - 65, cx + 110, eye_y - 25), start=200, end=340, fill=brow_color, width=14)

    # Cheeks (blush)
    blush = (255, 160, 160, 90)
    cdraw.ellipse((cx - 145, eye_y + 25, cx - 95, eye_y + 65), fill=blush)
    cdraw.ellipse((cx + 95, eye_y + 25, cx + 145, eye_y + 65), fill=blush)

    # Nose
    nose_color = (max(0, skin[0] - 35), max(0, skin[1] - 35), max(0, skin[2] - 35), 255)
    cdraw.arc((cx - 20, cy + 10, cx + 20, cy + 45), start=30, end=150, fill=nose_color, width=10)

    # Smile / Mouth
    lip_color = (225, 112, 112, 255)
    cdraw.arc((cx - 50, cy + 60, cx + 50, cy + 120), start=15, end=165, fill=lip_color, width=12)

    # Glasses
    if has_glasses:
        frame_color = (30, 41, 59, 255)
        cdraw.ellipse((cx - 125, eye_y - 42, cx - 25, eye_y + 38), outline=frame_color, width=14)
        cdraw.ellipse((cx + 25, eye_y - 42, cx + 125, eye_y + 38), outline=frame_color, width=14)
        cdraw.line([(cx - 25, eye_y), (cx + 25, eye_y)], fill=frame_color, width=12)

    # 6. Front Hair
    if hair_style == 'short':
        cdraw.ellipse((cx - 195, cy - 300, cx + 195, cy - 90), fill=hair_color)
        cdraw.polygon([(cx - 195, cy - 140), (cx - 140, cy - 80), (cx - 70, cy - 130), (cx, cy - 80), (cx + 70, cy - 130), (cx + 140, cy - 80), (cx + 195, cy - 140)], fill=hair_color)
    elif hair_style == 'side_part':
        cdraw.ellipse((cx - 205, cy - 300, cx + 205, cy - 80), fill=hair_color)
        cdraw.polygon([(cx - 195, cy - 120), (cx - 80, cy - 50), (cx + 195, cy - 140)], fill=hair_color)
    elif hair_style == 'bob':
        cdraw.ellipse((cx - 205, cy - 300, cx + 205, cy - 60), fill=hair_color)
        cdraw.rectangle((cx - 205, cy - 100, cx - 145, cy + 140), fill=hair_color)
        cdraw.rectangle((cx + 145, cy - 100, cx + 205, cy + 140), fill=hair_color)
    elif hair_style in ['long', 'ponytail', 'bun']:
        cdraw.ellipse((cx - 205, cy - 310, cx + 205, cy - 70), fill=hair_color)
        cdraw.arc((cx - 190, cy - 250, cx + 190, cy - 50), start=0, end=180, fill=hair_color, width=70)
        if hair_style == 'long':
            cdraw.rectangle((cx - 215, cy - 80, cx - 150, cy + 240), fill=hair_color)
            cdraw.rectangle((cx + 150, cy - 80, cx + 215, cy + 240), fill=hair_color)
    elif hair_style == 'curly':
        for angle in range(0, 360, 30):
            rad = math.radians(angle)
            hx = int(cx + 170 * math.cos(rad))
            hy = int((cy - 160) + 120 * math.sin(rad))
            cdraw.ellipse((hx - 60, hy - 60, hx + 60, hy + 60), fill=hair_color)

    # Composite character inside mask
    img.paste(char_img, (0, 0), char_img)

    # Clip to circular border
    final_img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    final_img.paste(img, (0, 0), mask)
    fdraw = ImageDraw.Draw(final_img)
    fdraw.ellipse((20, 20, S - 20, S - 20), outline=(255, 255, 255, 220), width=18)

    # High-quality downsampling to 256x256
    thumb = final_img.resize((256, 256), Image.Resampling.LANCZOS)
    thumb.save(filename, "PNG")

avatars = [
    {
        'file': 'assets/images/avatars/avatar_doc_m.png',
        'bg1': (0, 113, 227), 'bg2': (59, 130, 246),
        'skin': (255, 224, 189, 255), 'hair': (30, 41, 59, 255),
        'clothes': (14, 116, 144, 255), 'hair_style': 'side_part',
        'steth': True, 'glasses': False,
    },
    {
        'file': 'assets/images/avatars/avatar_doc_f.png',
        'bg1': (16, 185, 129), 'bg2': (5, 150, 105),
        'skin': (248, 209, 178, 255), 'hair': (67, 56, 202, 255),
        'clothes': (13, 148, 136, 255), 'hair_style': 'bun',
        'steth': True, 'glasses': True,
    },
    {
        'file': 'assets/images/avatars/avatar_male_1.png',
        'bg1': (37, 99, 235), 'bg2': (79, 70, 229),
        'skin': (245, 205, 170, 255), 'hair': (44, 30, 24, 255),
        'clothes': (59, 130, 246, 255), 'hair_style': 'short',
        'steth': False, 'glasses': False,
    },
    {
        'file': 'assets/images/avatars/avatar_female_1.png',
        'bg1': (236, 72, 153), 'bg2': (219, 39, 119),
        'skin': (255, 224, 195, 255), 'hair': (120, 53, 15, 255),
        'clothes': (244, 114, 182, 255), 'hair_style': 'bob',
        'steth': False, 'glasses': False,
    },
    {
        'file': 'assets/images/avatars/avatar_male_2.png',
        'bg1': (15, 23, 42), 'bg2': (51, 65, 85),
        'skin': (238, 196, 160, 255), 'hair': (30, 41, 59, 255),
        'clothes': (30, 41, 59, 255), 'hair_style': 'short',
        'beard': True, 'glasses': True, 'steth': False,
    },
    {
        'file': 'assets/images/avatars/avatar_female_2.png',
        'bg1': (124, 58, 237), 'bg2': (147, 51, 234),
        'skin': (255, 228, 205, 255), 'hair': (30, 27, 75, 255),
        'clothes': (168, 85, 247, 255), 'hair_style': 'long',
        'steth': False, 'glasses': True,
    },
    {
        'file': 'assets/images/avatars/avatar_senior_m.png',
        'bg1': (217, 119, 6), 'bg2': (180, 83, 9),
        'skin': (250, 215, 185, 255), 'hair': (203, 213, 225, 255),
        'clothes': (100, 116, 139, 255), 'hair_style': 'side_part',
        'beard': True, 'glasses': True, 'steth': False,
    },
    {
        'file': 'assets/images/avatars/avatar_senior_f.png',
        'bg1': (190, 24, 93), 'bg2': (157, 23, 77),
        'skin': (250, 215, 185, 255), 'hair': (226, 232, 240, 255),
        'clothes': (147, 51, 234, 255), 'hair_style': 'bun',
        'glasses': True, 'steth': False,
    },
    {
        'file': 'assets/images/avatars/avatar_kid_m.png',
        'bg1': (234, 88, 12), 'bg2': (249, 115, 22),
        'skin': (255, 225, 190, 255), 'hair': (74, 4, 4, 255),
        'clothes': (59, 130, 246, 255), 'hair_style': 'short',
        'steth': False, 'glasses': False,
    },
    {
        'file': 'assets/images/avatars/avatar_kid_f.png',
        'bg1': (244, 63, 94), 'bg2': (251, 113, 133),
        'skin': (255, 228, 205, 255), 'hair': (180, 83, 9, 255),
        'clothes': (244, 114, 182, 255), 'hair_style': 'long',
        'steth': False, 'glasses': False,
    },
    {
        'file': 'assets/images/avatars/avatar_wellness_m.png',
        'bg1': (5, 150, 105), 'bg2': (16, 185, 129),
        'skin': (240, 195, 155, 255), 'hair': (30, 41, 59, 255),
        'clothes': (16, 185, 129, 255), 'hair_style': 'curly',
        'steth': False, 'glasses': False,
    },
    {
        'file': 'assets/images/avatars/avatar_wellness_f.png',
        'bg1': (6, 182, 212), 'bg2': (14, 165, 233),
        'skin': (255, 225, 195, 255), 'hair': (136, 19, 55, 255),
        'clothes': (14, 165, 233, 255), 'hair_style': 'ponytail',
        'steth': False, 'glasses': False,
    },
]

for av in avatars:
    draw_avatar(av, av['file'])
    print(f"Generated {av['file']}")
