"""NotebookLM non-interactive login script.

Opens Edge browser (with existing Google session),
polls URL until login succeeds, then saves storage_state.
"""

import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

STORAGE_PATH = Path.home() / ".notebooklm" / "storage_state.json"
BROWSER_PROFILE = Path.home() / ".notebooklm" / "browser_profile"
NOTEBOOKLM_URL = "https://notebooklm.google.com/"


def main():
    STORAGE_PATH.parent.mkdir(parents=True, exist_ok=True)
    BROWSER_PROFILE.mkdir(parents=True, exist_ok=True)

    print("[*] Opening browser...")

    with sync_playwright() as p:
        # Try Edge first (likely has Google session), fallback to Chromium
        try:
            context = p.chromium.launch_persistent_context(
                user_data_dir=str(BROWSER_PROFILE),
                headless=False,
                channel="msedge",
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--password-store=basic",
                ],
                ignore_default_args=["--enable-automation"],
            )
            print("[*] Using Microsoft Edge")
        except Exception:
            context = p.chromium.launch_persistent_context(
                user_data_dir=str(BROWSER_PROFILE),
                headless=False,
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--password-store=basic",
                ],
                ignore_default_args=["--enable-automation"],
            )
            print("[*] Using Chromium")

        page = context.pages[0] if context.pages else context.new_page()
        page.goto(NOTEBOOKLM_URL, wait_until="domcontentloaded", timeout=30000)

        print("[*] Waiting for login... (max 10 min)")
        print("[*] If browser opened, please log in with Google.")

        max_wait = 600
        start = time.time()
        logged_in = False

        while time.time() - start < max_wait:
            try:
                current_url = page.url
                if "notebooklm.google.com" in current_url and "accounts.google" not in current_url:
                    # Wait for page to fully load
                    page.wait_for_load_state("networkidle", timeout=10000)
                    time.sleep(2)
                    logged_in = True
                    break
            except Exception:
                pass
            time.sleep(2)

        if logged_in:
            context.storage_state(path=str(STORAGE_PATH))
            print(f"[OK] Auth saved: {STORAGE_PATH}")
        else:
            print("[FAIL] Timeout (10 min). Try again.")

        context.close()

    return 0 if logged_in else 1


if __name__ == "__main__":
    sys.exit(main())
