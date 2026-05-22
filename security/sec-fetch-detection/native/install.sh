#!/usr/bin/env bash
# One-time setup. Installs npm + pip deps into the project dir.
# No browser downloads (puppeteer-core / playwright-core).
# Cleanup: rm -rf node_modules .venv
#
# Tolerant of per-package failures (Python 3.14 wheel gaps).

set -uo pipefail
cd "$(dirname "$0")"

echo "==> npm install (browser downloads skipped)"
PUPPETEER_SKIP_DOWNLOAD=true \
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
npm install --no-audit --no-fund --omit=dev || {
  echo "    !!  npm install failed"; exit 1;
}

echo
echo "==> python venv"
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

pip install --quiet --upgrade pip wheel setuptools

py_try() {
  local pkg="$1"
  echo "    pip: $pkg"
  if pip install --quiet "$pkg"; then
    echo "         OK"
    return 0
  else
    echo "         !! failed (likely Python 3.14 wheel missing)"
    return 1
  fi
}

echo
echo "==> pip install (per-package, tolerant of failures)"

py_try "requests==2.32.3"
py_try "selenium==4.27.0"

# Try to pre-install a greenlet that supports Python 3.14, then playwright
echo "    pre-fetch: upgrading greenlet for Python 3.14 compatibility"
pip install --quiet --upgrade greenlet || echo "         !! greenlet upgrade failed"

# Try latest playwright (newer versions bundle newer greenlet)
py_try "playwright==1.49.0" || \
  py_try "playwright" || \
  echo "         playwright unavailable on this Python"

py_try "playwright-stealth==1.0.6" || true
py_try "undetected-chromedriver==3.5.5" || true

echo
echo "==> what's installed:"
for mod in requests playwright playwright_stealth selenium undetected_chromedriver; do
  if python -c "import $mod" 2>/dev/null; then
    printf "    %-30s OK\n" "$mod"
  else
    printf "    %-30s MISSING\n" "$mod"
  fi
done

echo
echo "==> sizes"
[[ -d node_modules ]] && echo "    node_modules: $(du -sh node_modules 2>/dev/null | cut -f1)"
[[ -d .venv ]] && echo "    .venv:        $(du -sh .venv 2>/dev/null | cut -f1)"
