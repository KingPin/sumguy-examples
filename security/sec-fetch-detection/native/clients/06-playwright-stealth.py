import os
from playwright.sync_api import sync_playwright
from playwright_stealth import stealth_sync

CHROME = os.environ.get("CHROMIUM_BIN")
if not CHROME:
    raise SystemExit("CHROMIUM_BIN env var required")

with sync_playwright() as p:
    browser = p.chromium.launch(
        headless=True,
        executable_path=CHROME,
    )
    context = browser.new_context()
    page = context.new_page()
    stealth_sync(page)
    page.goto(
        "http://localhost:8080/?client=playwright-stealth",
        wait_until="networkidle",
        timeout=30000,
    )
    page.wait_for_timeout(1000)
    browser.close()
    print("playwright-stealth done")
