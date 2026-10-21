#!/bin/sh
# Fetch LittleLink v3.11.0 into ./site (not vendored in this repo).
set -e
cd "$(dirname "$0")"
rm -rf site
git clone --depth 1 --branch v3.11.0 https://github.com/sethcottle/littlelink.git site
rm -rf site/.git
