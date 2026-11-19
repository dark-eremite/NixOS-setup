#!/usr/bin/env python3
"""Record desktop notifications to a JSONL file for Quickshell's history panel."""

import asyncio
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

from dbus_fast import Message, MessageType, Variant
from dbus_fast.aio import MessageBus

MAX_ENTRIES = 500

cache_home = os.environ.get("XDG_CACHE_HOME")
if not cache_home:
    cache_home = str(Path.home() / ".cache")

CACHE_DIR = Path(cache_home) / "quickshell"
HISTORY_FILE = CACHE_DIR / "notifications.jsonl"
STATE_FILE = CACHE_DIR / "notifications-enabled"


def ensure_files() -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if not STATE_FILE.exists():
        STATE_FILE.write_text("1\n", encoding="utf-8")
    HISTORY_FILE.touch(exist_ok=True)


def notifications_enabled() -> bool:
    try:
        return STATE_FILE.read_text(encoding="utf-8").strip() != "0"
    except OSError:
        return True


def unwrap(value):
    while isinstance(value, Variant):
        value = value.value
    return value


def trim_history() -> None:
    try:
        with HISTORY_FILE.open("r+", encoding="utf-8") as handle:
            lines = handle.readlines()
            if len(lines) <= MAX_ENTRIES:
                return
            handle.seek(0)
            handle.writelines(lines[-MAX_ENTRIES:])
            handle.truncate()
            handle.flush()
            os.fsync(handle.fileno())
    except OSError as err:
        print(f"notification-history: trim failed: {err}", file=sys.stderr)


def record(body) -> None:
    if not notifications_enabled() or not isinstance(body, (list, tuple)) or len(body) < 5:
        return

    app_name = str(unwrap(body[0]) or "")
    app_icon = str(unwrap(body[2]) or "")
    summary = str(unwrap(body[3]) or "")
    text = str(unwrap(body[4]) or "")
    if not summary and not text:
        return

    hints = unwrap(body[6]) if len(body) > 6 else {}
    image = ""
    if isinstance(hints, dict):
        for key in ("image-path", "desktop-entry", "image-data"):
            if key in hints:
                value = unwrap(hints[key])
                if isinstance(value, str):
                    image = value
                    break

    entry = {
        "time": time.time(),
        "iso": datetime.now().astimezone().isoformat(timespec="seconds"),
        "app": app_name,
        "icon": app_icon,
        "image": image,
        "summary": summary,
        "body": text,
    }

    try:
        with HISTORY_FILE.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())
    except OSError as err:
        print(f"notification-history: write failed: {err}", file=sys.stderr)
        return

    trim_history()


async def main() -> None:
    ensure_files()

    bus = await MessageBus().connect()
    # BecomeMonitor receives copies of messages addressed to other peers, which
    # is needed to see Notify calls sent to Quickshell's notification server.
    monitor_request = bus.send(
        Message(
            destination="org.freedesktop.DBus",
            path="/org/freedesktop/DBus",
            interface="org.freedesktop.DBus.Monitoring",
            member="BecomeMonitor",
            signature="asu",
            body=[["interface='org.freedesktop.Notifications',member='Notify'"], 0],
        )
    )

    def on_message(message) -> None:
        if (
            message.message_type == MessageType.METHOD_CALL
            and message.interface == "org.freedesktop.Notifications"
            and message.member == "Notify"
        ):
            try:
                record(message.body)
            except Exception as err:  # keep the daemon alive on malformed notifications
                print(f"notification-history: bad notification: {err}", file=sys.stderr)

    bus.add_message_handler(on_message)
    try:
        await bus.wait_for_disconnect()
    except EOFError:
        pass
    finally:
        monitor_request.cancel()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
