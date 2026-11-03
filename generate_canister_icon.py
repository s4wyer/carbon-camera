#!/usr/bin/env python3
"""
Generate a film canister app icon from above.
Black knurled body with brass cap, shot straight down.
"""

from PIL import Image, ImageDraw
import math

def create_icon(size=1024):
    """Create a film canister icon viewed from above."""
    
    # Create image with transparency
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # Colors
    remjet_black = (14, 14, 16, 255)  # #0E0E10
    brass = (183, 155, 98, 255)  # #B79B62
    brass_highlight = (210, 185, 130, 255)
    brass_shadow = (150, 125, 70, 255)
    knurl_dark = (8, 8, 10, 255)
    
    # Dimensions (as ratios of size)
    outer_radius = int(size * 0.42)
    brass_cap_radius = int(size * 0.38)
    inner_cap_radius = int(size * 0.30)
    center_indent_radius = int(size * 0.08)
    
    # Draw outer knurled body (visible ring around brass cap)
    draw.ellipse(
        [center - outer_radius, center - outer_radius,
         center + outer_radius, center + outer_radius],
        fill=remjet_black
    )
    
    # Draw knurling texture on the body ring
    num_knurls = 72
    for i in range(num_knurls):
        angle = (i / num_knurls) * 2 * math.pi
        # Knurl lines from outer edge toward brass cap
        x1 = center + math.cos(angle) * outer_radius
        y1 = center + math.sin(angle) * outer_radius
        x2 = center + math.cos(angle) * (brass_cap_radius + 10)
        y2 = center + math.sin(angle) * (brass_cap_radius + 10)
        
        # Alternate slightly darker lines for knurling effect
        color = knurl_dark if i % 2 == 0 else remjet_black
        draw.line([(x1, y1), (x2, y2)], fill=color, width=2)
    
    # Draw brass cap with subtle gradient effect via concentric circles
    gradient_steps = 50
    for step in range(gradient_steps):
        ratio = step / gradient_steps
        radius = brass_cap_radius - (brass_cap_radius - inner_cap_radius) * ratio
        
        # Radial gradient: lighter at top-left (light source), darker at bottom-right
        light_angle = math.pi * 1.25  # Top-left
        step_angle = math.atan2(step - gradient_steps/2, step - gradient_steps/2)
        light_intensity = 0.5 + 0.5 * math.cos(step_angle - light_angle) * (1 - ratio * 0.3)
        light_intensity = max(0.3, min(1.0, light_intensity))
        
        r = int(brass[0] * light_intensity)
        g = int(brass[1] * light_intensity)
        b = int(brass[2] * light_intensity)
        
        draw.ellipse(
            [center - radius, center - radius,
             center + radius, center + radius],
            fill=(r, g, b, 255)
        )
    
    # Draw inner cap surface (slightly recessed appearance)
    draw.ellipse(
        [center - inner_cap_radius, center - inner_cap_radius,
         center + inner_cap_radius, center + inner_cap_radius],
        fill=brass_shadow
    )
    
    # Add highlight arc on brass (top-left)
    for i in range(20):
        angle_start = 180 + i * 2
        angle_end = angle_start + 60
        radius = brass_cap_radius - i * 2
        
        # Create a subtle arc highlight
        alpha = int(30 - i * 1.5)
        if alpha > 0:
            # Draw arc segments
            for angle in range(int(angle_start), int(angle_end), 2):
                rad = math.radians(angle)
                x = center + math.cos(rad) * radius
                y = center + math.sin(rad) * radius
                draw.ellipse(
                    [x-3, y-3, x+3, y+3],
                    fill=(255, 255, 255, alpha)
                )
    
    # Draw center indent/spindle mount
    draw.ellipse(
        [center - center_indent_radius, center - center_indent_radius,
         center + center_indent_radius, center + center_indent_radius],
        fill=(80, 70, 50, 255)
    )
    
    # Add small highlight on center indent
    highlight_offset = int(center_indent_radius * 0.3)
    draw.ellipse(
        [center - highlight_offset - 3, center - highlight_offset - 3,
         center - highlight_offset + 3, center - highlight_offset + 3],
        fill=(200, 180, 130, 180)
    )
    
    # Add subtle shadow gradient on right and bottom of brass cap
    shadow_steps = 30
    for step in range(shadow_steps):
        angle_start = -45
        angle_end = 135
        angle = angle_start + (angle_end - angle_start) * (step / shadow_steps)
        rad = math.radians(angle)
        
        x = center + math.cos(rad) * brass_cap_radius
        y = center + math.sin(rad) * brass_cap_radius
        
        shadow_alpha = int(40 * (step / shadow_steps))
        draw.ellipse(
            [x-8, y-8, x+8, y+8],
            fill=(0, 0, 0, shadow_alpha)
        )
    
    return img

# Generate multiple sizes
sizes = [1024, 512, 256, 128, 64]

for size in sizes:
    icon = create_icon(size)
    filename = f'carbon_icon_{size}x{size}.png'
    icon.save(filename, 'PNG')
    print(f'Generated {filename}')

print('\nIcon generation complete.')
print('Main icon: carbon_icon_1024x1024.png')
