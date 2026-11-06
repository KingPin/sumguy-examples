FROM debian:trixie

RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus polkitd sudo procps ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Two trivial services so we can prove the rule is scoped to one unit.
COPY demo-web.service demo-other.service /etc/systemd/system/
RUN groupadd oncall \
    && useradd -m -G oncall alice \
    && useradd -m bob \
    && systemctl enable demo-web.service demo-other.service

# Polkit rule is installed by test.sh (so it can show before/after).
COPY 50-oncall-restart.rules /root/50-oncall-restart.rules
COPY 50-oncall-sudoers /root/50-oncall-sudoers
COPY 00-log-verbs.rules /root/00-log-verbs.rules
COPY test.sh /test.sh
RUN chmod +x /test.sh

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
