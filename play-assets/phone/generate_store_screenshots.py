import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "play-assets" / "phone" / "source"
EXPORT_ROOT = ROOT / "play-assets" / "phone"
BASE_WIDTH = 1242
BASE_HEIGHT = 2208

FORMATS = [
    {"name": "play-store", "size": (1242, 2208)},
    {"name": "app-store-6.5", "size": (1284, 2778)},
]

HEADLINE_FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
BODY_FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
MONO_BOLD = str(ROOT / "assets" / "fonts" / "SpaceMono-Bold.ttf")
APP_ICON = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-App-1024x1024@1x.png"

SCREENS = [
    {
        "source": "01-map-save.jpeg",
        "output": "reelpin-phone-01-map-save.png",
        "label": "MAP SAVES",
        "headline": "Turn saved reels into places you can visit",
        "body": "Reelpin drops every called out place onto your map, so your saved reels stay useful outside Instagram.",
        "palette": ("#F3F6FF", "#DBE6FF", "#3565FF"),
    },
    {
        "source": "02-save-reels.jpeg",
        "output": "reelpin-phone-02-save-reels.png",
        "label": "SAVE FAST",
        "headline": "Keep the reels you actually want to try",
        "body": "Send any reel to Reelpin once, then come back to food spots, products, and ideas before they get buried.",
        "palette": ("#FFF9DB", "#FFE99A", "#FFCF00"),
    },
    {
        "source": "03-sign-up.jpeg",
        "output": "reelpin-phone-03-sign-up.png",
        "label": "ACCOUNT SETUP",
        "headline": "Create your Reelpin account in seconds",
        "body": "Sign up once and keep your saved reels, map pins, and categories synced in one place.",
        "palette": ("#F3FFE6", "#DFF6C5", "#C6FF2D"),
    },
    {
        "source": "04-home-feed.jpeg",
        "output": "reelpin-phone-04-home-feed.png",
        "label": "SMART FEED",
        "headline": "Browse your saved reels as clean cards",
        "body": "Each saved reel becomes a quick summary card you can scan later instead of rewatching from the start.",
        "palette": ("#FFF9E1", "#FFECB1", "#FFC700"),
    },
    {
        "source": "05-sign-in.jpeg",
        "output": "reelpin-phone-05-sign-in.png",
        "label": "SIGN IN",
        "headline": "Pick up your reel archive on any device",
        "body": "Log back in and get the same library, map pins, and discover tools right where you left them.",
        "palette": ("#E9FFFB", "#CFF3EE", "#7ED3C7"),
    },
    {
        "source": "06-action-items.jpeg",
        "output": "reelpin-phone-06-action-items.png",
        "label": "ACTION ITEMS",
        "headline": "See tasks, facts, and transcript highlights",
        "body": "Open one reel and Reelpin pulls out useful next steps, people mentioned, and the parts worth remembering.",
        "palette": ("#EEF4FF", "#D9E5FF", "#4C7BFF"),
    },
    {
        "source": "07-discover.jpeg",
        "output": "reelpin-phone-07-discover.png",
        "label": "DISCOVER",
        "headline": "Search everything you have already saved",
        "body": "Jump from food spots to travel ideas and categories without scrolling through your saved tab again.",
        "palette": ("#FFF8DA", "#FFEA9A", "#FFCF00"),
    },
    {
        "source": "08-profile.jpeg",
        "output": "reelpin-phone-08-profile.png",
        "label": "PROFILE STATS",
        "headline": "Track your reel library at a glance",
        "body": "See total reels, pinned places, and tags from one profile screen so your collection stays organized.",
        "palette": ("#E6FFF8", "#CAEDE3", "#0E7267"),
    },
    {
        "source": "09-summary.jpeg",
        "output": "reelpin-phone-09-summary.png",
        "label": "DETAIL VIEW",
        "headline": "Read the key takeaway before you rewatch",
        "body": "Every saved reel opens with a summary and key facts, so you can decide fast if it is worth acting on.",
        "palette": ("#F2FFE3", "#DCFFC5", "#67FF37"),
    },
    {
        "source": "10-map-pins.jpeg",
        "output": "reelpin-phone-10-map-pins.png",
        "label": "PLACES MAP",
        "headline": "Open saved spots directly on your map",
        "body": "Food stalls, cafes, and places to visit stay pinned, ready when you are out and want to go there.",
        "palette": ("#FFF4DE", "#FFE1A6", "#FF6A1F"),
    },
]


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def fill_background(image, bg_hex):
    image.paste((*hex_to_rgb(bg_hex), 255), (0, 0, image.size[0], image.size[1]))


def tracking_text_width(draw, text, font, tracking):
    width = 0
    for index, char in enumerate(text):
        bbox = draw.textbbox((0, 0), char, font=font)
        width += bbox[2] - bbox[0]
        if index < len(text) - 1:
            width += tracking
    return width


def draw_tracking_text(draw, position, text, font, fill, tracking):
    x, y = position
    for index, char in enumerate(text):
        draw.text((x, y), char, fill=fill, font=font)
        bbox = draw.textbbox((x, y), char, font=font)
        x = bbox[2]
        if index < len(text) - 1:
            x += tracking
    return x


def draw_brutal_box(base, box, fill, border_width, shadow_offset, outline=(0, 0, 0, 255), shadow_fill=(0, 0, 0, 255)):
    draw = ImageDraw.Draw(base)
    if shadow_offset:
        shadow_x, shadow_y = shadow_offset
        draw.rectangle(
            (
                box[0] + shadow_x,
                box[1] + shadow_y,
                box[2] + shadow_x,
                box[3] + shadow_y,
            ),
            fill=shadow_fill,
        )
    draw.rectangle(box, fill=fill, outline=outline, width=border_width)


def add_background_shapes(base, panel_hex, accent_hex):
    return


def load_font(path, size):
    return ImageFont.truetype(path, size=size)


def wrap_text(draw, text, font, max_width):
    words = text.split()
    lines = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        if draw.textbbox((0, 0), candidate, font=font)[2] <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return "\n".join(lines)


def fit_text(draw, text, font_path, max_size, min_size, max_width, max_lines, spacing_ratio):
    result = None
    for size in range(max_size, min_size - 1, -2):
        font = load_font(font_path, size)
        wrapped = wrap_text(draw, text, font, max_width)
        lines = wrapped.count("\n") + 1
        spacing = int(size * spacing_ratio)
        bbox = draw.multiline_textbbox((0, 0), wrapped, font=font, spacing=spacing)
        width = bbox[2] - bbox[0]
        if lines <= max_lines and width <= max_width:
            return font, wrapped, spacing
        result = (font, wrapped, spacing)
    return result


def add_brand_header(base, accent_hex, label_text):
    width, height = base.size
    sx = width / BASE_WIDTH
    sy = height / BASE_HEIGHT
    draw = ImageDraw.Draw(base)
    accent = hex_to_rgb(accent_hex)
    brand_y = int(102 * sy)
    icon_x = int(96 * sx)
    icon_size = int(74 * sx)
    shadow_offset = int(8 * sx)
    draw.rectangle(
        (
            icon_x + shadow_offset,
            brand_y + shadow_offset,
            icon_x + icon_size + shadow_offset,
            brand_y + icon_size + shadow_offset,
        ),
        fill=(0, 0, 0, 255),
    )

    icon = Image.open(APP_ICON).convert("RGBA")
    icon = ImageOps.fit(icon, (icon_size, icon_size))
    base.alpha_composite(icon, (icon_x, brand_y))

    brand_font = load_font(MONO_BOLD, int(36 * sx))
    tracking = max(1, int(2 * sx))
    draw_tracking_text(
        draw,
        (int(198 * sx), brand_y + int(17 * sy)),
        "REELPIN",
        brand_font,
        (16, 16, 16, 255),
        tracking,
    )

    label_font = load_font(MONO_BOLD, int(26 * sx))
    pill_x = int(96 * sx)
    pill_y = int(214 * sy)
    label_tracking = max(1, int(1 * sx))
    pill_w = tracking_text_width(draw, label_text, label_font, label_tracking) + int(44 * sx)
    pill_h = int(56 * sy)
    draw_brutal_box(
        base,
        (pill_x, pill_y, pill_x + pill_w, pill_y + pill_h),
        fill=(*accent, 255),
        border_width=max(2, int(4 * sx)),
        shadow_offset=(int(8 * sx), int(8 * sy)),
    )
    draw_tracking_text(
        draw,
        (pill_x + int(20 * sx), pill_y + int(13 * sy)),
        label_text,
        label_font,
        (16, 16, 16, 255),
        label_tracking,
    )


def add_copy(base, headline, body, accent_hex):
    width, height = base.size
    sx = width / BASE_WIDTH
    sy = height / BASE_HEIGHT
    draw = ImageDraw.Draw(base)
    headline_font, wrapped_headline, headline_spacing = fit_text(
        draw,
        headline,
        HEADLINE_FONT,
        int(116 * sx),
        int(80 * sx),
        int(1050 * sx),
        3,
        0.1,
    )
    body_font, wrapped_body, body_spacing = fit_text(
        draw,
        body,
        BODY_FONT,
        int(42 * sx),
        int(30 * sx),
        int(1020 * sx),
        3,
        0.28,
    )

    headline_x = int(96 * sx)
    headline_y = int(318 * sy)
    draw.multiline_text(
        (headline_x, headline_y),
        wrapped_headline,
        fill=(18, 18, 18, 255),
        font=headline_font,
        spacing=headline_spacing,
    )
    headline_box = draw.multiline_textbbox(
        (headline_x, headline_y),
        wrapped_headline,
        font=headline_font,
        spacing=headline_spacing,
    )
    body_y = headline_box[3] + int(28 * sy)
    draw.multiline_text(
        (headline_x, body_y),
        wrapped_body,
        fill=(58, 58, 58, 255),
        font=body_font,
        spacing=body_spacing,
    )
    body_box = draw.multiline_textbbox(
        (headline_x, body_y),
        wrapped_body,
        font=body_font,
        spacing=body_spacing,
    )

    accent = hex_to_rgb(accent_hex)
    underline_y = body_box[3] + int(34 * sy)
    draw.rectangle(
        (
            headline_x,
            underline_y,
            headline_x + int(152 * sx),
            underline_y + int(12 * sy),
        ),
        fill=(*accent, 255),
    )
    return underline_y + int(54 * sy)


def add_screenshot(base, screenshot_path, accent_hex, min_top):
    width, height = base.size
    sx = width / BASE_WIDTH
    sy = height / BASE_HEIGHT

    screenshot = Image.open(screenshot_path).convert("RGB")
    screenshot = ImageOps.contain(
        screenshot,
        (
            int(838 * sx),
            height - min_top - int(96 * sy),
        ),
    )
    screenshot = screenshot.convert("RGBA")

    border = int(9 * sx)
    card_w = screenshot.width + border * 2
    card_h = screenshot.height + border * 2
    card_x = (width - card_w) // 2
    card_y = max(min_top, height - card_h - int(104 * sy))

    draw_brutal_box(
        base,
        (
            card_x,
            card_y,
            card_x + card_w,
            card_y + card_h,
        ),
        fill=(0, 0, 0, 255),
        border_width=max(2, int(4 * sx)),
        shadow_offset=(int(12 * sx), int(12 * sy)),
    )

    card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 255))
    card.paste(screenshot, (border, border), screenshot)
    base.alpha_composite(card, (card_x, card_y))


def render_screen(spec, output_dir, canvas_size):
    output_dir.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", canvas_size, (255, 255, 255, 255))
    bg, panel, accent = spec["palette"]
    fill_background(canvas, bg)
    add_background_shapes(canvas, panel, accent)
    add_brand_header(canvas, accent, spec["label"])
    screenshot_top = add_copy(canvas, spec["headline"], spec["body"], accent)
    add_screenshot(
        canvas,
        SOURCE_DIR / spec["source"],
        accent,
        screenshot_top + int(24 * (canvas_size[1] / BASE_HEIGHT)),
    )
    canvas.convert("RGB").save(output_dir / spec["output"], quality=95)


def render_contact_sheet(output_dir):
    files = sorted(output_dir.glob("reelpin-phone-*.png"))
    if not files:
        return

    thumb_w = 220
    thumb_h = 390
    margin = 24
    label_h = 52
    cols = 2
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new(
        "RGB",
        (
            cols * thumb_w + (cols + 1) * margin,
            rows * (thumb_h + label_h) + (rows + 1) * margin,
        ),
        "#111111",
    )
    draw = ImageDraw.Draw(sheet)
    font = load_font("/System/Library/Fonts/Menlo.ttc", 16)
    for index, path in enumerate(files, start=1):
        image = Image.open(path).convert("RGB")
        thumb = ImageOps.contain(image, (thumb_w, thumb_h))
        x = margin + ((index - 1) % cols) * (thumb_w + margin)
        y = margin + ((index - 1) // cols) * (thumb_h + label_h)
        sheet.paste(thumb, (x + (thumb_w - thumb.width) // 2, y + (thumb_h - thumb.height) // 2))
        draw.rectangle((x - 2, y - 2, x + thumb_w + 2, y + thumb_h + 2), outline="#ffffff", width=2)
        draw.text((x, y + thumb_h + 10), path.stem.replace("reelpin-phone-", ""), fill="white", font=font)
    sheet.save(output_dir / "contact-sheet.png")


def main():
    for format_spec in FORMATS:
        output_dir = EXPORT_ROOT / format_spec["name"]
        if output_dir.exists():
            shutil.rmtree(output_dir)
        for spec in SCREENS:
            render_screen(spec, output_dir, format_spec["size"])
        render_contact_sheet(output_dir)


if __name__ == "__main__":
    main()
