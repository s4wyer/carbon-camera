#!/usr/bin/env python3
"""
Professional film canister icon with realistic materials and lighting.
Based on actual Kodak/Fuji 35mm film canister construction.
"""

import numpy as np
from PIL import Image, ImageFilter, ImageDraw
import math

def srgb_to_linear(srgb):
    """Convert sRGB to linear for proper light calculations."""
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)

def linear_to_srgb(linear):
    """Convert linear back to sRGB."""
    return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * (linear ** (1/2.4)) - 0.055)

def fresnel_schlick(cos_theta, f0=0.04):
    """Fresnel reflection for metallic surfaces."""
    return f0 + (1.0 - f0) * (1.0 - cos_theta) ** 5

def ggx_distribution(ndoth, roughness):
    """GGX microfacet distribution for realistic highlights."""
    a = roughness * roughness
    a2 = a * a
    denom = ndoth * ndoth * (a2 - 1.0) + 1.0
    return a2 / (np.pi * denom * denom + 1e-6)

def create_realistic_canister(size=1024):
    """Create photorealistic 35mm film canister from above."""
    
    # Create coordinate system
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    cx, cy = size / 2.0, size / 2.0
    
    dx = (x - cx) / (size / 2)
    dy = (y - cy) / (size / 2)
    r = np.sqrt(dx**2 + dy**2)
    theta = np.arctan2(dy, dx)
    
    # Light setup: studio key light from upper left (45 degrees)
    light_dir = np.array([-0.707, -0.707, 0.5])  # x, y, z
    light_dir = light_dir / np.linalg.norm(light_dir)
    
    # Environment/fill light (softer, from opposite)
    fill_dir = np.array([0.3, 0.3, 0.8])
    fill_dir = fill_dir / np.linalg.norm(fill_dir)
    
    # Physical dimensions (all in normalized units, 1.0 = half canvas)
    outer_radius = 0.78        # Outer edge
    body_radius = 0.75         # Black plastic body
    cap_radius = 0.72          # Brass/steel cap
    cap_center_radius = 0.45   # Raised center
    hub_radius = 0.28          # Film hub
    core_radius = 0.16         # Center spindle
    hole_radius = 0.09         # Center hole
    
    # Initialize image
    img_linear = np.zeros((size, size, 3), dtype=np.float32)
    
    # Background (warm studio backdrop)
    bg_color = srgb_to_linear(np.array([246, 243, 236]) / 255.0)
    img_linear[:] = bg_color
    
    # ==========================================
    # LAYER 1: Cast shadow (soft contact shadow)
    # ==========================================
    shadow_offset = 0.03
    shadow_r = np.sqrt((dx - shadow_offset)**2 + (dy - shadow_offset)**2)
    shadow_mask = np.maximum(0, 1.0 - (shadow_r - outer_radius) / 0.08)
    shadow_mask = shadow_mask ** 2 * 0.4
    img_linear *= (1.0 - shadow_mask[:, :, None])
    
    # ==========================================
    # LAYER 2: Outer black plastic body rim
    # ==========================================
    body_mask = (r >= cap_radius) & (r <= body_radius)
    
    if np.any(body_mask):
        # Height map for rounded edge
        body_t = (r[body_mask] - cap_radius) / (body_radius - cap_radius)
        body_height = np.sin(body_t * np.pi) * 0.15 + 0.85  # Rounded bevel
        
        # Normal calculation
        normal_xy = -np.gradient(body_height)[0] * 10  # Steeper gradient
        nx = dx[body_mask] / r[body_mask] * normal_xy
        ny = dy[body_mask] / r[body_mask] * normal_xy
        nz = np.sqrt(np.maximum(0, 1.0 - nx**2 - ny**2))
        
        # Lighting
        ndotl = nx * light_dir[0] + ny * light_dir[1] + nz * light_dir[2]
        ndotf = nx * fill_dir[0] + ny * fill_dir[1] + nz * fill_dir[2]
        
        # Matte black plastic material
        base_color = np.array([0.015, 0.015, 0.018])  # Very dark
        diffuse = np.maximum(0, ndotl) * 0.3 + np.maximum(0, ndotf) * 0.15 + 0.02
        
        # Subtle texture
        noise = np.sin(theta[body_mask] * 180) * 0.02 + np.sin(r[body_mask] * size * 0.5) * 0.01
        
        body_color = base_color * (diffuse[:, None] + noise[:, None])
        img_linear[body_mask] = body_color
    
    # ==========================================
    # LAYER 3: Main brass/steel cap surface
    # ==========================================
    cap_mask = (r >= cap_center_radius) & (r < cap_radius)
    
    if np.any(cap_mask):
        # Gently curved cap surface
        cap_t = (r[cap_mask] - cap_center_radius) / (cap_radius - cap_center_radius)
        cap_height = 0.05 * (1.0 - cap_t**2)  # Subtle dish
        
        # Normal (pointing mostly up with slight radial tilt)
        radial_tilt = (cap_t - 0.5) * 0.3
        nx = dx[cap_mask] / r[cap_mask] * radial_tilt
        ny = dy[cap_mask] / r[cap_mask] * radial_tilt
        nz = np.sqrt(1.0 - nx**2 - ny**2)
        
        # View vector (straight down)
        vx, vy, vz = 0, 0, 1
        
        # Lighting vectors
        ndotl = nx * light_dir[0] + ny * light_dir[1] + nz * light_dir[2]
        ndotv = nz  # simplified since view is (0,0,1)
        
        # Half vector for specular
        hx = light_dir[0] + vx
        hy = light_dir[1] + vy
        hz = light_dir[2] + vz
        hl = np.sqrt(hx**2 + hy**2 + hz**2) + 1e-6
        hx, hy, hz = hx/hl, hy/hl, hz/hl
        ndoth = np.maximum(0, nx * hx + ny * hy + nz * hz)
        
        # Brushed metal anisotropic texture
        # Circular brushing pattern (like a lathe)
        brush_angle = theta[cap_mask]
        light_angle = np.arctan2(light_dir[1], light_dir[0])
        aniso_factor = np.abs(np.sin((brush_angle - light_angle) * 1.0))
        
        # Micro-grooves from machining
        groove_pattern = np.sin(r[cap_mask] * size * 2.5) * 0.5 + 0.5
        groove_detail = np.sin(r[cap_mask] * size * 12.0) * 0.5 + 0.5
        
        # PBR material: brushed brass
        base_color = np.array([0.72, 0.61, 0.38])  # Brass albedo
        metallic = 0.95
        roughness = 0.35 + groove_pattern * 0.15  # Varies with grooves
        
        # Diffuse (minimal for metals)
        diffuse = np.maximum(0, ndotl) * (1.0 - metallic) * 0.2
        
        # Specular: GGX + anisotropic modulation
        spec_d = ggx_distribution(ndoth, roughness)
        fresnel = fresnel_schlick(np.maximum(0, ndotv), f0=0.04)
        specular = spec_d * fresnel * np.maximum(0, ndotl)
        
        # Anisotropic elongation
        specular *= (0.3 + 0.7 * aniso_factor)
        
        # Ambient occlusion near edges
        ao = 0.4 + 0.6 * (1.0 - cap_t**1.5)
        
        # Combine
        cap_color = base_color * (diffuse[:, None] + 0.05) * ao[:, None] + \
                    base_color * specular[:, None] + \
                    groove_pattern[:, None] * 0.02 + \
                    groove_detail[:, None] * 0.008
        
        img_linear[cap_mask] = cap_color
    
    # ==========================================
    # LAYER 4: Raised center hub with stamped details
    # ==========================================
    hub_mask = (r >= core_radius) & (r < cap_center_radius)
    
    if np.any(hub_mask):
        # Higher raised section
        hub_t = (r[hub_mask] - core_radius) / (cap_center_radius - core_radius)
        hub_height = 0.12 + 0.03 * np.sin(hub_t * np.pi)
        
        # Normals with more pronounced curvature
        edge_dist = np.minimum(
            np.abs(r[hub_mask] - core_radius),
            np.abs(r[hub_mask] - cap_center_radius)
        ) / 0.02
        edge_curve = np.minimum(edge_dist, 1.0)
        
        radial_tilt = (hub_t - 0.5) * 0.5
        nx = dx[hub_mask] / r[hub_mask] * radial_tilt
        ny = dy[hub_mask] / r[hub_mask] * radial_tilt
        nz = np.sqrt(np.maximum(0.5, 1.0 - nx**2 - ny**2))
        
        ndotl = nx * light_dir[0] + ny * light_dir[1] + nz * light_dir[2]
        ndotv = nz
        
        # Half vector
        hx, hy, hz = light_dir[0], light_dir[1], light_dir[2] + 1
        hl = np.sqrt(hx**2 + hy**2 + hz**2)
        ndoth = np.maximum(0, (nx * hx + ny * hy + nz * hz) / hl)
        
        # Slightly darker brass
        base_color = np.array([0.68, 0.58, 0.36])
        roughness = 0.4
        
        diffuse = np.maximum(0, ndotl) * 0.18
        spec_d = ggx_distribution(ndoth, roughness)
        specular = spec_d * 0.5 * np.maximum(0, ndotl)
        
        # Edge highlights
        edge_highlight = (1.0 - edge_curve) * np.maximum(0, ndotl) * 0.3
        
        # Fine concentric stamping rings
        stamp_ring1 = (r[hub_mask] > 0.37) & (r[hub_mask] < 0.39)
        stamp_ring2 = (r[hub_mask] > 0.25) & (r[hub_mask] < 0.26)
        
        hub_color = base_color * (diffuse[:, None] + 0.04) + \
                    base_color * specular[:, None] + \
                    edge_highlight[:, None]
        
        # Darken stamped rings
        hub_color[stamp_ring1 | stamp_ring2] *= 0.7
        
        img_linear[hub_mask] = hub_color
    
    # ==========================================
    # LAYER 5: Dark plastic film core with drive slots
    # ==========================================
    core_mask = (r >= hole_radius) & (r < core_radius)
    
    if np.any(core_mask):
        core_t = (r[core_mask] - hole_radius) / (core_radius - hole_radius)
        
        # Normal pointing mostly up
        nx = dx[core_mask] / r[core_mask] * 0.2
        ny = dy[core_mask] / r[core_mask] * 0.2
        nz = np.sqrt(0.96 - nx**2 - ny**2)
        
        ndotl = nx * light_dir[0] + ny * light_dir[1] + nz * light_dir[2]
        
        # Dark gray/black plastic
        base_color = np.array([0.05, 0.05, 0.06])
        diffuse = np.maximum(0, ndotl) * 0.25 + 0.03
        
        # Three drive slots (film advance teeth)
        slot_width = 0.15
        for slot_i in range(3):
            slot_angle = slot_i * (2 * np.pi / 3)
            angle_diff = np.abs(np.angle(np.exp(1j * (theta[core_mask] - slot_angle))))
            in_slot = (angle_diff < slot_width) & (r[core_mask] > 0.12)
            if np.any(in_slot):
                diffuse[in_slot] *= 0.5  # Darken slots
        
        core_color = base_color * diffuse[:, None]
        img_linear[core_mask] = core_color
    
    # ==========================================
    # LAYER 6: Center hole (pure black)
    # ==========================================
    hole_mask = r < hole_radius
    if np.any(hole_mask):
        hole_fade = (hole_radius - r[hole_mask]) / hole_radius
        hole_color = np.array([0.005, 0.005, 0.006]) * (1.0 - hole_fade[:, None] * 0.8)
        img_linear[hole_mask] = hole_color
    
    # ==========================================
    # LAYER 7: Red frame counter dot at top
    # ==========================================
    dot_x = cx
    dot_y = cy - (body_radius * 0.94 * size / 2)
    dot_r = np.sqrt((x - dot_x)**2 + (y - dot_y)**2)
    dot_mask = dot_r < (size * 0.01)
    if np.any(dot_mask):
        # Safelight red
        red_linear = srgb_to_linear(np.array([255, 59, 29]) / 255.0)
        img_linear[dot_mask] = red_linear
    
    # ==========================================
    # Post-processing
    # ==========================================
    
    # Subtle vignette for depth
    vignette = 1.0 - (r ** 2) * 0.08
    img_linear *= vignette[:, :, None]
    
    # Convert to sRGB
    img_srgb = linear_to_srgb(img_linear)
    img_srgb = np.clip(img_srgb * 255, 0, 255).astype(np.uint8)
    
    img = Image.fromarray(img_srgb, 'RGB')
    
    # Subtle sharpening for final detail
    img = img.filter(ImageFilter.UnsharpMask(radius=1.5, percent=50, threshold=2))
    
    return img


def create_dark_variant(size=1024):
    """Dark background variant for Remjet black canvas."""
    
    # Generate on dark background
    img = create_realistic_canister(size)
    
    # Replace background
    arr = np.array(img).astype(np.float32) / 255.0
    
    # Detect background (near original cream color)
    bg_mask = (arr[:, :, 0] > 0.9) & (arr[:, :, 1] > 0.9) & (arr[:, :, 2] > 0.9)
    
    # New background: Remjet black with subtle gradient
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    cx, cy = size / 2.0, size / 2.0
    dx, dy = x - cx, y - cy
    r = np.sqrt(dx**2 + dy**2) / (size / 2)
    
    bg = np.array([14, 14, 16]) / 255.0
    bg_gradient = bg * (1.0 + r[:, :, None] * 0.05)
    
    arr[bg_mask] = bg_gradient[bg_mask]
    
    # Enhance shadow on dark background
    shadow_r = np.sqrt((dx/size + 0.03)**2 + (dy/size + 0.03)**2)
    shadow = np.maximum(0, 1.0 - (shadow_r * 2 - 0.75) / 0.15) ** 2 * 0.3
    arr *= (1.0 - shadow[:, :, None])
    
    img_dark = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), 'RGB')
    
    return img_dark


if __name__ == '__main__':
    print("Rendering realistic film canister icon...")
    print("(This will take 30-60 seconds for proper PBR shading)")
    
    # Light version
    img_light = create_realistic_canister(1024)
    img_light.save("carbon_canister_light.png", "PNG")
    print("✓ Saved: carbon_canister_light.png")
    
    # Dark version
    img_dark = create_dark_variant(1024)
    img_dark.save("carbon_canister_dark.png", "PNG")
    print("✓ Saved: carbon_canister_dark.png")
    
    # Preview sizes
    img_light.resize((512, 512), Image.Resampling.LANCZOS).save("preview_light_512.png")
    img_dark.resize((512, 512), Image.Resampling.LANCZOS).save("preview_dark_512.png")
    print("✓ Preview renders complete")
    
    print("\nDone! Check carbon_canister_light.png and carbon_canister_dark.png")
