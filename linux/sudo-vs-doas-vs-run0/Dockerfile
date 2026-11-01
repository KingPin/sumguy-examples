FROM debian:trixie
RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo doas sudo-rs polkitd \
 && rm -rf /var/lib/apt/lists/*
RUN groupadd svc \
 && useradd -m -s /bin/bash -G svc alice \
 && useradd -m -s /bin/bash bob
RUN printf '#!/bin/sh\necho "restarting web (demo stub) as uid $(id -u)"\n' > /usr/local/bin/restart-web \
 && chmod 755 /usr/local/bin/restart-web
COPY sudoers.d/50-svc /etc/sudoers.d/50-svc
COPY doas.conf /etc/doas.conf
COPY 50-run0-homelab.rules /etc/polkit-1/rules.d/50-run0-homelab.rules
RUN chmod 440 /etc/sudoers.d/50-svc && chmod 400 /etc/doas.conf
COPY test.sh /test.sh
CMD ["bash", "/test.sh"]
