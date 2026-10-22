# Self-hosted UniFi Network Application (Docker Compose)

Runs the UniFi Network Application controller with the linuxserver.io image and a MongoDB container. Use it to manage UniFi APs and switches while a different box (for example OPNsense) does the routing.

Companion to [UniFi in a Home Lab: Worth the Tax?](https://sumguy.com/unifi-home-lab-tax/)

> **Heads up:** Ubiquiti announced in September 2026 that UniFi Network 10.6 is the final standalone Network Application release. Network 11 and later ship only on UniFi OS Server and UniFi consoles. This stack keeps working on 10.6 but gets no new features. See the article for the UniFi OS Server route.

## Prerequisites

- Docker Engine with the Compose plugin
- A host on the same L2 network as your UniFi devices for discovery (10001/udp is broadcast and does not cross VLANs). Devices on other networks only need to reach 8080/tcp, using `set-inform`.
- Host ports 8443, 8080, 3478/udp and 10001/udp free, plus the optional ones in `compose.yaml` (1900/udp, 8843, 8880, 6789, 5514/udp). Comment out any optional port that is already taken; 1900/udp often is (Plex, DLNA, Home Assistant).
- An x86_64 CPU with AVX for MongoDB 8.0. Celeron and Pentium chips from before Tiger Lake lack it; pin `mongo:4.4` on those.

## Tested versions

| Component | Version |
| --- | --- |
| `lscr.io/linuxserver/unifi-network-application` | 10.6.106 |
| `mongo` | 8.0.34 |
| Docker Engine | 29.8.2 |

The controller needs MongoDB 3.6 to 7.0 on 8.1+ builds, and 8.0 is supported from Network Application 9.0 (linuxserver.io docs). Tested 2026-10-22: `docker compose config` passes and `/status` on the web UI port reports `"up":true` with server version 10.6.106.

## Run

```bash
cp .env.example .env     # then edit both passwords (letters and digits only)
docker compose up -d
```

Open `https://<host-ip>:8443` and finish the setup wizard. The certificate is self-signed.

Before adopting anything, enable **Inform Host Override** and set it to the Docker host's IP or hostname. Inside Docker the controller only knows its container IP, which your devices cannot reach. The linuxserver.io docs place the setting under UniFi Devices > Device Updates and Settings > Device SSH Settings; Ubiquiti moves it often, so search the settings for "Inform".

`init-mongo.sh` only runs when `data/db` is empty. If you change the passwords after the first start, delete `data/db` (this erases the controller database) and start again.

## Adopt a device

SSH into the device, then point it at the controller:

```bash
ssh <device-user>@<device-ip>
set-inform http://<controller-ip>:8080/inform
```

Then click adopt in the UI. If the device sits at "Adopting" and drops offline, check the Inform Host Override. Factory-reset devices accept `ui` / `ui` (older devices: `ubnt` / `ubnt`). Previously adopted devices use the SSH credentials from the old controller.

## Tear down

```bash
docker compose down -v
rm -rf data    # may need sudo: the mongo container writes as another user
```

## Notes

- Port 8080 is the inform port. Anything that must adopt a device needs to reach it.
- Back up `data/config` (the app writes automatic backups there) before upgrading. Pin image tags and move one version at a time.
