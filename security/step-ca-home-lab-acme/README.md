# step-ca as a private ACME server, with Caddy

A private CA (smallstep `step-ca`) issues certificates over ACME to Caddy for `demo.home.arpa`. Nothing touches the public internet or public CT logs.

Companion to [step-ca: Let's Encrypt for Your LAN](https://sumguy.com/step-ca-home-lab-acme/).

## Files

| File | Purpose |
| --- | --- |
| `compose.yaml` | step-ca (ACME provisioner enabled by `DOCKER_STEPCA_INIT_ACME`) and Caddy on one Docker network |
| `Caddyfile` | One site, certificate from step-ca via `tls { ca ... ca_root ... }` |
| `bootstrap.sh` | Creates the CA password file, starts the CA, exports `root_ca.crt`, starts Caddy |
| `site/index.html` | Demo page |

## Prerequisites and tested versions

- Docker Engine 29.8 with Compose v2
- `smallstep/step-ca:0.30.2`, `caddy:2.11.7-alpine`
- Host ports 8080 and 8443 free

## Run

```bash
./bootstrap.sh
```

## Verify

```bash
curl --cacert root_ca.crt --resolve demo.home.arpa:8443:127.0.0.1 https://demo.home.arpa:8443/

echo | openssl s_client -connect 127.0.0.1:8443 -servername demo.home.arpa -CAfile root_ca.crt 2>/dev/null \
  | openssl x509 -noout -issuer -dates
```

Expected: HTTP 200, issuer `Home Lab CA Intermediate CA`, a lifetime of about 24 hours (the step-ca default).

## Notes

- The per-site `tls` block matters. Caddy treats `.home.arpa` as an internal name and signs it with its own local CA, ignoring a global `acme_ca`.
- The CA's keys and `ca.json` live in the `step-data` volume. Back it up and keep `ca_password.txt`.
- `root_ca.crt` is public. `ca_password.txt` is not: both are in `.gitignore`.

## Cleanup

```bash
docker compose down -v
rm -f root_ca.crt ca_password.txt
```
