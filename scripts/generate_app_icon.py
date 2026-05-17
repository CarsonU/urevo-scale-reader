#!/usr/bin/env python3
"""Generate the UrevoScale iOS app icon set."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ICON_SET = ROOT / "UrevoScale/Resources/Assets.xcassets/AppIcon.appiconset"
OUTPUTS = {
    "AppIcon-20.png": 20,
    "AppIcon-29.png": 29,
    "AppIcon-40.png": 40,
    "AppIcon-58.png": 58,
    "AppIcon-60.png": 60,
    "AppIcon-76.png": 76,
    "AppIcon-80.png": 80,
    "AppIcon-87.png": 87,
    "AppIcon-120.png": 120,
    "AppIcon-152.png": 152,
    "AppIcon-167.png": 167,
    "AppIcon-180.png": 180,
    "AppIcon-1024.png": 1024,
}


def rounded_rectangle_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def draw_background(size: int) -> Image.Image:
    image = Image.new("RGB", (size, size), "#eaf4ff")
    pixels = image.load()

    top = (243, 248, 255)
    bottom = (200, 221, 255)
    accent = (36, 116, 246)
    cool = (215, 240, 252)

    for y in range(size):
        y_ratio = y / (size - 1)
        for x in range(size):
            x_ratio = x / (size - 1)
            base = tuple(int(top[i] * (1 - y_ratio) + bottom[i] * y_ratio) for i in range(3))

            dx = x_ratio - 0.28
            dy = y_ratio - 0.2
            glow = max(0.0, 1.0 - ((dx * dx + dy * dy) ** 0.5 / 0.72)) * 0.24

            dx2 = x_ratio - 0.86
            dy2 = y_ratio - 0.9
            blue_lift = max(0.0, 1.0 - ((dx2 * dx2 + dy2 * dy2) ** 0.5 / 0.82)) * 0.12

            color = tuple(
                int(
                    base[i] * (1 - glow - blue_lift)
                    + cool[i] * glow
                    + accent[i] * blue_lift
                )
                for i in range(3)
            )
            pixels[x, y] = color

    return image


def paste_shadowed(
    base: Image.Image,
    shape: Image.Image,
    mask: Image.Image,
    xy: tuple[int, int],
    shadow_offset: tuple[int, int],
    shadow_radius: int,
    shadow_color: tuple[int, int, int, int],
) -> None:
    shadow_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", shape.size, shadow_color)
    shadow_layer.paste(shadow, (xy[0] + shadow_offset[0], xy[1] + shadow_offset[1]), mask)
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(shadow_radius))
    base.alpha_composite(shadow_layer)
    base.alpha_composite(shape, xy)


def draw_signal_arc(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    width: int,
    color: tuple[int, int, int, int],
) -> None:
    draw.arc(box, 210, 330, fill=color, width=width)


def draw_icon(size: int = 1024) -> Image.Image:
    image = draw_background(size).convert("RGBA")
    draw = ImageDraw.Draw(image)

    blue = (36, 116, 246, 255)
    blue_deep = (20, 86, 214, 255)
    graphite = (38, 48, 66, 255)
    graphite_soft = (76, 88, 110, 255)
    white = (255, 255, 255, 255)
    panel = (248, 252, 255, 255)

    scale_box = (
        int(size * 0.19),
        int(size * 0.33),
        int(size * 0.81),
        int(size * 0.82),
    )
    scale_radius = int(size * 0.135)
    scale_w = scale_box[2] - scale_box[0]
    scale_h = scale_box[3] - scale_box[1]

    scale = Image.new("RGBA", (scale_w, scale_h), (0, 0, 0, 0))
    scale_mask = rounded_rectangle_mask((scale_w, scale_h), scale_radius)
    scale_draw = ImageDraw.Draw(scale)

    scale_draw.rounded_rectangle(
        (0, 0, scale_w - 1, scale_h - 1),
        radius=scale_radius,
        fill=panel,
        outline=(202, 219, 240, 255),
        width=max(2, int(size * 0.012)),
    )

    glass_box = (
        int(scale_w * 0.19),
        int(scale_h * 0.13),
        int(scale_w * 0.81),
        int(scale_h * 0.49),
    )
    scale_draw.rounded_rectangle(
        glass_box,
        radius=int(size * 0.055),
        fill=(226, 239, 255, 255),
        outline=(174, 204, 244, 255),
        width=max(2, int(size * 0.01)),
    )

    sensor_y = int(scale_h * 0.69)
    sensor_radius = int(size * 0.027)
    for sensor_x in (int(scale_w * 0.26), int(scale_w * 0.74)):
        scale_draw.ellipse(
            (
                sensor_x - sensor_radius,
                sensor_y - sensor_radius,
                sensor_x + sensor_radius,
                sensor_y + sensor_radius,
            ),
            fill=(205, 218, 234, 255),
        )

    blue_line_width = max(4, int(size * 0.018))
    scale_draw.line(
        (
            int(scale_w * 0.31),
            int(scale_h * 0.55),
            int(scale_w * 0.5),
            int(scale_h * 0.62),
            int(scale_w * 0.69),
            int(scale_h * 0.55),
        ),
        fill=blue,
        width=blue_line_width,
        joint="curve",
    )

    scale_draw.arc(
        (
            int(scale_w * 0.32),
            int(scale_h * 0.36),
            int(scale_w * 0.68),
            int(scale_h * 0.78),
        ),
        204,
        336,
        fill=graphite_soft,
        width=max(4, int(size * 0.016)),
    )
    scale_draw.ellipse(
        (
            int(scale_w * 0.485),
            int(scale_h * 0.59),
            int(scale_w * 0.515),
            int(scale_h * 0.62),
        ),
        fill=graphite,
    )

    scale.putalpha(scale_mask)
    paste_shadowed(
        image,
        scale,
        scale_mask,
        (scale_box[0], scale_box[1]),
        (0, int(size * 0.05)),
        int(size * 0.04),
        (23, 52, 102, 70),
    )

    arc_draw = ImageDraw.Draw(image)
    center_x = int(size * 0.5)
    center_y = int(size * 0.315)
    arc_draw.ellipse(
        (
            center_x - int(size * 0.024),
            center_y - int(size * 0.024),
            center_x + int(size * 0.024),
            center_y + int(size * 0.024),
        ),
        fill=blue_deep,
    )

    for radius, width, alpha in (
        (int(size * 0.13), int(size * 0.026), 255),
        (int(size * 0.22), int(size * 0.024), 220),
    ):
        draw_signal_arc(
            arc_draw,
            (
                center_x - radius,
                center_y - int(radius * 0.55),
                center_x + radius,
                center_y + int(radius * 1.45),
            ),
            width,
            (blue[0], blue[1], blue[2], alpha),
        )

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.rounded_rectangle(
        (
            int(size * 0.23),
            int(size * 0.36),
            int(size * 0.77),
            int(size * 0.52),
        ),
        radius=int(size * 0.09),
        fill=(255, 255, 255, 42),
    )
    image.alpha_composite(highlight)

    return image.convert("RGB")


def main() -> None:
    ICON_SET.mkdir(parents=True, exist_ok=True)
    master = draw_icon()

    for filename, size in OUTPUTS.items():
        output = ICON_SET / filename
        icon = master if size == 1024 else master.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(output, format="PNG", optimize=True)


if __name__ == "__main__":
    main()
