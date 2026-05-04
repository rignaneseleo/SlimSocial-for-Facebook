#!/usr/bin/env python3
"""Convert Flutter `assets/lang/<locale>.json` files into Android string
resources (`app/src/main/res/values{,-<locale>}/strings.xml`).

Phase 11 of the Kotlin rewrite — see
`docs/superpowers/specs/2026-05-03-kotlin-rewrite-plan.md`.

Behaviours:
- en-US is canonical and additionally written to `values/strings.xml`.
- Legacy keys with spaces / punctuation are normalised to a snake_case
  Android resource id; the original→normalised mapping is dumped to
  `scripts/strings_mapping.json` so the Compose code can stay in sync.
- Empty values are skipped (Android falls back to the default locale).
- Only en-US extra keys are added (Kotlin port additions); other locales
  are converted as-is.

Run from the repo root:

    python3 scripts/convert_lang.py
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LANG_DIR = REPO_ROOT / "SlimSocial_for_Facebook" / "assets" / "lang"
RES_DIR = REPO_ROOT / "app" / "src" / "main" / "res"
MAPPING_OUT = REPO_ROOT / "scripts" / "strings_mapping.json"

# Locales to skip (template / non-locale files).
SKIP_FILES = {"_.json"}

# Strings introduced by the Kotlin port that have no JSON equivalent.
# These get added to values/strings.xml only (English-only for now).
EXTRA_EN_STRINGS: dict[str, str] = {
    # --- Existing app_name retained ---
    "app_name": "SlimSocial for Facebook",
    # --- Generic ---
    "back": "Back",
    "reload": "Reload",
    "facebook_stopped_responding": "Facebook stopped responding",
    # --- JS warning ---
    "js_warning_title": "JavaScript runs in your Facebook session",
    "js_warning_body": (
        "Custom JavaScript runs with full access to your Facebook session — "
        "including your feed, messages, and session cookies. "
        "Only paste code from sources you trust."
    ),
    "js_warning_strip": (
        "JavaScript runs with full Facebook session DOM access. "
        "Only paste code from sources you trust."
    ),
    "i_understand": "I understand",
    # --- Permission row tri-state ---
    "permission_state_off": "Off",
    "permission_state_on": "On",
    "permission_state_denied_by_os_tap_to_fix": "On (denied by OS — tap to fix)",
    "open_system_settings": "Open system settings",
    "gps_permission_desc": "Allow Facebook to access your location",
    "camera_permission_desc": "Allow Facebook to access the camera",
    "gallery_permission_desc": "Allow Facebook to read photos from your gallery",
    "photos_permission_legacy": "Photos permission (legacy alias)",
    "photos_permission_legacy_desc": (
        "Legacy duplicate of the gallery permission used by older flows"
    ),
    # --- Section headers (Kotlin port) ---
    "section_facebook": "Facebook",
    "section_style": "Style",
    "section_permissions": "Permissions",
    "section_advanced": "Advanced",
    "section_privacy": "Privacy",
    "section_debug": "Debug",
    "section_about": "About",
    # --- Style toggles introduced by the Kotlin port ---
    "hide_messenger_sidebar": "Hide Messenger sidebar",
    "dark_theme_messenger": "Dark theme for Messenger",
    "remove_messenger_download": "Remove Messenger download prompt",
    "remove_browser_not_supported": "Remove \"browser not supported\" notice",
    "hide_ads_and_pymk": "Hide ads and \"People You May Know\"",
    "fab_btn": "Floating action button",
    "adapt_messenger": "Adapt Messenger layout",
    # --- Advanced extras ---
    "send_to_dev_desc_v2": (
        "If the code is safe and useful, it will be included in the next release"
    ),
    # --- Privacy ---
    "send_anonymous_crash_reports": "Send anonymous crash reports (Sentry)",
    "send_anonymous_crash_reports_desc": (
        "No personal or device information is ever collected"
    ),
    "debug_mode": "Debug mode",
    "debug_mode_desc": "Show extra logging in the log viewer",
    # --- Debug / log viewer ---
    "log_viewer": "Log viewer",
    "log_viewer_desc": "View recent navigation, console, and rule events",
    "reproduce_mode": "Reproduce mode",
    "reproduce_mode_desc": "Records extra detail to help reproduce bugs.",
    "state_snapshot": "State snapshot",
    "state_snapshot_webview": "WebView",
    "state_snapshot_url": "URL",
    "state_snapshot_user_agent": "UA",
    "state_snapshot_active_rules": "Active rules",
    "state_snapshot_active_css": "Active CSS",
    "state_snapshot_active_js": "Active JS",
    "state_snapshot_proxy": "Proxy",
    "state_snapshot_permissions": "Permissions",
    "state_snapshot_none": "none",
    "state_snapshot_url_none": "(none)",
    "state_snapshot_proxy_off": "off",
    "log_pause_button": "Pause",
    "log_resume_button": "Resume",
    "log_clear_button": "Clear",
    "log_export_button": "Export",
    "log_send_to_dev_button": "Send to dev",
    "log_export_chooser": "Export log",
    "log_empty_filter": "No log events match the current filter.",
    "log_send_subject": "SlimSocial debug log v%1$s",
    # --- About ---
    "about": "About",
    "about_app_name": "SlimSocial for Facebook",
    "about_version": "Version %1$s",
    "source_code_subtitle": "GitHub repository",
    "license_gpl3": "License (GPL-3.0)",
    "changelog": "Changelog",
    "donate_become_hero": "Donate / Become a hero",
    "about_slimsocial": "About SlimSocial",
    # --- Editor ---
    "editor_test_button": "Test",
    "editor_save_button": "Save",
    "editor_cancel_button": "Cancel",
    "editor_apply_button": "Apply",
    "editor_name_label": "Name",
    "editor_unnamed": "(unnamed)",
    "editor_untitled": "Untitled",
    "editor_new_snippet": "New snippet",
    "editor_edit": "Edit",
    "editor_delete_snippet_title": "Delete snippet?",
    "editor_delete_snippet_message": "This will remove \"%1$s\" permanently.",
    "editor_no_snippets_yet": "No %1$s snippets yet. Tap + to add one.",
    "editor_noun_css": "CSS",
    "editor_noun_js": "JavaScript",
    "editor_title_custom_css": "Custom CSS",
    "editor_title_custom_js": "Custom JS",
    "editor_title_new_css": "New CSS snippet",
    "editor_title_new_js": "New JS snippet",
    "editor_title_edit_css": "Edit CSS snippet",
    "editor_title_edit_js": "Edit JS snippet",
    # --- Proxy ---
    "proxy_enable": "Enable proxy",
    "proxy_host_label": "Host",
    "proxy_port_label": "Port",
    "proxy_port_invalid": "Port must be between 1 and 65535",
    # --- User agent ---
    "user_agent_title": "Custom user agent",
    "user_agent_label": "User agent",
    "user_agent_hint": "Leave empty to use the default user agent.",
    # --- Settings extras ---
    "send_to_dev_subject": "SlimSocial custom code submission",
}


# ---------------------------------------------------------------------------
# Key normalisation
# ---------------------------------------------------------------------------

_BAD_CHAR = re.compile(r"[^a-z0-9]+")


def normalize_key(raw: str) -> str:
    """Convert an arbitrary JSON key into a valid Android resource id."""
    lowered = raw.lower()
    # Replace `{}` placeholders before non-alnum stripping so they don't
    # contribute to the id.
    lowered = lowered.replace("{}", "")
    cleaned = _BAD_CHAR.sub("_", lowered)
    cleaned = cleaned.strip("_")
    if not cleaned:
        cleaned = "key"
    if cleaned[0].isdigit():
        cleaned = "_" + cleaned
    return cleaned


# ---------------------------------------------------------------------------
# Locale code → Android folder name
# ---------------------------------------------------------------------------


def android_folder(locale_code: str) -> str:
    """`it-IT` → `values-it-rIT`, bare `it` → `values-it`."""
    if "-" in locale_code:
        lang, region = locale_code.split("-", 1)
        return f"values-{lang}-r{region}"
    return f"values-{locale_code}"


# ---------------------------------------------------------------------------
# XML escaping
# ---------------------------------------------------------------------------

_PRINTF_RE = re.compile(r"%([0-9]+\$)?[\-+ #0]?[0-9]*(\.[0-9]+)?[sdifeEgGxXoc%]")


def escape_value(value: str) -> str:
    """Escape a JSON string value for inclusion in Android strings.xml.

    Handles:
      - XML entities (&, <, >)
      - Android single-string quirks (apostrophes, quotes, ?)
      - {} placeholders → %1$s (keeping it as a printf format specifier)
      - %% for stray percent signs not part of a format specifier
      - Newline → literal `\\n` in XML (Android renders it)
      - Wraps in double-quotes when value has leading/trailing whitespace
    """

    # Convert legacy {}-style placeholders (used in Flutter's intl package) into
    # printf positional format specifiers so callers can use String.format /
    # Resources.getString(int, args).
    placeholder_index = 0

    def _repl_brace(match: re.Match[str]) -> str:  # noqa: ARG001
        nonlocal placeholder_index
        placeholder_index += 1
        return f"%{placeholder_index}$s"

    value = re.sub(r"\{\}", _repl_brace, value)

    # Escape lone `%` not part of a format specifier.
    out_parts: list[str] = []
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == "%":
            m = _PRINTF_RE.match(value, i)
            if m:
                out_parts.append(m.group(0))
                i = m.end()
                continue
            out_parts.append("%%")
            i += 1
            continue
        out_parts.append(ch)
        i += 1
    value = "".join(out_parts)

    # XML entity escaping (do `&` first!).
    value = value.replace("&", "&amp;")
    value = value.replace("<", "&lt;")
    value = value.replace(">", "&gt;")

    # Newline → literal backslash-n; Android string resource decoder turns it
    # back into a real newline at runtime.
    value = value.replace("\r\n", "\n").replace("\n", "\\n")

    # Apostrophes and double quotes need escaping inside Android string values
    # unless the whole string is already wrapped in double quotes.
    has_leading_trailing_ws = value != value.strip()
    if has_leading_trailing_ws:
        # Wrap in double quotes; inside the wrapper we still need to escape
        # double-quote characters but apostrophes are safe.
        value_inner = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{value_inner}"'

    value = value.replace("'", "\\'")
    value = value.replace('"', "\\\"")

    # Android resource quirk: unescaped trailing `?` is allowed but some
    # tools have flagged it historically. Leave it as-is — none of the
    # current strings rely on the special form.
    return value


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------


def write_strings_xml(target_dir: Path, entries: list[tuple[str, str]]) -> None:
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / "strings.xml"
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    for key, value in entries:
        lines.append(f'    <string name="{key}">{value}</string>')
    lines.append("</resources>")
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def _attempt_repair(text: str) -> str:
    """Best-effort fix for the most common typo we see in legacy locale
    files: a missing comma between two key/value entries (e.g. ru-RU.json
    had `"enabled": "...":<newline>"proxy_is_active":`). Inserts a comma at
    the end of any line where the next non-blank line starts a new JSON
    string entry."""
    lines = text.splitlines()
    fixed: list[str] = []
    string_start = re.compile(r'^\s*"[^"\\]*"\s*:')
    for i, line in enumerate(lines):
        stripped = line.rstrip()
        # If the previous line we emitted ends a value (closing quote, no
        # trailing comma / open brace) and the current line starts a new
        # `"key":` pair, append a trailing comma to the previous line.
        if (
            fixed
            and string_start.match(line)
            and fixed[-1].rstrip().endswith('"')
        ):
            fixed[-1] = fixed[-1].rstrip() + ","
        fixed.append(stripped)
    return "\n".join(fixed) + ("\n" if text.endswith("\n") else "")


def load_locale(path: Path) -> dict[str, str] | None:
    text = path.read_text(encoding="utf-8")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        repaired = _attempt_repair(text)
        try:
            data = json.loads(repaired)
            print(f"  NOTE: repaired malformed JSON in {path.name}", file=sys.stderr)
            return data
        except json.JSONDecodeError as exc:
            print(f"  WARN: skipping {path.name}: invalid JSON ({exc})", file=sys.stderr)
            return None


def main() -> int:
    if not LANG_DIR.is_dir():
        print(f"ERROR: {LANG_DIR} does not exist", file=sys.stderr)
        return 1

    files = sorted(p for p in LANG_DIR.iterdir() if p.suffix == ".json" and p.name not in SKIP_FILES)
    if not files:
        print(f"ERROR: no JSON files found in {LANG_DIR}", file=sys.stderr)
        return 1

    # Build the canonical key→android-id mapping from en-US.json so it's
    # stable regardless of which locale we process first.
    en_path = LANG_DIR / "en-US.json"
    if not en_path.is_file():
        print(f"ERROR: missing canonical {en_path}", file=sys.stderr)
        return 1
    en_data = load_locale(en_path) or {}
    mapping: dict[str, str] = {}
    seen_ids: set[str] = set()
    for raw_key in en_data.keys():
        android_id = normalize_key(raw_key)
        # If two original keys map to the same id, suffix to keep both.
        base = android_id
        i = 2
        while android_id in seen_ids:
            android_id = f"{base}_{i}"
            i += 1
        seen_ids.add(android_id)
        mapping[raw_key] = android_id

    # Also reserve the manually added Kotlin-port keys.
    for k in EXTRA_EN_STRINGS.keys():
        seen_ids.add(k)

    # Persist mapping for the Compose code generator / humans.
    MAPPING_OUT.write_text(
        json.dumps(mapping, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    locales_written: list[str] = []
    skipped: list[str] = []

    # values/strings.xml — English fallback. Combine en-US.json + extras.
    fallback_entries: list[tuple[str, str]] = []
    for raw_key, value in en_data.items():
        if not isinstance(value, str) or value == "":
            continue
        fallback_entries.append((mapping[raw_key], escape_value(value)))
    for k, v in EXTRA_EN_STRINGS.items():
        fallback_entries.append((k, escape_value(v)))
    # Dedupe by key — last write wins, so EXTRA_EN_STRINGS overrides where it
    # collides intentionally (e.g. app_name).
    dedup: dict[str, str] = {}
    for k, v in fallback_entries:
        dedup[k] = v
    write_strings_xml(RES_DIR / "values", sorted(dedup.items()))

    for path in files:
        locale = path.stem  # e.g. en-US
        data = load_locale(path)
        if data is None:
            skipped.append(locale)
            continue
        entries: dict[str, str] = {}
        for raw_key, value in data.items():
            if not isinstance(value, str) or value == "":
                continue
            android_id = mapping.get(raw_key)
            if android_id is None:
                # Keys present in non-en-US files but missing from en-US;
                # synthesise an id and add to the running mapping.
                candidate = normalize_key(raw_key)
                base = candidate
                i = 2
                while candidate in seen_ids:
                    candidate = f"{base}_{i}"
                    i += 1
                seen_ids.add(candidate)
                mapping[raw_key] = candidate
                android_id = candidate
            entries[android_id] = escape_value(value)
        folder = RES_DIR / android_folder(locale)
        write_strings_xml(folder, sorted(entries.items()))
        locales_written.append(locale)

    # Re-write mapping in case extra keys were synthesised mid-pass.
    MAPPING_OUT.write_text(
        json.dumps(mapping, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"Wrote values/strings.xml ({len(dedup)} keys)")
    print(f"Wrote {len(locales_written)} locale folders:")
    for loc in locales_written:
        print(f"  - {loc} → values-{android_folder(loc).split('-', 1)[1] if '-' in android_folder(loc) else android_folder(loc)}")
    if skipped:
        print(f"Skipped {len(skipped)} locales: {skipped}")
    print(f"Mapping → {MAPPING_OUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
