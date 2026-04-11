#!/usr/bin/env python3
"""
OmniX X-Ray + Night Vision - Texture Generator for Minecraft Bedrock Edition
Generates all required textures for the resource pack.
"""

from PIL import Image, ImageDraw, ImageFilter
import os
import math

BASE_DIR = "OmniX_XRay_NightVision/textures/blocks"
SIZE = 16  # Standard Minecraft texture size

os.makedirs(BASE_DIR, exist_ok=True)


def save(img, name):
    """Save a 16x16 RGBA image."""
    img.save(os.path.join(BASE_DIR, name))
    print(f"  [OK] {name}")


def fully_transparent():
    """Create a completely transparent 16x16 image."""
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def solid_color(r, g, b, a=255):
    """Create a solid color 16x16 image."""
    return Image.new("RGBA", (SIZE, SIZE), (r, g, b, a))


def create_signaling_texture(base_color, warning_color, pattern="dots"):
    """
    Create a semi-transparent signaling texture.
    The block is visible but with reduced opacity and warning markers.
    """
    img = Image.new("RGBA", (SIZE, SIZE), (*base_color, 50))  # Very low opacity base
    draw = ImageDraw.Draw(img)

    if pattern == "dots":
        # Yellow/orange warning dots in corners and center
        for x, y in [(0, 0), (15, 0), (0, 15), (15, 15), (7, 7), (8, 8)]:
            draw.point((x, y), fill=(*warning_color, 200))
        # Border pulse effect
        for i in range(16):
            draw.point((i, 0), fill=(*warning_color, 120))
            draw.point((i, 15), fill=(*warning_color, 120))
            draw.point((0, i), fill=(*warning_color, 120))
            draw.point((15, i), fill=(*warning_color, 120))

    elif pattern == "stripes":
        # Diagonal warning stripes
        for x in range(SIZE):
            for y in range(SIZE):
                if (x + y) % 4 < 2:
                    draw.point((x, y), fill=(*warning_color, 100))

    return img


def create_fall_detection_texture():
    """
    Create a BRIGHT RED pulsing border texture for blocks that indicate
    potential falls (used on bottom-face-exposed blocks like sand, gravel near caves).
    This texture signals DANGER - there may be a drop below or nearby.
    Pattern: Red/orange chevrons pointing DOWN (universal fall warning).
    """
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))  # Transparent base
    draw = ImageDraw.Draw(img)

    # Bright red border - thick and unmissable
    for i in range(16):
        # Top and bottom thick red border (2px)
        draw.point((i, 0), fill=(255, 0, 0, 255))
        draw.point((i, 1), fill=(255, 0, 0, 230))
        draw.point((i, 14), fill=(255, 0, 0, 230))
        draw.point((i, 15), fill=(255, 0, 0, 255))
        # Left and right thick red border
        draw.point((0, i), fill=(255, 0, 0, 255))
        draw.point((1, i), fill=(255, 0, 0, 230))
        draw.point((14, i), fill=(255, 0, 0, 230))
        draw.point((15, i), fill=(255, 0, 0, 255))

    # Downward-pointing chevrons (V shapes) inside - universal "fall" symbol
    # First chevron
    for offset in range(5):
        x1 = 4 + offset
        x2 = 12 - offset
        y = 4 + offset
        if 0 <= y < 16:
            draw.point((x1, y), fill=(255, 255, 0, 255))
            draw.point((x2, y), fill=(255, 255, 0, 255))

    # Second chevron below
    for offset in range(4):
        x1 = 5 + offset
        x2 = 11 - offset
        y = 10 + offset
        if 0 <= y < 16:
            draw.point((x1, y), fill=(255, 165, 0, 230))
            draw.point((x2, y), fill=(255, 165, 0, 230))

    return img


def create_cave_air_warning():
    """
    Special texture overlay - creates a subtle red glow pattern
    that would be applied to cave_air to highlight empty spaces.
    """
    img = Image.new("RGBA", (SIZE, SIZE), (255, 0, 0, 8))
    draw = ImageDraw.Draw(img)
    # Faint pulsing cross pattern
    for i in range(SIZE):
        draw.point((8, i), fill=(255, 0, 0, 25))
        draw.point((i, 8), fill=(255, 0, 0, 25))
    return img


def create_bright_ore_texture(ore_color, glow_color, pattern_type="scattered"):
    """
    Create a night-vision enhanced ore texture.
    Bright, glowing appearance so ores are unmissable in the dark.
    """
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Glowing background halo
    for x in range(SIZE):
        for y in range(SIZE):
            dist = math.sqrt((x - 7.5) ** 2 + (y - 7.5) ** 2)
            if dist < 10:
                alpha = int(max(0, 60 - dist * 6))
                draw.point((x, y), fill=(*glow_color, alpha))

    if pattern_type == "scattered":
        # Ore spots - bright colored pixels
        ore_positions = [
            (3, 3), (4, 3), (3, 4),
            (10, 5), (11, 5), (11, 6),
            (5, 9), (6, 9), (5, 10), (6, 10),
            (12, 11), (13, 11), (12, 12),
            (2, 13), (3, 13),
        ]
        for x, y in ore_positions:
            draw.point((x, y), fill=(*ore_color, 255))
            # Glow around each ore pixel
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < SIZE and 0 <= ny < SIZE:
                    draw.point((nx, ny), fill=(*glow_color, 150))

    elif pattern_type == "cluster":
        # Dense cluster in center
        for x in range(5, 12):
            for y in range(5, 12):
                if (x + y) % 2 == 0:
                    draw.point((x, y), fill=(*ore_color, 255))
                else:
                    draw.point((x, y), fill=(*glow_color, 180))

    return img


def create_bright_block(color, border_color=None):
    """Create a bright, highly visible block texture for night vision."""
    img = Image.new("RGBA", (SIZE, SIZE), (*color, 220))
    draw = ImageDraw.Draw(img)

    if border_color:
        for i in range(SIZE):
            draw.point((i, 0), fill=(*border_color, 255))
            draw.point((i, 15), fill=(*border_color, 255))
            draw.point((0, i), fill=(*border_color, 255))
            draw.point((15, i), fill=(*border_color, 255))

    return img


def create_water_texture():
    """Bright blue water - clearly visible."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 100, 255, 160))
    draw = ImageDraw.Draw(img)
    # Wave pattern
    for x in range(SIZE):
        y_wave = int(4 + 2 * math.sin(x * 0.8))
        draw.point((x, y_wave), fill=(100, 200, 255, 200))
        y_wave2 = int(10 + 2 * math.sin(x * 0.8 + 2))
        draw.point((x, y_wave2), fill=(100, 200, 255, 200))
    return img


def create_lava_texture():
    """Bright orange/red lava - unmissable."""
    img = Image.new("RGBA", (SIZE, SIZE), (255, 80, 0, 200))
    draw = ImageDraw.Draw(img)
    # Hot spots
    for x in range(SIZE):
        for y in range(SIZE):
            if (x * 7 + y * 13) % 11 < 3:
                draw.point((x, y), fill=(255, 255, 0, 230))
            elif (x * 3 + y * 7) % 9 < 2:
                draw.point((x, y), fill=(255, 50, 0, 255))
    return img


def create_amethyst_texture():
    """Bright purple amethyst - glowing crystal effect."""
    img = Image.new("RGBA", (SIZE, SIZE), (150, 50, 200, 200))
    draw = ImageDraw.Draw(img)
    # Crystal sparkle points
    sparkle_points = [(3, 2), (8, 4), (12, 3), (5, 8), (10, 10), (2, 12), (14, 7), (7, 14)]
    for x, y in sparkle_points:
        draw.point((x, y), fill=(255, 200, 255, 255))
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = x + dx, y + dy
            if 0 <= nx < SIZE and 0 <= ny < SIZE:
                draw.point((nx, ny), fill=(200, 130, 255, 200))
    return img


def create_chest_texture():
    """Bright golden chest texture."""
    img = Image.new("RGBA", (SIZE, SIZE), (180, 130, 40, 240))
    draw = ImageDraw.Draw(img)
    # Lock/latch in center
    draw.rectangle([(6, 6), (9, 9)], fill=(255, 215, 0, 255))
    draw.point((7, 7), fill=(100, 60, 0, 255))
    draw.point((8, 7), fill=(100, 60, 0, 255))
    # Border
    for i in range(SIZE):
        draw.point((i, 0), fill=(120, 80, 20, 255))
        draw.point((i, 15), fill=(120, 80, 20, 255))
        draw.point((0, i), fill=(120, 80, 20, 255))
        draw.point((15, i), fill=(120, 80, 20, 255))
    return img


def create_spawner_texture():
    """Bright red spawner texture - unmissable."""
    img = Image.new("RGBA", (SIZE, SIZE), (60, 60, 60, 220))
    draw = ImageDraw.Draw(img)
    # Grid pattern (cage bars)
    for i in range(0, 16, 3):
        for j in range(16):
            draw.point((i, j), fill=(80, 80, 80, 255))
            draw.point((j, i), fill=(80, 80, 80, 255))
    # Red glow center
    for x in range(5, 11):
        for y in range(5, 11):
            draw.point((x, y), fill=(255, 0, 0, 200))
    return img


def create_pack_icon():
    """Create the pack icon (64x64)."""
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # Background gradient - dark to purple
    for y in range(size):
        r = int(20 + (y / size) * 30)
        g = 0
        b = int(40 + (y / size) * 80)
        for x in range(size):
            draw.point((x, y), fill=(r, g, b, 255))

    # "X" for X-Ray in bright green
    for i in range(size):
        t = i / size
        # First line of X
        x1 = int(10 + t * 44)
        y1 = int(10 + t * 44)
        # Second line of X
        x2 = int(54 - t * 44)
        y2 = int(10 + t * 44)
        for dx in range(-2, 3):
            for dy in range(-1, 2):
                px1, py1 = x1 + dx, y1 + dy
                px2, py2 = x2 + dx, y2 + dy
                if 0 <= px1 < size and 0 <= py1 < size:
                    draw.point((px1, py1), fill=(0, 255, 100, 255))
                if 0 <= px2 < size and 0 <= py2 < size:
                    draw.point((px2, py2), fill=(0, 255, 100, 255))

    # Diamond ore in center
    cx, cy = 32, 32
    diamond_color = (0, 255, 255, 255)
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if abs(dx) + abs(dy) <= 5:
                draw.point((cx + dx, cy + dy), fill=diamond_color)

    # Eye symbol for night vision (top)
    eye_y = 12
    for x in range(22, 43):
        dist = abs(x - 32)
        ey = eye_y + int(dist * dist * 0.05)
        draw.point((x, ey), fill=(255, 255, 0, 255))
        draw.point((x, 2 * eye_y - ey + 8), fill=(255, 255, 0, 255))
    # Pupil
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            if dx * dx + dy * dy <= 4:
                draw.point((32 + dx, eye_y + 4 + dy), fill=(255, 255, 0, 255))

    img.save("OmniX_XRay_NightVision/pack_icon.png")
    print("  [OK] pack_icon.png")


# ============================================================
# MAIN GENERATION
# ============================================================

print("=" * 60)
print("OmniX X-Ray + Night Vision - Texture Generator")
print("=" * 60)

# ----------------------------------------------------------
# 1. TRANSPARENT BLOCKS (X-Ray - invisible)
# ----------------------------------------------------------
print("\n[1/7] Generating TRANSPARENT textures (X-Ray)...")

transparent_blocks = [
    # Stone variants
    "stone.png",
    "stone_slab_top.png",
    "stone_slab_side.png",
    "stone_andesite.png",
    "stone_diorite.png",
    "stone_granite.png",
    "smooth_stone.png",
    "smooth_stone_slab_side.png",

    # Deepslate variants
    "deepslate.png",
    "deepslate_top.png",
    "cobbled_deepslate.png",
    "polished_deepslate.png",
    "deepslate_bricks.png",
    "deepslate_tiles.png",
    "cracked_deepslate_bricks.png",
    "cracked_deepslate_tiles.png",
    "chiseled_deepslate.png",

    # Netherrack
    "netherrack.png",

    # Tuff (filler block)
    "tuff.png",
    "tuff_top.png",
    "tuff_side.png",
    "polished_tuff.png",
    "polished_tuff_top.png",
    "polished_tuff_side.png",
    "tuff_bricks.png",
    "chiseled_tuff.png",
    "chiseled_tuff_top.png",

    # Calcite
    "calcite.png",

    # Basalt (nether filler)
    "basalt_top.png",
    "basalt_side.png",
    "polished_basalt_top.png",
    "polished_basalt_side.png",

    # Blackstone (nether filler)
    "blackstone.png",
    "blackstone_top.png",
    "polished_blackstone.png",
    "polished_blackstone_bricks.png",
    "cracked_polished_blackstone_bricks.png",
    "chiseled_polished_blackstone.png",
    "gilded_blackstone.png",

    # End stone
    "end_stone.png",
    "end_bricks.png",

    # Sandstone interior (common filler in deserts)
    "sandstone_normal.png",
    "sandstone_top.png",
    "sandstone_bottom.png",
    "red_sandstone_normal.png",
    "red_sandstone_top.png",
    "red_sandstone_bottom.png",

    # Terracotta (natural, not colored/glazed)
    "hardened_clay.png",

    # Bedrock - make visible with special pattern instead
    # (skip - handled separately)
]

transparent = fully_transparent()
for name in transparent_blocks:
    save(transparent, name)

# ----------------------------------------------------------
# 2. DIRT & GRAVEL SIGNALING
# ----------------------------------------------------------
print("\n[2/7] Generating SIGNALING textures (dirt/gravel)...")

# Dirt - Yellow/amber warning border with very low opacity fill
dirt_signal = create_signaling_texture(
    base_color=(139, 90, 43),     # Brown base
    warning_color=(255, 200, 0),  # Yellow warning
    pattern="dots"
)
dirt_names = [
    "dirt.png",
    "coarse_dirt.png",
    "dirt_with_roots.png",
    "farmland_dry.png",
    "farmland_wet.png",
    "mud.png",
    "muddy_mangrove_roots_top.png",
    "muddy_mangrove_roots_side.png",
    "packed_mud.png",
    "soul_soil.png",
]
for name in dirt_names:
    save(dirt_signal, name)

# Grass block - keep top slightly visible with green tint signal
grass_signal = create_signaling_texture(
    base_color=(80, 140, 40),      # Green base
    warning_color=(200, 255, 0),   # Yellow-green warning
    pattern="dots"
)
grass_names = [
    "grass_side.png",
    "grass_top.png",
    "grass_carried.png",
    "grass_side_carried.png",
    "mycelium_side.png",
    "mycelium_top.png",
    "podzol_side.png",
    "podzol_top.png",
    "grass_path_side.png",
    "grass_path_top.png",
]
for name in grass_names:
    save(grass_signal, name)

# Gravel - Orange warning with stripe pattern (danger indicator)
gravel_signal = create_signaling_texture(
    base_color=(130, 120, 110),    # Gray-ish base
    warning_color=(255, 140, 0),   # Orange warning (gravel is dangerous - can fall)
    pattern="stripes"
)
gravel_names = [
    "gravel.png",
]
for name in gravel_names:
    save(gravel_signal, name)

# Sand - also signaling (can fall, near lava in caves)
sand_signal = create_signaling_texture(
    base_color=(220, 200, 130),
    warning_color=(255, 100, 0),   # Orange-red (gravity block = danger)
    pattern="stripes"
)
sand_names = [
    "sand.png",
    "red_sand.png",
    "soul_sand.png",
    "suspicious_sand_0.png",
    "suspicious_gravel_0.png",
]
for name in sand_names:
    save(sand_signal, name)

# ----------------------------------------------------------
# 3. FALL/PRECIPICE DETECTION
# ----------------------------------------------------------
print("\n[3/7] Generating FALL DETECTION warning textures...")

fall_warning = create_fall_detection_texture()

# These blocks often border caves and drops - give them fall warning pattern
# Air blocks can't have textures, but we can mark blocks that commonly
# sit at the edge of cliffs/drops
# Exposed stone-like surfaces near air get this treatment
# We apply this to specific "edge" indicator blocks

# Cobblestone appears at dungeon edges and cave boundaries
cobble_warning = create_fall_detection_texture()
save(cobble_warning, "cobblestone.png")
save(cobble_warning, "mossy_cobblestone.png")

# Cave air visualization (subtle red to mark empty dangerous spaces)
cave_air = create_cave_air_warning()
save(cave_air, "cave_air.png")
save(cave_air, "barrier.png")

# Bedrock - bright magenta so you know you hit bottom (fall reference)
bedrock_tex = Image.new("RGBA", (SIZE, SIZE), (200, 0, 200, 180))
draw_br = ImageDraw.Draw(bedrock_tex)
for x in range(SIZE):
    for y in range(SIZE):
        if (x + y) % 4 == 0:
            draw_br.point((x, y), fill=(255, 0, 255, 255))
save(bedrock_tex, "bedrock.png")

# Scaffolding / ladder visible as navigation aids
scaffold_tex = create_bright_block((200, 180, 100), (255, 200, 50))
save(scaffold_tex, "scaffolding_top.png")
save(scaffold_tex, "scaffolding_side.png")
save(scaffold_tex, "scaffolding_bottom.png")

# ----------------------------------------------------------
# 4. ORES - Bright & Glowing (Night Vision Enhanced)
# ----------------------------------------------------------
print("\n[4/7] Generating BRIGHT ORE textures (Night Vision)...")

ores = {
    # (ore_color, glow_color, [list of texture names])
    "coal": ((50, 50, 50), (80, 80, 80), [
        "coal_ore.png", "deepslate_coal_ore.png"
    ]),
    "iron": ((216, 175, 147), (255, 200, 160), [
        "iron_ore.png", "deepslate_iron_ore.png", "raw_iron_block.png"
    ]),
    "copper": ((180, 110, 70), (230, 140, 80), [
        "copper_ore.png", "deepslate_copper_ore.png", "raw_copper_block.png"
    ]),
    "gold": ((255, 215, 0), (255, 255, 100), [
        "gold_ore.png", "deepslate_gold_ore.png", "nether_gold_ore.png", "raw_gold_block.png"
    ]),
    "redstone": ((255, 0, 0), (255, 80, 80), [
        "redstone_ore.png", "deepslate_redstone_ore.png", "lit_redstone_ore.png"
    ]),
    "lapis": ((30, 60, 200), (80, 120, 255), [
        "lapis_ore.png", "deepslate_lapis_ore.png"
    ]),
    "diamond": ((0, 255, 255), (150, 255, 255), [
        "diamond_ore.png", "deepslate_diamond_ore.png"
    ]),
    "emerald": ((0, 200, 50), (100, 255, 100), [
        "emerald_ore.png", "deepslate_emerald_ore.png"
    ]),
    "quartz": ((255, 250, 240), (255, 255, 255), [
        "quartz_ore.png"
    ]),
    "ancient_debris": ((130, 80, 50), (180, 100, 60), [
        "ancient_debris_side.png", "ancient_debris_top.png"
    ]),
}

for ore_name, (ore_color, glow_color, textures) in ores.items():
    ore_tex = create_bright_ore_texture(ore_color, glow_color)
    for tex_name in textures:
        save(ore_tex, tex_name)

# ----------------------------------------------------------
# 5. WATER, LAVA, AMETHYST - Always Visible
# ----------------------------------------------------------
print("\n[5/7] Generating WATER, LAVA, AMETHYST textures...")

# Water
water_tex = create_water_texture()
save(water_tex, "water_still.png")
save(water_tex, "water_flow.png")
save(water_tex, "water_still_grey.png")
save(water_tex, "water_flow_grey.png")

# Lava
lava_tex = create_lava_texture()
save(lava_tex, "lava_still.png")
save(lava_tex, "lava_flow.png")

# Amethyst
amethyst_tex = create_amethyst_texture()
save(amethyst_tex, "amethyst_block.png")
save(amethyst_tex, "budding_amethyst.png")
save(amethyst_tex, "amethyst_cluster.png")
save(amethyst_tex, "large_amethyst_bud.png")
save(amethyst_tex, "medium_amethyst_bud.png")
save(amethyst_tex, "small_amethyst_bud.png")

# ----------------------------------------------------------
# 6. STRUCTURES & CONSTRUCTIONS - Visible
# ----------------------------------------------------------
print("\n[6/7] Generating STRUCTURE/CONSTRUCTION textures...")

# Chests
chest_tex = create_chest_texture()
save(chest_tex, "chest_front.png")
save(chest_tex, "chest_side.png")
save(chest_tex, "chest_top.png")
save(chest_tex, "ender_chest_front.png")
save(chest_tex, "ender_chest_side.png")
save(chest_tex, "ender_chest_top.png")

# Spawner
spawner_tex = create_spawner_texture()
save(spawner_tex, "mob_spawner.png")

# TNT - very visible
tnt_side = create_bright_block((255, 50, 50), (200, 0, 0))
draw_tnt = ImageDraw.Draw(tnt_side)
for x in range(3, 13):
    for y in range(5, 11):
        if (x + y) % 2 == 0:
            draw_tnt.point((x, y), fill=(255, 255, 255, 255))
save(tnt_side, "tnt_side.png")
save(tnt_side, "tnt_top.png")
save(tnt_side, "tnt_bottom.png")

# Obsidian - visible (portals/structures)
obsidian_tex = create_bright_block((40, 0, 60), (80, 0, 120))
save(obsidian_tex, "obsidian.png")
save(obsidian_tex, "crying_obsidian.png")

# Mossy stone bricks (structures like dungeons, strongholds)
mossy_sb = create_bright_block((80, 120, 80), (60, 100, 60))
save(mossy_sb, "stonebrick.png")
save(mossy_sb, "stonebrick_mossy.png")
save(mossy_sb, "stonebrick_cracked.png")
save(mossy_sb, "stonebrick_carved.png")

# Nether Bricks (fortress)
nether_brick = create_bright_block((50, 25, 30), (80, 40, 45))
save(nether_brick, "nether_brick.png")
save(nether_brick, "red_nether_brick.png")
save(nether_brick, "cracked_nether_bricks.png")
save(nether_brick, "chiseled_nether_bricks.png")

# End Portal Frame
end_portal = create_bright_block((50, 100, 80), (80, 150, 120))
save(end_portal, "end_portal_frame_top.png")
save(end_portal, "end_portal_frame_side.png")

# Purpur (End Cities)
purpur_tex = create_bright_block((150, 100, 160), (180, 130, 190))
save(purpur_tex, "purpur_block.png")
save(purpur_tex, "purpur_pillar.png")
save(purpur_tex, "purpur_pillar_top.png")

# Prismarine (Ocean Monuments)
prismarine_tex = create_bright_block((60, 150, 130), (80, 180, 160))
save(prismarine_tex, "prismarine.png")
save(prismarine_tex, "dark_prismarine.png")
save(prismarine_tex, "prismarine_bricks.png")
save(prismarine_tex, "sea_lantern.png")

# Rail (mineshafts)
rail_tex = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw_rail = ImageDraw.Draw(rail_tex)
# Two parallel bright lines
for y in range(SIZE):
    draw_rail.point((4, y), fill=(200, 180, 100, 255))
    draw_rail.point((5, y), fill=(200, 180, 100, 255))
    draw_rail.point((10, y), fill=(200, 180, 100, 255))
    draw_rail.point((11, y), fill=(200, 180, 100, 255))
# Cross ties
for x in range(3, 13):
    for ty in [2, 6, 10, 14]:
        draw_rail.point((x, ty), fill=(139, 90, 43, 200))
save(rail_tex, "rail_normal.png")
save(rail_tex, "rail_golden.png")
save(rail_tex, "rail_activator.png")
save(rail_tex, "rail_detector.png")

# ----------------------------------------------------------
# 7. PACK ICON
# ----------------------------------------------------------
print("\n[7/7] Generating pack icon...")
create_pack_icon()

# ----------------------------------------------------------
# SUMMARY
# ----------------------------------------------------------
total = len([f for f in os.listdir(BASE_DIR) if f.endswith('.png')])
print(f"\n{'=' * 60}")
print(f"Generation complete! {total} textures created.")
print(f"Pack location: OmniX_XRay_NightVision/")
print(f"{'=' * 60}")
print(f"""
FEATURES:
  - X-RAY: Stone, Deepslate, Netherrack + variants = INVISIBLE
  - NIGHT VISION: All ores glow brightly with colored halos
  - SIGNALING: Dirt/Gravel have warning borders (yellow/orange)
  - FALL DETECTION: Cobblestone has RED chevron warnings
    (cobblestone borders caves/drops, so red = danger ahead)
  - STRUCTURES: Dungeons, Strongholds, Fortresses = BRIGHT
  - WATER/LAVA: Enhanced visibility, unmissable
  - AMETHYST: Bright purple crystal glow
  - BEDROCK: Magenta indicator (bottom of world reference)

FALL DETECTION SYSTEM:
  The pack uses a multi-layer approach to warn about precipices:
  1. All filler stone is transparent -> you can SEE drops through walls
  2. Cobblestone (cave edges) has RED+YELLOW chevrons pointing down
  3. Gravel/Sand have ORANGE stripes (gravity blocks = fall danger)
  4. Bedrock is MAGENTA (absolute bottom reference point)
  5. Cave air has subtle RED glow marking empty dangerous spaces
""")
