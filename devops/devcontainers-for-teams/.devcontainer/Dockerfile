FROM mcr.microsoft.com/devcontainers/python:3.13-trixie

# Dependencies live in the image so a prebuild carries them.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
