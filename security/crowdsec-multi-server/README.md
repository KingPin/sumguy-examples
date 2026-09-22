# crowdsec-multi-server

Working files from **[CrowdSec Across a Home Lab: One Brain](https://sumguy.com/crowdsec-multi-server-home-lab/)** on SumGuy's Ramblings.

One central CrowdSec LAPI, remote agents on every other box that push alerts instead of keeping their own, and firewall bouncers everywhere that pull decisions from the one central LAPI. Ban an IP on box A, and it's blocked on box B and box C too.

## What's in here

| Path | What it is |
|---|---|
| `lapi/docker-compose.yml` | The central Local API (LAPI). Runs on the one box that's always on. |
| `agent/docker-compose.yml` | A log-parsing agent for a remote box, local LAPI disabled, pointed at the central one. |
| `bouncer/crowdsec-firewall-bouncer.yaml` | Config for the native `cs-firewall-bouncer` package on a remote box, pointed at the central LAPI. |

Placeholders to swap before running any of this: `192.168.1.10` (LAPI box's LAN IP), `boxb-agent` (agent machine name), `CHANGE_ME_AGENT_PASSWORD`, `CHANGE_ME_BOUNCER_KEY` / `CHANGE_ME_FIREWALL_BOUNCER_KEY`.

## Prerequisites

- Docker 24+ and Docker Compose v2 for the LAPI and agent containers.
- CrowdSec v1.8.1 (tested). Keep the LAPI and every agent/bouncer on the same version; a version mismatch has been known to crash an agent-only container on startup.
- The firewall bouncer (`cs-firewall-bouncer`) installed as a native package on each remote box, not in Docker, since it needs direct access to the host's iptables or nftables.
- Every box on the same LAN or Tailscale network, so port 8080 (the LAPI) is reachable between them but not from the internet.

## How to run it

1. **Start the central LAPI**, on the box that stays on 24/7:

   ```bash
   cd lapi/
   docker compose up -d
   ```

2. **Register each remote box's agent**, run on the LAPI box:

   ```bash
   docker exec -it crowdsec-lapi cscli machines add boxb-agent --password CHANGE_ME_AGENT_PASSWORD
   ```

   Repeat with a unique machine name and password per remote box.

3. **Register a bouncer for each remote box**, also run on the LAPI box:

   ```bash
   docker exec -it crowdsec-lapi cscli bouncers add firewall-boxb
   ```

   This prints an API key once. Save it, you'll need it in step 5.

4. **Start the agent on each remote box**, after editing `agent/docker-compose.yml` with that box's machine name, password, and the LAPI's LAN IP:

   ```bash
   cd agent/
   docker compose up -d
   ```

5. **Install the firewall bouncer on each remote box** (package install, see [docs.crowdsec.net](https://docs.crowdsec.net/u/bouncers/firewall/) for your distro), then drop `bouncer/crowdsec-firewall-bouncer.yaml` into `/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` with the API key from step 3, and restart the bouncer service.

6. **Verify it actually works**, from the LAPI box:

   ```bash
   docker exec -it crowdsec-lapi cscli decisions add --ip 203.0.113.42 --duration 4h --reason "multi-server smoke test"
   docker exec -it crowdsec-lapi cscli bouncers list
   ```

   Then on a remote box, confirm the IP landed in its firewall set:

   ```bash
   sudo nft list table ip crowdsec | grep 203.0.113.42
   ```

   `203.0.113.42` should show up within one `update_frequency` cycle (10 seconds by default), with zero manual steps on the remote box.

## Notes

- Don't expose port 8080 to the internet. Firewall it to LAN/Tailscale-only, or use TLS client-cert auth if you want to skip passwords entirely (see the article for the config keys).
- If the LAPI box goes down, existing firewall/nftables entries on remote boxes stay enforced (they're already in the kernel), but new bans and expirations stop propagating until it's back.
