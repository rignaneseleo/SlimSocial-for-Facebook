#!/usr/bin/env python3
"""One-finger feed scroll smoke test, run on a real device over adb.

Sends real one-finger swipes with `adb input swipe` (the Android touch
pipeline, like a user's finger) and checks from screenshots that the page
content moved up. It reads pixels, not the DOM, so it works on release builds
(no debuggable WebView needed) and on any layout Facebook serves.

A swipe passes when the screenshot after it matches the one before it shifted
up by at least --min-shift pixels. A playing video changes pixels without a
shift, so it does not count as a scroll.

Run it on every change to a user agent string or to injected CSS/JS, and on
every release candidate, on a phone signed in to Facebook. See
.github/PULL_REQUEST_TEMPLATE.md.

Usage:
  scripts/qa/scroll_smoke.py -s <adb serial>
  scripts/qa/scroll_smoke.py -s <serial> --package it.rignanese.leo.slimfacebook.debug
  scripts/qa/scroll_smoke.py -s <serial> --no-launch   # test what is on screen

Exit code 0 = scroll works, 1 = scroll is stuck, 2 = could not run.
Needs adb, Pillow and numpy.
"""
import argparse
import io
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image

# Screenshots are shrunk to this width before comparing: fast, and it ignores
# sub-pixel noise from font rendering.
COMPARE_WIDTH = 96


def adb(serial, *args, binary=False):
    out = subprocess.run(["adb", "-s", serial, *args], capture_output=True,
                         timeout=60)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.decode(errors="replace").strip()
                           or f"adb {' '.join(args)} failed")
    return out.stdout if binary else out.stdout.decode(errors="replace")


def screenshot(serial):
    png = adb(serial, "exec-out", "screencap", "-p", binary=True)
    return Image.open(io.BytesIO(png)).convert("L")


def content_band(image):
    """The part of the screen the page scrolls in, as a float array.

    Drops the status bar and app bar at the top and the navigation bar at the
    bottom, which never scroll, and the side edges, where scroll bars draw.
    """
    w, h = image.size
    band = image.crop((int(w * 0.1), int(h * 0.15), int(w * 0.9),
                       int(h * 0.88)))
    scale = COMPARE_WIDTH / band.size[0]
    band = band.resize((COMPARE_WIDTH, max(1, int(band.size[1] * scale))))
    return np.asarray(band, dtype=np.float32), scale


def vertical_shift(before, after, scale):
    """How far the content moved up between two screenshots, in screen pixels.

    Returns (shift, still_error, shift_error). `still_error` is the mean pixel
    difference with no shift; `shift_error` the difference at the best shift.
    """
    rows = before.shape[0]
    min_overlap = max(8, rows // 5)
    still = float(np.mean(np.abs(before - after)))
    best_d, best_err = 0, still
    for d in range(1, rows - min_overlap):
        err = float(np.mean(np.abs(before[d:] - after[:rows - d])))
        if err < best_err:
            best_d, best_err = d, err
    return int(round(best_d / scale)), still, best_err


def scrolled(before_img, after_img, min_shift):
    before, scale = content_band(before_img)
    after, _ = content_band(after_img)
    shift, still, err = vertical_shift(before, after, scale)
    # The shift must explain the change clearly better than "nothing moved",
    # or a video playing in place would look like a scroll.
    moved = shift >= min_shift and err < still * 0.8
    return moved, shift, still, err


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("-s", "--serial", default=os.environ.get("ANDROID_SERIAL"),
                    help="adb serial (default: $ANDROID_SERIAL)")
    ap.add_argument("--package", default="it.rignanese.leo.slimfacebook")
    ap.add_argument("--no-launch", action="store_true",
                    help="do not restart the app; test the current screen")
    ap.add_argument("--wait", type=float, default=20,
                    help="seconds to let the feed load after launch")
    ap.add_argument("--swipes", type=int, default=5)
    ap.add_argument("--min-shift", type=int, default=150,
                    help="screen pixels a swipe must move the content")
    ap.add_argument("--out", help="save the screenshots to this directory")
    args = ap.parse_args()
    if not args.serial:
        ap.error("pass -s <serial> or set ANDROID_SERIAL")

    try:
        if not args.no_launch:
            adb(args.serial, "shell", "am", "force-stop", args.package)
            adb(args.serial, "shell", "monkey", "-p", args.package, "-c",
                "android.intent.category.LAUNCHER", "1")
            time.sleep(args.wait)
        w, h = screenshot(args.serial).size
        x = w // 2
        start_y, end_y = int(h * 0.70), int(h * 0.40)

        passed = 0
        before = screenshot(args.serial)
        if args.out:
            os.makedirs(args.out, exist_ok=True)
            before.save(os.path.join(args.out, "swipe0.png"))
        for i in range(1, args.swipes + 1):
            # One finger, 800 ms: a slow drag, so the page does not fling far.
            adb(args.serial, "shell", "input", "swipe", str(x), str(start_y),
                str(x), str(end_y), "800")
            time.sleep(1.5)
            after = screenshot(args.serial)
            if args.out:
                after.save(os.path.join(args.out, f"swipe{i}.png"))
            moved, shift, still, err = scrolled(before, after, args.min_shift)
            passed += moved
            print(f"swipe {i}: {'moved' if moved else 'STUCK'} "
                  f"shift={shift}px diff={still:.1f}->{err:.1f}")
            before = after
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as err:
        print(f"scroll smoke: could not run: {err}", file=sys.stderr)
        return 2

    # One miss is allowed: the end of a short page, or a swipe that landed on
    # a horizontal carousel.
    ok = passed >= args.swipes - 1
    print(f"scroll smoke: {'PASS' if ok else 'FAIL'} "
          f"({passed}/{args.swipes} swipes scrolled the page)")
    if not ok:
        # A short page (login, checkpoint) and a stuck feed look the same in
        # pixels, so a person has to look once.
        where = f" in {args.out}" if args.out else " (pass --out to save them)"
        print("Look at the screenshots" + where + ". If they show a login or "
              "checkpoint page instead of the feed, sign in and run again.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
