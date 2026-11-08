FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends inotify-tools entr procps \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /kit
COPY *.sh ./
RUN chmod +x *.sh
CMD ["bash"]
