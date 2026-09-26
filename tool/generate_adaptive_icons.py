import zlib
import struct
import math
import os

def read_png(path):
    with open(path, 'rb') as f:
        data = f.read()
    pos = 8
    width, height = 0, 0
    idat_data = bytearray()
    while pos < len(data):
        length, chunk_type = struct.unpack('>I4s', data[pos:pos+8])
        pos += 8
        chunk_data = data[pos:pos+length]
        pos += length + 4
        if chunk_type == b'IHDR':
            width, height, bit_depth, color_type = struct.unpack('>IIBB', chunk_data[:10])
        elif chunk_type == b'IDAT':
            idat_data.extend(chunk_data)
        elif chunk_type == b'IEND':
            break

    raw = zlib.decompress(idat_data)
    bytes_per_pixel = 3 if color_type == 2 else 4
    stride = width * bytes_per_pixel + 1
    pixels = bytearray(width * height * bytes_per_pixel)
    prev_line = bytearray(width * bytes_per_pixel)

    for y in range(height):
        filter_type = raw[y * stride]
        line = bytearray(raw[y * stride + 1 : (y + 1) * stride])
        if filter_type == 0:
            pass
        elif filter_type == 1:
            for i in range(bytes_per_pixel, len(line)):
                line[i] = (line[i] + line[i - bytes_per_pixel]) & 0xFF
        elif filter_type == 2:
            for i in range(len(line)):
                line[i] = (line[i] + prev_line[i]) & 0xFF
        elif filter_type == 3:
            for i in range(len(line)):
                left = line[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                up = prev_line[i]
                line[i] = (line[i] + ((left + up) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(len(line)):
                a = line[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                b = prev_line[i]
                c = prev_line[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        pixels[y * width * bytes_per_pixel : (y + 1) * width * bytes_per_pixel] = line
        prev_line = line

    return width, height, bytes_per_pixel, pixels

def write_png(path, width, height, pixels_rgba):
    raw_lines = bytearray()
    for y in range(height):
        raw_lines.append(0) # filter None
        raw_lines.extend(pixels_rgba[y * width * 4 : (y + 1) * width * 4])
    
    compressed = zlib.compress(bytes(raw_lines), 9)
    
    def make_chunk(chunk_type, data):
        chunk = chunk_type + data
        crc = zlib.crc32(chunk) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', crc)
    
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    out = b'\x89PNG\r\n\x1a\n' + make_chunk(b'IHDR', ihdr) + make_chunk(b'IDAT', compressed) + make_chunk(b'IEND', b'')
    
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(out)
    print(f"Wrote {path} ({width}x{height})")

def bilinear_sample(src_w, src_h, bpp, src_px, u, v):
    if u < 0 or u >= src_w - 1 or v < 0 or v >= src_h - 1:
        # Return background #0A0A0C
        return (10, 10, 12)
    x0, y0 = int(u), int(v)
    x1, y1 = x0 + 1, y0 + 1
    fx, fy = u - x0, v - y0
    
    def get_rgb(x, y):
        idx = (y * src_w + x) * bpp
        return src_px[idx], src_px[idx+1], src_px[idx+2]
        
    r00, g00, b00 = get_rgb(x0, y0)
    r10, g10, b10 = get_rgb(x1, y0)
    r01, g01, b01 = get_rgb(x0, y1)
    r11, g11, b11 = get_rgb(x1, y1)
    
    r = (1-fx)*(1-fy)*r00 + fx*(1-fy)*r10 + (1-fx)*fy*r01 + fx*fy*r11
    g = (1-fx)*(1-fy)*g00 + fx*(1-fy)*g10 + (1-fx)*fy*g01 + fx*fy*g11
    b = (1-fx)*(1-fy)*b00 + fx*(1-fy)*b10 + (1-fx)*fy*b01 + fx*fy*b11
    return int(r + 0.5), int(g + 0.5), int(b + 0.5)

# Master parameters from logo.png
SRC_PATH = 'assets/icons/logo.png'
src_w, src_h, src_bpp, src_px = read_png(SRC_PATH)
SRC_CX = 623.27
SRC_CY = 604.61
SRC_R = 409.31

# Densities
densities = {
    'mdpi': {'fg': 108, 'legacy': 48},
    'hdpi': {'fg': 162, 'legacy': 72},
    'xhdpi': {'fg': 216, 'legacy': 96},
    'xxhdpi': {'fg': 324, 'legacy': 144},
    'xxxhdpi': {'fg': 432, 'legacy': 192},
}

for density, sizes in densities.items():
    # 1. Generate ic_launcher_foreground.png
    fg_size = sizes['fg']
    fg_cx = fg_size / 2.0
    fg_cy = fg_size / 2.0
    # Safe zone on 108dp is 72dp diameter (R = 36dp).
    # We choose badge radius = 30dp -> 30/108 * fg_size
    target_fg_r = (30.0 / 108.0) * fg_size
    scale_fg = target_fg_r / SRC_R
    
    fg_pixels = bytearray(fg_size * fg_size * 4)
    for y in range(fg_size):
        for x in range(fg_size):
            dx = (x + 0.5) - fg_cx
            dy = (y + 0.5) - fg_cy
            dist = math.hypot(dx, dy)
            
            src_u = SRC_CX + dx / scale_fg
            src_v = SRC_CY + dy / scale_fg
            
            r, g, b = bilinear_sample(src_w, src_h, src_bpp, src_px, src_u, src_v)
            idx = (y * fg_size + x) * 4
            fg_pixels[idx] = r
            fg_pixels[idx+1] = g
            fg_pixels[idx+2] = b
            fg_pixels[idx+3] = 255 # Full opaque #0A0A0C background floods canvas
            
    fg_path = f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png'
    write_png(fg_path, fg_size, fg_size, fg_pixels)

    # 2. Generate ic_launcher_round.png (Strictly circular with transparent exterior)
    leg_size = sizes['legacy']
    leg_cx = leg_size / 2.0
    leg_cy = leg_size / 2.0
    # Legacy round icon: circle radius is (leg_size / 2.0) - 1.0 (with 1.5px AA feather)
    outer_r = (leg_size / 2.0) - 0.75
    # Inner badge radius: around 76% of outer_r so badge has nice glass border
    target_leg_r = outer_r * 0.76
    scale_leg = target_leg_r / SRC_R
    
    round_pixels = bytearray(leg_size * leg_size * 4)
    for y in range(leg_size):
        for x in range(leg_size):
            dx = (x + 0.5) - leg_cx
            dy = (y + 0.5) - leg_cy
            dist = math.hypot(dx, dy)
            
            idx = (y * leg_size + x) * 4
            if dist > outer_r + 1.0:
                # Fully transparent outside circle
                round_pixels[idx] = 0
                round_pixels[idx+1] = 0
                round_pixels[idx+2] = 0
                round_pixels[idx+3] = 0
            else:
                src_u = SRC_CX + dx / scale_leg
                src_v = SRC_CY + dy / scale_leg
                r, g, b = bilinear_sample(src_w, src_h, src_bpp, src_px, src_u, src_v)
                
                # Anti-alias alpha along outer_r edge
                alpha = 1.0
                if dist > outer_r - 0.75:
                    alpha = max(0.0, min(1.0, (outer_r + 0.75 - dist) / 1.5))
                
                round_pixels[idx] = r
                round_pixels[idx+1] = g
                round_pixels[idx+2] = b
                round_pixels[idx+3] = int(alpha * 255 + 0.5)
                
    round_path = f'android/app/src/main/res/mipmap-{density}/ic_launcher_round.png'
    write_png(round_path, leg_size, leg_size, round_pixels)

    # 3. Generate ic_launcher.png (Rounded squircle icon for square launchers)
    squircle_pixels = bytearray(leg_size * leg_size * 4)
    corner_radius = leg_size * 0.22
    for y in range(leg_size):
        for x in range(leg_size):
            px_x = x + 0.5
            px_y = y + 0.5
            
            # Distance to squircle rounded box
            # Find closest point on squircle inner rect
            inner_left = corner_radius
            inner_right = leg_size - corner_radius
            inner_top = corner_radius
            inner_bottom = leg_size - corner_radius
            
            cx = min(max(px_x, inner_left), inner_right)
            cy = min(max(px_y, inner_top), inner_bottom)
            dist_to_corner_center = math.hypot(px_x - cx, px_y - cy)
            
            idx = (y * leg_size + x) * 4
            if dist_to_corner_center > corner_radius + 1.0:
                squircle_pixels[idx] = 0
                squircle_pixels[idx+1] = 0
                squircle_pixels[idx+2] = 0
                squircle_pixels[idx+3] = 0
            else:
                dx = px_x - leg_cx
                dy = px_y - leg_cy
                src_u = SRC_CX + dx / scale_leg
                src_v = SRC_CY + dy / scale_leg
                r, g, b = bilinear_sample(src_w, src_h, src_bpp, src_px, src_u, src_v)
                
                alpha = 1.0
                if dist_to_corner_center > corner_radius - 0.75:
                    alpha = max(0.0, min(1.0, (corner_radius + 0.75 - dist_to_corner_center) / 1.5))
                    
                squircle_pixels[idx] = r
                squircle_pixels[idx+1] = g
                squircle_pixels[idx+2] = b
                squircle_pixels[idx+3] = int(alpha * 255 + 0.5)
                
    launcher_path = f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    write_png(launcher_path, leg_size, leg_size, squircle_pixels)

print("SUCCESS: All calibrated Pixel ROM adaptive icons generated flawlessly!")
