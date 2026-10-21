#!/usr/bin/env bash
# php2shell-check.sh: find PHP in every running container and say if it has the
# PHP2Shell fix (CVE-2026-109618 / CVE-2026-109619).
# NOTE: ini values are the CLI view. FPM pools can override them with
# php_admin_value, so check your pool configs too.
set -u
# usage: php2shell-check.sh [name-regex]   (default: every running container)

FIXED="8.5.12 8.4.27 8.3.36 8.2.35"

# Runs inside the container (plain sh). Prints key=value lines, or nothing if no PHP.
probe='
keys="memory_limit post_max_size session.upload_progress.enabled opcache.enable"
bin=""
for d in /usr/local/bin /usr/local/sbin /usr/bin /usr/sbin /opt/*/bin; do
  for b in "$d"/php "$d"/php[0-9]* "$d"/php-fpm "$d"/php-fpm[0-9]* "$d"/frankenphp; do
    [ -x "$b" ] && [ -f "$b" ] && { bin=$b; break 2; }
  done
done
[ -z "$bin" ] && bin=$(command -v php || command -v php-fpm || command -v frankenphp)
[ -z "$bin" ] && exit 3
case "$bin" in
  *frankenphp) v=$($bin version 2>&1); i=$(for k in $keys; do echo "$k => $($bin php-cli -r "echo ini_get(\"$k\");" 2>/dev/null) => x"; done) ;;
  *) v=$($bin -v 2>&1 | head -1); i=$($bin -i 2>/dev/null) ;;
esac
echo "ver=$(echo "$v" | grep -o "PHP [0-9][0-9.]*[A-Za-z0-9]*" | head -1 | cut -d" " -f2)"
echo "sapi=$(echo "$v" | grep -o "(fpm-fcgi)\|(cli)\|(cgi-fcgi)" | head -1 | tr -d "()")/${bin##*/}"
for k in $keys; do
  echo "$k=$(echo "$i" | awk -F" => " -v k="$k" "\$1==k{print \$2; exit}")"
done'

# status VERSION -> PATCHED | VULNERABLE | EOL-NO-FIX | UNKNOWN
status() {
  local v=$1 mm=${1%.*} f
  [[ $v =~ ^[0-9]+\.[0-9]+ ]] || { echo UNKNOWN; return; }
  case $v in
    8.6.0RC*) [ "${v#8.6.0RC}" -ge 4 ] 2>/dev/null && echo PATCHED || echo VULNERABLE; return ;;
    8.6.0alpha*|8.6.0beta*) echo VULNERABLE; return ;;
  esac
  for f in $FIXED; do
    [ "${f%.*}" = "$mm" ] || continue
    [ "$(printf '%s\n%s\n' "$f" "$v" | sort -V | head -1)" = "$f" ] && echo PATCHED || echo VULNERABLE
    return
  done
  # no fixed release for this branch: older than 8.2 is EOL, newer than 8.5 is post-fix
  [ "$(printf '%s\n%s\n' 8.2.0 "$v" | sort -V | head -1)" = "8.2.0" ] && echo PATCHED || echo EOL-NO-FIX
}

printf '%-24s %-30s %-8s %-17s %-11s %-6s %-6s %-5s %s\n' \
  CONTAINER IMAGE PHP SAPI STATUS MEMLIM POSTMAX UPLPR OPC
bad=0
while IFS='|' read -r name image; do
  out=$(docker exec -i "$name" sh -c "$probe" </dev/null 2>/dev/null); rc=$?
  case $rc in
    0) ;;
    3) echo "# $name: no PHP found, skipped"; continue ;;
    *) echo "# $name: no shell or exec failed (rc=$rc), skipped"; continue ;;
  esac
  get() { echo "$out" | sed -n "s/^$1=//p" | head -1; }
  ver=$(get ver); st=$(status "$ver")
  # UNKNOWN counts as bad: a PHP binary we can't read a version from needs a human look
  [ "$st" = PATCHED ] || bad=1
  printf '%-24s %-30s %-8s %-17s %-11s %-6s %-6s %-5s %s\n' "$name" "${image:0:30}" "${ver:-?}" \
    "$(get sapi)" "$st" "$(get memory_limit)" "$(get post_max_size)" \
    "$(get session.upload_progress.enabled)" "$(get opcache.enable)"
  [ "$st" = EOL-NO-FIX ] && echo "# $name: PHP project ships no fix for this branch. Check your image vendor or distro for a backport, or upgrade."
done < <(docker ps --format '{{.Names}}|{{.Image}}' | grep -E "${1:-.}")

exit $bad
