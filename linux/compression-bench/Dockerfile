# Every tool at its current upstream release (checked 2026-10-06):
# zstd 1.5.7, lz4 1.10.0, xz 5.8.4, gzip 1.14, pigz 2.8, bzip2 1.0.8.
FROM debian:forky-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      zstd lz4 xz-utils gzip pigz bzip2 time unzip curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY run.sh /run.sh
ENTRYPOINT ["bash", "/run.sh"]
