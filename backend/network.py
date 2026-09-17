"""Runtime network identity used by the operator console and clients."""

from __future__ import annotations

import ipaddress
import socket
import subprocess
from typing import Any

from config import settings


def _usable_ipv4(value: str) -> bool:
    try:
        address = ipaddress.ip_address(value)
        return address.version == 4 and address.is_private and not address.is_loopback and not address.is_link_local
    except ValueError:
        return False


def lan_addresses() -> list[str]:
    found: set[str] = set()
    try:
        result = subprocess.run(["ip", "-o", "-4", "addr", "show", "up"], capture_output=True, text=True, timeout=1, check=False)
        for line in result.stdout.splitlines():
            parts = line.split()
            ifname = parts[1] if len(parts) > 1 else ""
            if ifname == "lo" or any(token in ifname.lower() for token in ("docker", "veth", "virbr", "vmnet")):
                continue
            for index, part in enumerate(parts):
                if part == "inet" and index + 1 < len(parts):
                    address = parts[index + 1].split("/", 1)[0]
                    if _usable_ipv4(address):
                        found.add(address)
    except (OSError, subprocess.SubprocessError):
        pass
    if not found:
        try:
            for address in socket.gethostbyname_ex(socket.gethostname())[2]:
                if _usable_ipv4(address):
                    found.add(address)
        except OSError:
            pass
    return sorted(found)


def network_info() -> dict[str, Any]:
    localhost = f"http://127.0.0.1:{settings.PORT}"
    lans = [f"http://{address}:{settings.PORT}" for address in lan_addresses()]
    return {
        "bind_host": settings.HOST,
        "port": settings.PORT,
        "localhost_url": localhost,
        "lan_urls": lans,
        "websocket_urls": [url.replace("http://", "ws://").replace("https://", "wss://") + "/ws" for url in lans],
        "client_presets": {
            "android_emulator": f"http://10.0.2.2:{settings.PORT}",
            "ios_simulator": localhost,
            "web": localhost,
            "physical_device": lans[0] if lans else None,
        },
    }
