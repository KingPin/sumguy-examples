#!/bin/bash
# Runs inside the container as root. Each check prints PASS or FAIL.
fail=0
check() { # name, expected (0=should succeed, 1=should fail), command...
  local name=$1 want=$2; shift 2
  "$@" >/tmp/out 2>&1; local rc=$?
  if { [ "$want" = 0 ] && [ $rc -eq 0 ]; } || { [ "$want" = 1 ] && [ $rc -ne 0 ]; }; then
    echo "PASS  $name"
  else
    echo "FAIL  $name (rc=$rc)"; fail=1
  fi
  sed 's/^/        /' /tmp/out
}
as() { local u=$1; shift; su -s /bin/bash "$u" -c "$*"; }

sudo --version | head -1
dpkg-query -W -f='doas (OpenDoas) ${Version}\n' doas
sudo-rs --version | head -1
echo
check "visudo -c validates the drop-in"        0 visudo -c
check "doas -C validates doas.conf"            0 doas -C /etc/doas.conf
echo "permit nopass :svc as root cmd /bin/nope extra" > /tmp/bad.conf
check "doas -C rejects a broken config"        1 doas -C /tmp/bad.conf
check "sudo: alice runs allowed cmd"           0 as alice "sudo -n /usr/local/bin/restart-web"
check "sudo: alice refused on other cmd"       1 as alice "sudo -n /bin/cat /etc/shadow"
check "sudo: bob refused on allowed cmd"       1 as bob   "sudo -n /usr/local/bin/restart-web"
check "doas: alice runs allowed cmd"           0 as alice "doas /usr/local/bin/restart-web"
check "doas: alice refused on other cmd"       1 as alice "doas /bin/cat /etc/shadow"
check "doas: bob refused on allowed cmd"       1 as bob   "doas /usr/local/bin/restart-web"
check "sudo-rs: alice runs allowed cmd"        0 as alice "sudo-rs -n /usr/local/bin/restart-web"
check "sudo-rs: alice refused on other cmd"    1 as alice "sudo-rs -n /bin/cat /etc/shadow"
echo
exit $fail
