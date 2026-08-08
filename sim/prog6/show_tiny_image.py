#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Show tiny_input_image[] from a generated .h file as ANSI grayscale blocks.
#
# Usage:
#   python show_tiny_image.py [header_file]
#
# Default header_file = "test_image.h".
#
# It:
#   - Finds "tiny_input_image[...]" in the header.
#   - Extracts all integer values (0..255).
#   - If the length is a perfect square (e.g., 196), it reshapes as sqrt(N) x sqrt(N).
#   - Prints grayscale blocks in the terminal using ANSI escape codes
#     (0 = black, 255 = white).

import sys
import re
import math


def load_pixels_from_header(path):
    """Parse tiny_input_image[...] from header and return a list of ints (0..255)."""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # Find the block that defines tiny_input_image
    m = re.search(
        r"tiny_input_image\s*\[\s*TINY_MNIST_D\s*\]\s*=\s*\{([^}]*)\}",
        text,
        flags=re.DOTALL
    )
    if not m:
        raise RuntimeError(
            "Cannot find tiny_input_image[...] initializer in {}".format(path)
        )

    block = m.group(1)
    # Extract all integers (0..255)
    nums = re.findall(r"\b\d+\b", block)
    if not nums:
        raise RuntimeError(
            "No integer values found in tiny_input_image in {}".format(path)
        )

    pixels = [int(x) for x in nums]
    return pixels


def guess_size(n):
    """Return side length if n is a perfect square, otherwise None."""
    # math.isqrt exists in Python 3.8+. Some lab environments still use Python 3.6/3.7.
    try:
        s = int(math.isqrt(n))  # type: ignore[attr-defined]
    except AttributeError:
        # For our small n (e.g. 196/784), float sqrt is safe enough.
        s = int(math.sqrt(n))
        while (s + 1) * (s + 1) <= n:
            s += 1
        while s * s > n:
            s -= 1
    if s * s == n:
        return s
    return None


def print_ansi_image(pixels, size=None):
    """
    Print grayscale image using ANSI 24-bit background color.

    pixels: list of ints (0..255), 0 = black, 255 = white.
    """
    n = len(pixels)
    if size is None:
        size = guess_size(n)
    if size is None:
        # Fallback: show as a single row
        size = n

    if size * size != n:
        print(
            "Warning: {} values, cannot form a perfect square, "
            "showing first {}x{}.".format(n, size, size)
        )

    def clamp(v, lo=0, hi=255):
        return lo if v < lo else hi if v > hi else v

    for y in range(size):
        row = pixels[y * size:(y + 1) * size]
        line = []
        for v in row:
            v = clamp(v)
            # ANSI 24-bit background: 48;2;R;G;B
            line.append(f"\033[48;2;{v};{v};{v}m  \033[0m")
        print("".join(line))


def main():
    if len(sys.argv) >= 2:
        header_path = sys.argv[1]
    else:
        header_path = "test_image.h"

    print("Loading:", header_path)
    pixels = load_pixels_from_header(header_path)
    print("Total pixels:", len(pixels))

    size = guess_size(len(pixels))
    if size is not None:
        print("Guessed size: {}x{}".format(size, size))
    else:
        print("Warning: length is not a perfect square, will show as one row.")

    print("Preview (ANSI grayscale blocks):")
    print_ansi_image(pixels, size=size)


if __name__ == "__main__":
    main()
