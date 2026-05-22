import os
import time
import undetected_chromedriver as uc

# undetected-chromedriver auto-patches a matching chromedriver; we point it
# at the system chromium (which is paired with the system chromedriver).
CHROME = os.environ.get("UC_CHROME_BIN", "/usr/bin/chromium")
# Use a writable copy — undetected-chromedriver patches the binary in place.
DRIVER = os.environ.get("UC_DRIVER_BIN", os.path.join(os.path.dirname(__file__), "..", "bin", "chromedriver"))
DRIVER = os.path.abspath(DRIVER)

options = uc.ChromeOptions()
options.add_argument("--headless=new")
options.add_argument("--no-sandbox")
options.add_argument("--disable-dev-shm-usage")
options.binary_location = CHROME

driver = uc.Chrome(
    options=options,
    browser_executable_path=CHROME,
    driver_executable_path=DRIVER,
    use_subprocess=True,
)
try:
    driver.get("http://localhost:8080/?client=undetected-chromedriver")
    time.sleep(2)
finally:
    driver.quit()

print("undetected-chromedriver done")
