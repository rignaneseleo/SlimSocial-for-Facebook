"""Checks the screenshot comparison in scroll_smoke.py on synthetic screens.

Run: python3 -m unittest scripts/qa/test_scroll_smoke.py
"""
import os
import sys
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from scroll_smoke import scrolled  # noqa: E402

W, H = 1080, 2400


def page(seed=1, height=6000):
    """A long page with enough texture that every row is different."""
    rng = np.random.default_rng(seed)
    blocks = rng.integers(0, 255, size=(height // 40, W // 60), dtype=np.uint8)
    return np.kron(blocks, np.ones((40, 60), dtype=np.uint8))


def screen(content, top):
    """The phone screen showing `content` scrolled to `top`."""
    shot = np.full((H, W), 240, dtype=np.uint8)
    shot[:200] = 60  # app bar, never scrolls
    shot[200:] = content[top:top + H - 200]
    return Image.fromarray(shot)


class ScrolledTest(unittest.TestCase):
    def test_a_real_scroll_is_seen(self):
        content = page()
        moved, shift, _, _ = scrolled(screen(content, 0), screen(content, 900),
                                      min_shift=150)
        self.assertTrue(moved)
        self.assertAlmostEqual(shift, 900, delta=40)

    def test_a_stuck_page_is_seen(self):
        content = page()
        moved, _, _, _ = scrolled(screen(content, 400), screen(content, 400),
                                  min_shift=150)
        self.assertFalse(moved)

    def test_a_small_nudge_is_not_a_scroll(self):
        content = page()
        moved, _, _, _ = scrolled(screen(content, 400), screen(content, 460),
                                  min_shift=150)
        self.assertFalse(moved)

    def test_a_video_playing_in_place_is_not_a_scroll(self):
        content = page()
        before = screen(content, 400)
        after = np.asarray(before).copy()
        # A video frame in the middle of the screen changes completely.
        rng = np.random.default_rng(7)
        after[900:1500, 100:980] = rng.integers(0, 255, size=(600, 880))
        moved, _, _, _ = scrolled(before, Image.fromarray(after),
                                  min_shift=150)
        self.assertFalse(moved)


if __name__ == "__main__":
    unittest.main()
