# Music Assistant: Whole-Home Audio in HA

Docker Compose for the Music Assistant server, four Home Assistant automations that drive it, and the client commands for a Raspberry Pi speaker room.

Companion to the article: [Music Assistant: Whole-Home Audio in HA](https://sumguy.com/music-assistant-whole-home-audio/) on SumGuy's Ramblings.

## What it does
- `compose.yaml`: runs Music Assistant 2.10.12 with host networking, a persistent `./data` volume, and a read-only music mount.
- `automations.yaml`: morning playlist (`music_assistant.play_media`), TTS dinner announcement (`music_assistant.play_announcement`), "follow me" queue move (`music_assistant.transfer_queue`), and a party-mode group (`media_player.join`).
- `pi-room-clients.sh`: the `snapclient` and `squeezelite` commands for a Pi room (commented out; pick one).

## Prerequisites
- Docker with Compose v2, on a 64-bit host with at least 2 GB RAM.
- The Music Assistant host on the same layer 2 network as your speakers (no VLANs between them).
- Home Assistant 2024.12 or newer with the Music Assistant integration (written against 2026.11.2).
- For the announcement example: a TTS entity (the example uses `tts.piper`).

Tested versions: the container was started on 2026-11-18 and served the web UI on port 8095 and the stream server on 8097. The automations parse and use only fields from the 2026.11.2 `music_assistant` services, but were not run against a live instance.

## How to run
```bash
# edit the music path in compose.yaml first
docker compose up -d
# open http://<host-ip>:8095 and finish onboarding, then add a music source
```
Then in Home Assistant: Settings > Devices & services > Add integration > Music Assistant (or accept the discovered one). Log in with an MA admin account.

Copy the automations you want into your `automations.yaml`, replace the entity IDs, and reload automations.

## Files
- `compose.yaml`
- `automations.yaml`
- `pi-room-clients.sh`
