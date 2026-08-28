# A job image that carries both halves of what a build job needs.
#
# JS actions (actions/checkout, actions/setup-node) are executed with `node`
# inside the job container, and `docker build` steps need the docker CLI.
# data.forgejo.org/oci/node:22-bookworm has node and no docker.
# data.forgejo.org/oci/docker:cli has docker and no node.
#
# Build it, push it to your Forgejo container registry, and point a runner
# label at it:
#
#   docker build -t git.example.com/you/ci-runner:latest -f ci-runner.Dockerfile .
#   docker push git.example.com/you/ci-runner:latest
#
#   labels:
#     - ci:docker://git.example.com/you/ci-runner:latest

FROM data.forgejo.org/oci/node:22-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*
