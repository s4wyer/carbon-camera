#!/usr/bin/env python3
"""
Generate a realistic, beautifully rendered film canister top app icon using NumPy + PIL.
An authentic 35mm canister viewed from top:
- iOS rounded squircle canvas (Receipt #F6F3EC or deep Remjet #0E0E10)
- Cylindrical canister body rim with knurled / matte dark texture
- Metal spool spindle / core protruding in the center (cruciform / notched drive hub)
- Circular stamped metal cap with concentric machined grooves and radial brushed metal sheen
- Tactile light from top-left, soft ambient drop shadow onto the squircle surface
"""

import numpy as np
from PIL import Image, ImageFilter

def make_film_canister_icon(size=1024):
    # Work at 1024x1024
    w, h = size, size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w / 2.0, h / 2.0
    
    # Distance and angle from center
    dx = x - cx
    dy = y - cy
    r = np.sqrt(dx * dx + dy * dy)
    theta = np.arctan2(dy, dx) # -pi to pi

    # Light direction: from top-left (approx -135 deg / 3*pi/4 in screen coords)
    # Light vector in 2D: normalized (-0.6, -0.8)
    lx, ly = -0.5547, -0.8320
    # dot product with radial normal (pointing outwards)
    cos_light = (dx * lx + dy * ly) / np.maximum(r, 1e-5)

    # -------------------------------------------------------------
    # 1. Background: Warm Editorial "Receipt" canvas (#F6F3EC)
    # -------------------------------------------------------------
    # Subtly vignette / directional daylight gradient
    bg_light = 0.5 * (dx * lx + dy * ly) / (size * 0.7)
    # Base #F6F3EC is rgb(246, 243, 236)
    bg_r = 246 + bg_light * 8
    bg_g = 243 + bg_light * 8
    bg_b = 236 + bg_light * 6

    # -------------------------------------------------------------
    # 2. Geometry Dimensions
    # -------------------------------------------------------------
    # App icon padding: canister sits comfortably inside
    R_outer = size * 0.385       # Canister crimped outer lip
    R_bevel = size * 0.365       # Inner edge of outer metal rim
    R_body = size * 0.355        # Recessed cap plate
    R_step = size * 0.220        # Raised center hub step
    R_core_outer = size * 0.135   # Central spool spool/core tube
    R_core_inner = size * 0.085   # Core inner bore
    R_spindle_hole = size * 0.045 # Central keyhole

    # -------------------------------------------------------------
    # 3. Canister Cast Shadow onto canvas
    # -------------------------------------------------------------
    # Shadow offset towards bottom-right (opposite light)
    sdx = dx - (-lx * size * 0.035)
    sdy = dy - (-ly * size * 0.035)
    sr = np.sqrt(sdx * sdx + sdy * sdy)
    # Soft drop shadow
    shadow_alpha = np.clip(1.0 - (sr - R_outer) / (size * 0.08), 0.0, 1.0)
    shadow_alpha = np.maximum(0.0, shadow_alpha) ** 2 * 0.35

    # -------------------------------------------------------------
    # 4. Machined Metal & Brass Shading
    # -------------------------------------------------------------
    # Brushed metal anisotropic reflection (creates opposite bright lobes perpendicular to light)
    # Brushed grooves run concentrically, so tangent is (-sin(theta), cos(theta))
    # Reflection lobes appear where tangent dot light is ~0, i.e., theta aligns with or against light
    aniso = np.abs(np.sin(theta - np.arctan2(ly, lx)))
    aniso_sheen = (aniso ** 4) * 0.45 + (aniso ** 16) * 0.35

    # Subtle concentric micro-grooves (lathe turning marks)
    lathe = 0.5 + 0.5 * np.sin(r * 1.8)
    lathe_fine = 0.5 + 0.5 * np.cos(r * 4.2)
    machined_tex = 1.0 + (lathe * 0.04 + lathe_fine * 0.03 - 0.035)

    # 35mm Spool Drive Key: standard film spools have 2 or 3 interior drive splines/notches
    # Let's create the central drive notches in the inner core
    notch_angle = np.mod(theta + np.pi/6, 2*np.pi / 3) - (np.pi / 3) # 3-fold symmetry
    in_notch = (np.abs(notch_angle) < 0.22) & (r < R_core_outer) & (r > R_spindle_hole * 1.2)

    # Colors:
    # Outer lip & cap: Machined steel / warm dark titanium with vintage brass warmth
    # Steel/brass balance: #D4AF37 brass accent or warm precision steel
    # Let's make the cap rich precision steel/brass like classic Leica/Kodak reloadable cassettes:
    # Warm metallic base: rgb(185, 172, 148)
    # Remjet black canister outer wall

    # Canvas buffer
    canvas = np.zeros((h, w, 3), dtype=np.float32)
    canvas[:, :, 0] = bg_r * (1.0 - shadow_alpha)
    canvas[:, :, 1] = bg_g * (1.0 - shadow_alpha)
    canvas[:, :, 2] = bg_b * (1.0 - shadow_alpha)

    # -------------------------------------------------------------
    # 5. Composite Layers (outside to inside)
    # -------------------------------------------------------------

    # A. Outer Knurled Rim / Lip (R_bevel <= r <= R_outer)
    # Real 35mm canisters have a stamped / crimped metal rim
    mask_outer_rim = (r <= R_outer) & (r > R_bevel)
    # Bevel shading: top-left bright, bottom-right dark
    rim_normal_z = np.clip(1.0 - ((r - R_bevel) / (R_outer - R_bevel) - 0.5)**2 * 4, 0.2, 1.0)
    rim_lighting = 0.5 + 0.45 * cos_light + 0.3 * (cos_light ** 3)
    rim_col = np.array([170, 162, 150], dtype=np.float32) * (rim_lighting * rim_normal_z)[:, :, None]

    # Fine knurling / serration on outer edge (classic reloadable cassette grip)
    knurl_pattern = np.cos(theta * 96) * 0.5 + 0.5
    rim_col *= (0.85 + 0.25 * knurl_pattern)[:, :, None]

    # B. Inner Bevel / Rim Chamfer
    mask_chamfer = (r <= R_bevel) & (r > R_body)
    chamfer_light = 0.5 - 0.4 * cos_light # Inside of rim catches light on opposite side
    chamfer_col = np.array([90, 85, 80], dtype=np.float32) * (0.6 + 0.5 * chamfer_light)[:, :, None]

    # C. Main Recessed Cap Surface (R_step <= r <= R_body)
    mask_cap = (r <= R_body) & (r > R_step)
    # Diffuse light + brushed anisotropic highlights + lathe texture
    cap_diffuse = 0.55 + 0.25 * cos_light
    cap_specular = aniso_sheen * (0.6 + 0.4 * np.maximum(0.0, cos_light))
    cap_val = (cap_diffuse + cap_specular) * machined_tex
    # Warm darkened brass/steel alloy tone:
    # Slightly darker near the outer perimeter (drop shadow from outer rim)
    rim_inner_shadow = np.clip((R_body - r) / 8.0, 0.0, 1.0)
    cap_base = np.array([195, 178, 142], dtype=np.float32) # rich warm champagne / brass
    cap_col = cap_base * (cap_val * (0.7 + 0.3 * rim_inner_shadow))[:, :, None]

    # Embossed classic brand concentric stamp ring
    stamp_r1, stamp_r2 = size * 0.275, size * 0.282
    mask_stamp = (r >= stamp_r1) & (r <= stamp_r2)
    stamp_shade = np.where(cos_light > 0, 1.25, 0.75)
    cap_col[mask_stamp] *= stamp_shade[mask_stamp, None]

    # D. Raised Center Stepped Collar (R_core_outer <= r <= R_step)
    mask_step = (r <= R_step) & (r > R_core_outer)
    # Raised circular boss that holds the spool spindle
    step_diffuse = 0.6 + 0.35 * cos_light
    step_sheen = (aniso ** 6) * 0.4
    step_val = (step_diffuse + step_sheen) * machined_tex
    # Step has a highlight rim at top-left
    step_rim_hl = np.clip(1.0 - np.abs(r - R_step) / 2.5, 0.0, 1.0) * np.maximum(0.0, cos_light)
    step_col = np.array([210, 192, 155], dtype=np.float32) * step_val[:, :, None]
    step_col += (step_rim_hl * 60)[:, :, None]

    # Drop shadow cast by step onto cap
    step_shadow = np.clip((r - R_step) / 12.0, 0.0, 1.0)
    mask_step_shadow = (r > R_step) & (r < R_step + 14) & (cos_light < 0.2)
    cap_col[mask_step_shadow] *= (0.65 + 0.35 * step_shadow[mask_step_shadow, None])

    # E. Center Spool Spindle (Plastic/delrin or steel core)
    # In 35mm film, the central spool is black or deep Remjet with 3 drive lugs
    mask_core_rim = (r <= R_core_outer) & (r > R_core_inner)
    core_diffuse = 0.4 + 0.4 * cos_light
    # Deep matte Remjet black / dark graphite
    core_col = np.array([32, 33, 36], dtype=np.float32) * (0.7 + 0.5 * core_diffuse)[:, :, None]
    # Highlight on top-left outer edge of core
    core_edge_hl = np.clip(1.0 - np.abs(r - R_core_outer) / 2.0, 0.0, 1.0) * np.maximum(0.0, cos_light)
    core_col += (core_edge_hl * 80)[:, :, None]

    # F. Spindle Bore & Drive Lugs (r <= R_core_inner)
    mask_inner_bore = (r <= R_core_inner)
    # Deep cavity shadow
    bore_depth = np.clip(r / R_core_inner, 0.0, 1.0)
    bore_col = np.array([12, 12, 14], dtype=np.float32) * (0.3 + 0.5 * bore_depth)[:, :, None]

    # Drive splines / lugs (3 distinct teeth that a camera's film advance fork engages)
    # These stick inward from R_core_inner to R_spindle_hole * 1.3
    lug_w = 0.25 # angular width
    is_lug = (np.abs(notch_angle) < lug_w) & (r <= R_core_inner + 2) & (r >= R_spindle_hole * 1.3)
    lug_light = 0.5 + 0.4 * cos_light
    lug_col = np.array([45, 46, 50], dtype=np.float32) * (0.6 + 0.5 * lug_light)[:, :, None]

    # Center through-hole (deepest black)
    mask_center_void = (r < R_spindle_hole * 1.1)
    void_col = np.array([6, 6, 8], dtype=np.float32)

    # -------------------------------------------------------------
    # 6. Smooth Antialiased Compositing
    # -------------------------------------------------------------
    # Outer silhouette AA mask
    aa_width = 1.8
    alpha_canister = np.clip((R_outer - r) / aa_width + 0.5, 0.0, 1.0)

    # Composite canister parts
    canister_rgb = np.zeros_like(canvas)
    canister_rgb = np.where(mask_outer_rim[:, :, None], rim_col, canister_rgb)
    canister_rgb = np.where(mask_chamfer[:, :, None], chamfer_col, canister_rgb)
    canister_rgb = np.where(mask_cap[:, :, None], cap_col, canister_rgb)
    canister_rgb = np.where(mask_step[:, :, None], step_col, canister_rgb)
    canister_rgb = np.where(mask_core_rim[:, :, None], core_col, canister_rgb)
    canister_rgb = np.where(mask_inner_bore[:, :, None], bore_col, canister_rgb)
    canister_rgb = np.where(is_lug[:, :, None], lug_col, canister_rgb)
    canister_rgb = np.where(mask_center_void[:, :, None], void_col, canister_rgb)

    # Subtle red safelight / film accent:
    # A single tiny, sharp, beautiful red index pip at top (12 o'clock / frame count alignment mark)
    pip_dx = dx
    pip_dy = dy - (-R_bevel + 1)
    pip_r = np.sqrt(pip_dx * pip_dx + pip_dy * pip_dy)
    mask_pip = pip_r < size * 0.012
    # Carbon's Safelight Red #FF3B1D = (255, 59, 29)
    canister_rgb[mask_pip] = [255, 59, 29]

    # Blend canister over background canvas using AA edge
    final_rgb = canvas * (1.0 - alpha_canister[:, :, None]) + canister_rgb * alpha_canister[:, :, None]

    # Clamp and return PIL Image
    final_rgb = np.clip(final_rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(final_rgb, mode='RGB')


def make_remjet_dark_variant(size=1024):
    """
    Variant B: Dark Mode / Remjet Canvas (#0E0E10)
    Gives a striking, high-contrast darkroom aesthetic on iOS home screen.
    """
    w, h = size, size
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w / 2.0, h / 2.0
    
    dx = x - cx
    dy = y - cy
    r = np.sqrt(dx * dx + dy * dy)
    theta = np.arctan2(dy, dx)

    lx, ly = -0.5547, -0.8320
    cos_light = (dx * lx + dy * ly) / np.maximum(r, 1e-5)

    # Remjet black canvas with subtle darkroom glow
    bg_r = 14 + np.maximum(0.0, cos_light) * 6
    bg_g = 14 + np.maximum(0.0, cos_light) * 6
    bg_b = 16 + np.maximum(0.0, cos_light) * 7

    R_outer = size * 0.385
    R_bevel = size * 0.365
    R_body = size * 0.355
    R_step = size * 0.220
    R_core_outer = size * 0.135
    R_core_inner = size * 0.085
    R_spindle_hole = size * 0.045

    # Canvas buffer
    canvas = np.zeros((h, w, 3), dtype=np.float32)
    canvas[:, :, 0] = bg_r
    canvas[:, :, 1] = bg_g
    canvas[:, :, 2] = bg_b

    # Subtle ambient floor shadow
    sr = np.sqrt((dx - 12)**2 + (dy - 16)**2)
    shadow = np.clip(1.0 - (sr - R_outer) / (size * 0.1), 0.0, 1.0) ** 2 * 0.6
    canvas *= (1.0 - shadow[:, :, None])

    # Metals
    aniso = np.abs(np.sin(theta - np.arctan2(ly, lx)))
    aniso_sheen = (aniso ** 5) * 0.55 + (aniso ** 18) * 0.45
    machined_tex = 1.0 + (np.sin(r * 1.8) * 0.035 + np.cos(r * 4.2) * 0.025)

    # Outer Rim
    mask_outer_rim = (r <= R_outer) & (r > R_bevel)
    rim_normal_z = np.clip(1.0 - ((r - R_bevel) / (R_outer - R_bevel) - 0.5)**2 * 4, 0.2, 1.0)
    rim_lighting = 0.5 + 0.45 * cos_light + 0.35 * (cos_light ** 3)
    rim_col = np.array([215, 205, 185], dtype=np.float32) * (rim_lighting * rim_normal_z)[:, :, None]
    knurl_pattern = np.cos(theta * 96) * 0.5 + 0.5
    rim_col *= (0.82 + 0.3 * knurl_pattern)[:, :, None]

    # Chamfer
    mask_chamfer = (r <= R_bevel) & (r > R_body)
    chamfer_light = 0.5 - 0.4 * cos_light
    chamfer_col = np.array([80, 75, 70], dtype=np.float32) * (0.6 + 0.5 * chamfer_light)[:, :, None]

    # Cap surface
    mask_cap = (r <= R_body) & (r > R_step)
    cap_diffuse = 0.55 + 0.3 * cos_light
    cap_specular = aniso_sheen * (0.65 + 0.45 * np.maximum(0.0, cos_light))
    cap_val = (cap_diffuse + cap_specular) * machined_tex
    rim_inner_shadow = np.clip((R_body - r) / 8.0, 0.0, 1.0)
    # Rich brass tone (#B79B62)
    cap_base = np.array([183, 155, 98], dtype=np.float32)
    cap_col = cap_base * (cap_val * (0.7 + 0.35 * rim_inner_shadow))[:, :, None]

    # Center stepped hub
    mask_step = (r <= R_step) & (r > R_core_outer)
    step_diffuse = 0.6 + 0.4 * cos_light
    step_sheen = (aniso ** 6) * 0.5
    step_val = (step_diffuse + step_sheen) * machined_tex
    step_rim_hl = np.clip(1.0 - np.abs(r - R_step) / 2.5, 0.0, 1.0) * np.maximum(0.0, cos_light)
    step_col = np.array([205, 178, 120], dtype=np.float32) * step_val[:, :, None] + (step_rim_hl * 70)[:, :, None]

    # Core rim & spindle
    mask_core_rim = (r <= R_core_outer) & (r > R_core_inner)
    core_diffuse = 0.4 + 0.4 * cos_light
    core_col = np.array([28, 28, 32], dtype=np.float32) * (0.7 + 0.5 * core_diffuse)[:, :, None]
    core_edge_hl = np.clip(1.0 - np.abs(r - R_core_outer) / 2.0, 0.0, 1.0) * np.maximum(0.0, cos_light)
    core_col += (core_edge_hl * 90)[:, :, None]

    # Bore & 3 Drive Lugs
    notch_angle = np.mod(theta + np.pi/6, 2*np.pi / 3) - (np.pi / 3)
    mask_inner_bore = (r <= R_core_inner)
    bore_col = np.array([8, 8, 10], dtype=np.float32) * (0.4 + 0.6 * np.clip(r / R_core_inner, 0.0, 1.0))[:, :, None]

    is_lug = (np.abs(notch_angle) < 0.25) & (r <= R_core_inner + 2) & (r >= R_spindle_hole * 1.3)
    lug_col = np.array([42, 42, 48], dtype=np.float32) * (0.6 + 0.5 * (0.5 + 0.4 * cos_light))[:, :, None]

    mask_center_void = (r < R_spindle_hole * 1.1)
    void_col = np.array([2, 2, 3], dtype=np.float32)

    # Assemble
    alpha_canister = np.clip((R_outer - r) / 1.8 + 0.5, 0.0, 1.0)
    canister_rgb = np.zeros_like(canvas)
    canister_rgb = np.where(mask_outer_rim[:, :, None], rim_col, canister_rgb)
    canister_rgb = np.where(mask_chamfer[:, :, None], chamfer_col, canister_rgb)
    canister_rgb = np.where(mask_cap[:, :, None], cap_col, canister_rgb)
    canister_rgb = np.where(mask_step[:, :, None], step_col, canister_rgb)
    canister_rgb = np.where(mask_core_rim[:, :, None], core_col, canister_rgb)
    canister_rgb = np.where(mask_inner_bore[:, :, None], bore_col, canister_rgb)
    canister_rgb = np.where(is_lug[:, :, None], lug_col, canister_rgb)
    canister_rgb = np.where(mask_center_void[:, :, None], void_col, canister_rgb)

    # Safelight pip
    pip_r = np.sqrt(dx * dx + (dy - (-R_bevel + 1))**2)
    canister_rgb[pip_r < size * 0.012] = [255, 59, 29]

    final_rgb = canvas * (1.0 - alpha_canister[:, :, None]) + canister_rgb * alpha_canister[:, :, None]
    final_rgb = np.clip(final_rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(final_rgb, mode='RGB')


if __name__ == '__main__':
    print("Rendering Receipt Canvas edition (1024x1024)...")
    img_receipt = make_film_canister_icon(1024)
    img_receipt.save("carbon_icon_canister_receipt.png", "PNG")

    print("Rendering Remjet Dark edition (1024x1024)...")
    img_dark = make_remjet_dark_variant(1024)
    img_dark.save("carbon_icon_canister_remjet.png", "PNG")

    # Downscale previews for instant inspection
    img_receipt.resize((512, 512), Image.Resampling.LANCZOS).save("preview_receipt_512.png")
    img_dark.resize((512, 512), Image.Resampling.LANCZOS).save("preview_dark_512.png")
    print("Done!")
