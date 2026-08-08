#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Convert input.bmp into test_image.h for tiny_mnist.
# Fixed filenames:
#   Model header : tiny_mnist_model.h
#   Input BMP    : input.bmp
#   Output header: test_image.h


import sys
import struct
import re
import math

MODEL_HEADER = "tiny_mnist_model.h"
IN_BMP       = "input.bmp"
OUT_HEADER   = "test_image.h"

# Kept for compatibility with older code; no longer used in computation.
BIN_THRESHOLD = 128
FG_THRESHOLD  = 16

# New options:
#   - If your digits are "dark stroke on bright background",
#     set INVERT_FOR_DARK_STROKE = True so that stroke becomes large value.
#   - POOL_MODE:
#       "avg": keep old behavior (average pooling)
#       "min": use min pooling (stronger stroke, prevents thin lines being washed out)
INVERT_FOR_DARK_STROKE = True
POOL_MODE              = "min"   # "min" or "avg"


# ===== BMP load & grayscale =====

def load_bmp_24bpp_grayscale(path):
    """
    Load a 24bpp BMP file and return (width, height, gray_list).

    gray_list is a Python list of length width*height, each value in [0,255].
    Only uses the Python standard library.
    """
    with open(path, "rb") as f:
        data = f.read()

    if len(data) < 54 or data[0:2] != b"BM":
        raise ValueError("Not a valid BMP file (missing 'BM').")

    # BITMAPFILEHEADER
    file_size   = struct.unpack_from("<I", data, 2)[0]
    bf_off_bits = struct.unpack_from("<I", data, 10)[0]

    # BITMAPINFOHEADER (assume 40 bytes)
    bi_size = struct.unpack_from("<I", data, 14)[0]
    if bi_size != 40:
        raise ValueError("Only BITMAPINFOHEADER (40-byte) BMPs are supported.")

    width, height, planes, bpp = struct.unpack_from("<iiHH", data, 18)
    compression = struct.unpack_from("<I", data, 30)[0]

    if planes != 1:
        raise ValueError("Unsupported BMP planes != 1")
    if bpp != 24:
        raise ValueError(f"Expected 24bpp BMP, got {bpp} bpp.")
    if compression != 0:
        raise ValueError("Compressed BMP is not supported.")

    bottom_up = True
    if height < 0:
        bottom_up = False
        height = -height

    row_bytes = ((width * 3 + 3) // 4) * 4  # each row padded to multiple of 4 bytes
    if bf_off_bits + row_bytes * height > len(data):
        raise ValueError("BMP data is truncated or invalid.")

    gray = [0] * (width * height)
    for y in range(height):
        if bottom_up:
            dst_y = height - 1 - y
        else:
            dst_y = y
        row_start = bf_off_bits + y * row_bytes
        for x in range(width):
            offset = row_start + x * 3
            B = data[offset + 0]
            G = data[offset + 1]
            R = data[offset + 2]
            # Grayscale: approximate 0.3R + 0.59G + 0.11B (integer form).
            val = (30 * R + 59 * G + 11 * B) // 100
            gray[dst_y * width + x] = val

    return width, height, gray


# ===== Downsample to tiny_mnist resolution =====

def downsample_to_binary(width, height, gray, out_size,
                         bin_threshold=None, fg_threshold=None,
                         invert_for_dark_stroke=INVERT_FOR_DARK_STROKE,
                         pool_mode=POOL_MODE):
    """
    Downsample a grayscale image to (out_size x out_size).

    - pool_mode == "avg":
         use average pooling (old behavior). Dark strokes will be diluted
         if they occupy only a small region of the patch.
    - pool_mode == "min":
         use min pooling: if there is any dark pixel (stroke) in the patch,
         the pooled value will be close to that dark value, preserving strokes.

    - invert_for_dark_stroke == True:
         assumes original image is "dark stroke on bright background".
         Pooled value v (0..255) will be transformed as (255 - v) so that
         stroke becomes a large value, background becomes a small value.

    Returns a list of length out_size * out_size, each value in [0,255].
    """
    if out_size <= 0:
        raise ValueError("out_size must be positive.")

    if pool_mode not in ("avg", "min"):
        raise ValueError("pool_mode must be 'avg' or 'min'.")

    out = []
    for oy in range(out_size):
        # integer-range block in source image
        y0 = oy * height // out_size
        y1 = (oy + 1) * height // out_size
        if y1 <= y0:
            y1 = y0 + 1
        for ox in range(out_size):
            x0 = ox * width // out_size
            x1 = (ox + 1) * width // out_size
            if x1 <= x0:
                x1 = x0 + 1

            s = 0
            cnt = 0
            patch_min = 255
            for yy in range(y0, y1):
                base = yy * width
                for xx in range(x0, x1):
                    v = gray[base + xx]
                    s += v
                    cnt += 1
                    if v < patch_min:
                        patch_min = v

            if cnt == 0:
                pooled = 0
            else:
                if pool_mode == "avg":
                    pooled = s // cnt       # integer average 0..255
                else:  # "min"
                    pooled = patch_min     # emphasize darkest pixel (stroke)

            if invert_for_dark_stroke:
                pooled = 255 - pooled

            # clamp just in case
            if pooled < 0:
                pooled = 0
            elif pooled > 255:
                pooled = 255

            out.append(pooled)

    return out


# ===== Parse model header =====

def read_model_dim(path):
    """
    Try to read TINY_MNIST_D and TINY_MNIST_IMG_SIZE from tiny_mnist_model.h.
    Returns (dim, img_size). img_size may be None if not found.
    """
    dim = None
    img_size = None
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                m = re.search(r"\bTINY_MNIST_D\s+(\d+)", line)
                if m:
                    dim = int(m.group(1))
                m2 = re.search(r"\bTINY_MNIST_IMG_SIZE\s+(\d+)", line)
                if m2:
                    img_size = int(m2.group(1))
    except FileNotFoundError:
        return None, None
    return dim, img_size


# ===== Write C header =====

def write_test_header(path, pixels):
    """
    Write test_image.h compatible with tiny_mnist_model.h.

    Layout:
        #pragma once
        #include <stdint.h>
        #include "tiny_mnist_model.h"

        static const uint8_t tiny_input_image[TINY_MNIST_D] = { ... };
    """
    dim = len(pixels)
    with open(path, "w", encoding="utf-8") as f:
        f.write("#pragma once\n")
        f.write("#include <stdint.h>\n")
        f.write("#include \"tiny_mnist_model.h\"\n\n")
        f.write("static const uint8_t tiny_input_image[TINY_MNIST_D] = {\n")

        # Write 16 values per line for readability
        for i, v in enumerate(pixels):
            if i % 16 == 0:
                f.write("    ")
            f.write(str(int(v)))
            if i != dim - 1:
                f.write(", ")
            if (i + 1) % 16 == 0:
                f.write("\n")

        if dim % 16 != 0:
            f.write("\n")
        f.write("};\n")


# ===== Main =====

def main():
    dim, img_size = read_model_dim(MODEL_HEADER)
    if dim is None:
        print(f"Warning: cannot find TINY_MNIST_D in {MODEL_HEADER}.", file=sys.stderr)
    if img_size is None and dim is not None:
        img_size = int(math.isqrt(dim))
        if img_size * img_size != dim:
            print("Warning: TINY_MNIST_D is not a perfect square, defaulting img_size=14.",
                  file=sys.stderr)
            img_size = 14
    if img_size is None:
        img_size = 14  # fallback

    print(f"Model dim = {dim}, img_size = {img_size}")
    print(f"POOL_MODE = {POOL_MODE}, INVERT_FOR_DARK_STROKE = {INVERT_FOR_DARK_STROKE}")

    print("Loading BMP:", IN_BMP)
    w, h, gray = load_bmp_24bpp_grayscale(IN_BMP)
    print(f"BMP size: {w}x{h}")

    pixels = downsample_to_binary(
        w, h, gray,
        img_size,
        bin_threshold=BIN_THRESHOLD,
        fg_threshold=FG_THRESHOLD,
        invert_for_dark_stroke=INVERT_FOR_DARK_STROKE,
        pool_mode=POOL_MODE,
    )

    if dim is not None and len(pixels) != dim:
        print(f"Warning: downsampled size {len(pixels)} != TINY_MNIST_D {dim}", file=sys.stderr)

    print("Writing header:", OUT_HEADER)
    write_test_header(OUT_HEADER, pixels)


if __name__ == "__main__":
    main()
