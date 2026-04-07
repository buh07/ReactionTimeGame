import contextlib
import asyncio
import logging
import os
import struct

import httpx
from bleak import BleakClient, BleakError, BleakScanner
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("bridge")

DEVICE_NAME = os.environ["DEVICE_NAME"]
CHAR_UUID = os.environ["CHAR_UUID"]
API_URL = os.environ["API_URL"]
PLAYER = os.environ["PLAYER_NAME"]
DUEL_ID = os.environ.get("DUEL_ID")

score_queue: asyncio.Queue[int] = asyncio.Queue()


def handle_notify(sender: int, data: bytearray) -> None:
    """Queue notification payloads quickly; never block BLE callbacks."""
    _ = sender
    score_ms = struct.unpack_from("<I", data)[0]
    log.info("Score received: %d ms", score_ms)
    score_queue.put_nowait(score_ms)


async def post_score(client: httpx.AsyncClient, score_ms: int) -> None:
    """Post with retries and bounded backoff."""
    payload = {"player": PLAYER, "reaction_ms": score_ms}
    if DUEL_ID:
        payload["duel_id"] = DUEL_ID

    for attempt in range(1, 4):
        try:
            response = await client.post(API_URL, json=payload, timeout=5.0)
            response.raise_for_status()
            log.info("Posted %d ms -> %d", score_ms, response.status_code)
            return
        except httpx.HTTPError as exc:
            log.warning("Post attempt %d failed: %s", attempt, exc)
            await asyncio.sleep(attempt * 2)

    log.error("Giving up on score %d ms after 3 attempts", score_ms)


async def http_worker(client: httpx.AsyncClient) -> None:
    """Drain queued scores and submit them to the API."""
    while True:
        score_ms = await score_queue.get()
        try:
            await post_score(client, score_ms)
        finally:
            score_queue.task_done()


async def connect_and_listen() -> None:
    """Scan for the BLE peripheral, subscribe, then wait for disconnect."""
    log.info("Scanning for '%s'...", DEVICE_NAME)
    device = await BleakScanner.find_device_by_name(DEVICE_NAME, timeout=15)
    if device is None:
        raise RuntimeError(f"Device '{DEVICE_NAME}' not found")

    async with BleakClient(device) as ble:
        log.info("Connected to %s", device.address)
        await ble.start_notify(CHAR_UUID, handle_notify)
        while ble.is_connected:
            await asyncio.sleep(1)
        log.warning("BLE connection lost")


async def main() -> None:
    async with httpx.AsyncClient() as http:
        worker = asyncio.create_task(http_worker(http))
        try:
            while True:
                try:
                    await connect_and_listen()
                except (BleakError, RuntimeError) as exc:
                    log.warning("BLE error: %s - retrying in 5 s", exc)
                await asyncio.sleep(5)
        finally:
            worker.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await worker


if __name__ == "__main__":
    asyncio.run(main())
