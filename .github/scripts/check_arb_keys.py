#!/usr/bin/env python3
"""Validate ARB key parity across all locales for each app.

The script scans for */lib/l10n/app_*.arb files and ensures each locale file
within the same app has the exact same non-metadata key set.
"""

from __future__ import annotations

import json
from pathlib import Path


def get_locale_from_filename(path: Path) -> str:
    # app_en.arb -> en, app_pt_BR.arb -> pt_BR
    stem = path.stem
    if not stem.startswith("app_"):
        return stem
    return stem[len("app_") :]


def load_arb(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def non_metadata_keys(data: dict) -> set[str]:
    # ARB metadata keys start with '@' (e.g. @@locale, @someKey)
    return {key for key in data.keys() if not key.startswith("@")}


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    arb_files = sorted(root.glob("*/lib/l10n/app_*.arb"))

    if not arb_files:
        print("No ARB files found. Nothing to validate.")
        return 0

    grouped: dict[Path, list[Path]] = {}
    for arb in arb_files:
        grouped.setdefault(arb.parent, []).append(arb)

    has_error = False

    for l10n_dir, files in sorted(grouped.items()):
        app_root = l10n_dir.parents[1]
        app_name = app_root.name

        key_sets: dict[Path, set[str]] = {}
        parse_errors: list[tuple[Path, str]] = []

        for file_path in sorted(files):
            try:
                data = load_arb(file_path)
                if not isinstance(data, dict):
                    raise ValueError("ARB root must be a JSON object")
                key_sets[file_path] = non_metadata_keys(data)
            except Exception as exc:  # noqa: BLE001
                parse_errors.append((file_path, str(exc)))

        if parse_errors:
            has_error = True
            print(f"\n[{app_name}] Failed to parse ARB file(s):")
            for file_path, message in parse_errors:
                print(f"  - {file_path.relative_to(root)}: {message}")
            continue

        all_keys = set().union(*key_sets.values()) if key_sets else set()

        if len(files) < 2:
            locales = ", ".join(get_locale_from_filename(f) for f in files)
            print(
                f"\n[{app_name}] Only one locale file found ({locales}). "
                "Parity check skipped."
            )
            continue

        app_has_error = False
        for file_path, keys in sorted(key_sets.items()):
            missing = sorted(all_keys - keys)
            if missing:
                app_has_error = True
                has_error = True
                locale = get_locale_from_filename(file_path)
                print(
                    f"\n[{app_name}] Locale '{locale}' is missing "
                    f"{len(missing)} key(s) in {file_path.relative_to(root)}:"
                )
                for key in missing:
                    print(f"  - {key}")

        if not app_has_error:
            locales = ", ".join(
                get_locale_from_filename(file_path) for file_path in sorted(files)
            )
            print(f"[{app_name}] OK: all locale files have matching keys ({locales}).")

    if has_error:
        print("\nLocalization key parity check failed.")
        return 1

    print("\nLocalization key parity check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
