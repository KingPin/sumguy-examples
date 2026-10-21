# php2shell-check

Finds PHP inside every running Docker container and reports whether it has the PHP2Shell fix (CVE-2026-109618 and CVE-2026-109619, disclosed 2026-10-21).

For each container it prints: name, image, PHP version, SAPI/binary, status (`PATCHED`, `VULNERABLE`, `EOL-NO-FIX`), and the effective `memory_limit`, `post_max_size`, `session.upload_progress.enabled`, `opcache.enable`.

Fixed versions: 8.5.12, 8.4.27, 8.3.36, 8.2.35. PHP 8.6.0RC4 and later count as patched. PHP 8.1 and older are `EOL-NO-FIX`: the PHP project ships no binaries for them, but your distro or image vendor may backport.

## Prerequisites

- Bash 4+, `docker` CLI with access to the daemon, GNU coreutils (`sort -V`)
- Containers need a POSIX `sh` (BusyBox is fine). Shell-less containers are skipped with a note.

Tested with Docker 29.8.2 (client and server) on Linux, against `php:8.4.26-fpm`, `php:8.4.27-fpm`, `php:8.1-fpm`, `php:8.4.27-fpm-alpine`, `wordpress:php8.4-fpm`, `dunglas/frankenphp`, `redis:alpine`, `traefik`, and a scratch image with no shell.

## Run

```bash
chmod +x php2shell-check.sh
./php2shell-check.sh              # every running container
./php2shell-check.sh '^nextcloud' # only names matching a regex
```

Exit code is 1 if any container is `VULNERABLE`, `EOL-NO-FIX`, or `UNKNOWN` (PHP found but no readable version), otherwise 0.

## Limitations

- ini values are the CLI view. PHP-FPM pools can override them with `php_admin_value`, so check your pool configs separately.
- The script finds one PHP binary per container. A container that runs several PHP versions reports the first one found.
- The status is the version only. A distro build with a backported fix can report an old version string and still be patched. Check the vendor.
- It does not look at PHP on the host, only in running containers.

Write-up: https://sumguy.com/php2shell-homelab-triage/
