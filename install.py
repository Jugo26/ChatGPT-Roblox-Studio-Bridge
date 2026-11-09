"""Build and optionally install the Roblox Studio plugin with a per-installation token."""
from __future__ import annotations

import argparse
import os
import secrets
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent
TEMPLATE = ROOT / "plugin.template.lua"
TOKEN_PATH = ROOT / "token.txt"
TOKEN_MARKER = "__BRIDGE_TOKEN__"


def load_token() -> str:
    if TOKEN_PATH.exists():
        token = TOKEN_PATH.read_text(encoding="utf-8").strip()
        if len(token) != 64 or any(ch not in "0123456789abcdef" for ch in token):
            raise ValueError("token.txt invalid: expected 64 lowercase hex characters")
        return token
    token = secrets.token_hex(32)
    TOKEN_PATH.write_text(token + "\n", encoding="utf-8")
    if os.name != "nt":
        TOKEN_PATH.chmod(0o600)
    return token


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    parser.add_argument("--no-install", action="store_true")
    args = parser.parse_args()

    template = TEMPLATE.read_text(encoding="utf-8")
    if template.count(TOKEN_MARKER) != 1:
        raise ValueError("The public Lua template must contain exactly one token marker")

    source = template.replace(TOKEN_MARKER, load_token())
    xml = f'''<roblox version="4">
<External>null</External>
<External>nil</External>
<Item class="Script" referent="RBX0">
<Properties>
<bool name="Disabled">false</bool>
<string name="Name">ChatGPT Studio Bridge</string>
<ProtectedString name="Source">{escape(source)}</ProtectedString>
</Properties>
</Item>
</roblox>
'''
    target = args.output or ROOT / "ChatGPT_Studio_Bridge.rbxmx"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(xml, encoding="utf-8")
    print("Generated:", target)

    if not args.no_install:
        localappdata = os.environ.get("LOCALAPPDATA")
        if localappdata:
            destination = Path(localappdata) / "Roblox" / "Plugins" / target.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(xml, encoding="utf-8")
            print("Installed:", destination)
        else:
            print("LOCALAPPDATA unavailable; install generated .rbxmx in Roblox Studio manually")


if __name__ == "__main__":
    main()
