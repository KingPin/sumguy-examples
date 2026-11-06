#!/bin/bash
# Runs inside the container (systemd is PID 1). Exit 0 when every check passes.
fail=0
RULES=/etc/polkit-1/rules.d
as() { local u=$1; shift; runuser -u "$u" -- "$@" 2>&1; }

check() { # check "<name>" <expected: ok|deny> <cmd...>
  local name=$1 want=$2; shift 2
  local out rc; out=$("$@" 2>&1); rc=$?
  if { [ "$want" = ok ] && [ $rc -eq 0 ]; } || { [ "$want" = deny ] && [ $rc -ne 0 ]; }; then
    echo "PASS  $name"
  else
    echo "FAIL  $name (rc=$rc)"; fail=1
  fi
  [ -n "$out" ] && echo "$out" | sed 's/^/        /'
}

# "degraded" is fine in a container (modules-load fails); wait only past starting.
while s=$(systemctl is-system-running); [ "$s" = initializing ] || [ "$s" = starting ]; do sleep 1; done
systemctl start demo-web.service demo-other.service
echo "polkit: $(pkaction --version)"
echo "systemd: $(systemctl --version | head -1)"
echo

echo "== Phase 1: no rule installed (defaults) =="
check "alice restart demo-web, no rule" deny as alice systemctl --no-ask-password restart demo-web.service

echo
echo "== Phase 2: polkit rule installed =="
install -m 0644 -o root -g root /root/50-oncall-restart.rules $RULES/50-oncall-restart.rules
sleep 2   # polkitd watches the dir; give it a moment to reload
before=$(systemctl show -p MainPID --value demo-web.service)
check "alice (oncall) restarts demo-web" ok as alice systemctl --no-ask-password restart demo-web.service
after=$(systemctl show -p MainPID --value demo-web.service)
[ "$before" != "$after" ] && echo "PASS  MainPID changed ($before -> $after)" || { echo "FAIL  MainPID unchanged"; fail=1; }
check "alice stop demo-web refused" deny as alice systemctl --no-ask-password stop demo-web.service
check "alice restart demo-other refused" deny as alice systemctl --no-ask-password restart demo-other.service
check "alice enable demo-web refused (manage-unit-files)" deny as alice systemctl --no-ask-password enable demo-web.service
check "bob (not in oncall) restart demo-web refused" deny as bob systemctl --no-ask-password restart demo-web.service
systemctl is-active demo-web.service >/dev/null && echo "PASS  demo-web still active after the refused stop" || { echo "FAIL  demo-web not active"; fail=1; }

echo
echo "== Phase 3: pkcheck (root asks about alice's process) =="
runuser -u alice -- sleep 60 2>/dev/null &
sleep 1
apid=$(pgrep -u alice -x sleep)
astart=$(awk '{print $22}' /proc/$apid/stat)
for v in restart stop; do
  pkcheck --action-id org.freedesktop.systemd1.manage-units --process "$apid,$astart,$(id -u alice)" \
    --detail unit demo-web.service --detail verb $v
  echo "        verb=$v pkcheck rc=$?"
done
kill $apid 2>/dev/null; wait 2>/dev/null

echo
echo "== Phase 4: polkit.log and the verbs systemctl sends =="
install -m 0644 /root/00-log-verbs.rules $RULES/00-log-verbs.rules
sleep 2
as alice systemctl --no-ask-password restart demo-web.service >/dev/null
echo "default unit (polkitd --no-debug), lines logged: $(journalctl -u polkit --no-pager -o cat | grep -c 'unit=demo-web')"
mkdir -p /etc/systemd/system/polkit.service.d
printf '[Service]\nExecStart=\nExecStart=/usr/lib/polkit-1/polkitd --log-level=notice\n' > /etc/systemd/system/polkit.service.d/log.conf
systemctl daemon-reload; systemctl restart polkit; sleep 2
for v in start stop restart try-restart reload reload-or-restart kill; do
  as alice systemctl --no-ask-password $v demo-web.service >/dev/null
done
as alice systemctl --no-ask-password restart demo-web >/dev/null
journalctl -u polkit --no-pager -o cat | grep -o 'unit=.*' | sed 's/^/        /'
rm -f $RULES/00-log-verbs.rules /etc/systemd/system/polkit.service.d/log.conf
systemctl daemon-reload; systemctl restart polkit
systemctl start demo-web.service

echo
echo "== Phase 5: sudoers alternative =="
rm -f $RULES/50-oncall-restart.rules; sleep 2
install -m 0440 -o root -g root /root/50-oncall-sudoers /etc/sudoers.d/50-oncall
check "visudo validates the drop-in" ok visudo -c
check "sudo: alice restarts demo-web" ok as alice sudo -n systemctl restart demo-web.service
check "sudo: alice stop demo-web refused" deny as alice sudo -n systemctl stop demo-web.service
check "sudo: alice restart demo-other refused" deny as alice sudo -n systemctl restart demo-other.service
check "sudo: bob restart demo-web refused" deny as bob sudo -n systemctl restart demo-web.service
check "polkit rule removed: alice plain restart refused again" deny as alice systemctl --no-ask-password restart demo-web.service

echo
[ $fail -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit $fail
