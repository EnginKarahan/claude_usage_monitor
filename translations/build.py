#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
"""
Compile .po sources in translations/ into binary .mo files inside
plasmoid/contents/locale/<lang>/LC_MESSAGES/.

Uses python-babel (no system gettext required). If you don't have babel:
    pip install --user babel
or on Fedora:
    sudo dnf install python3-babel
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from babel.messages.mofile import write_mo
    from babel.messages.pofile import read_po
except ImportError:
    sys.exit(
        "python-babel is required.\n"
        "  Fedora:   sudo dnf install python3-babel\n"
        "  pip:      pip install --user babel"
    )

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
LOCALE_DIR = ROOT / "plasmoid" / "contents" / "locale"
DOMAIN = "plasma_applet_com.karahan.claudewidget"


def compile_one(po_path: Path) -> Path:
    lang = po_path.stem
    out_dir = LOCALE_DIR / lang / "LC_MESSAGES"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"{DOMAIN}.mo"
    with po_path.open("rb") as f:
        catalog = read_po(f, locale=lang)
    with out_file.open("wb") as f:
        write_mo(f, catalog)
    return out_file


def main() -> int:
    pos = sorted(HERE.glob("*.po"))
    if not pos:
        print("No .po files found in translations/", file=sys.stderr)
        return 1
    for po in pos:
        out = compile_one(po)
        # Show path relative to repo root for cleaner output.
        try:
            rel = out.relative_to(ROOT)
        except ValueError:
            rel = out
        print(f"  {po.name:<10} → {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
