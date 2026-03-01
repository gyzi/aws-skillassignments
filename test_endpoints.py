#!/usr/bin/env python3
"""
Integration test for the Multi-Region AI Video Analytics API.

Authenticates via Cognito, then tests /greet and /dispatch in both regions.
Exits with code 1 if any check fails (CI-friendly).

Required environment variables:
    COGNITO_CLIENT_ID       Cognito App Client ID
    COGNITO_USERNAME        Test user username
    COGNITO_PASSWORD        Test user password
    API_ENDPOINT_US_EAST    e.g. https://abc.execute-api.us-east-1.amazonaws.com
    API_ENDPOINT_EU_WEST    e.g. https://def.execute-api.eu-west-1.amazonaws.com
"""

import os
import sys
import json
import time
import concurrent.futures
import boto3
import requests

# ── Configuration ────────────────────────────────────────────
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID")
COGNITO_USERNAME = os.getenv("COGNITO_USERNAME")
COGNITO_PASSWORD = os.getenv("COGNITO_PASSWORD")
API_US_EAST = os.getenv("API_ENDPOINT_US_EAST", "").rstrip("/")
API_EU_WEST = os.getenv("API_ENDPOINT_EU_WEST", "").rstrip("/")

REQUIRED_VARS = {
    "COGNITO_CLIENT_ID": COGNITO_CLIENT_ID,
    "COGNITO_USERNAME": COGNITO_USERNAME,
    "COGNITO_PASSWORD": COGNITO_PASSWORD,
    "API_ENDPOINT_US_EAST": API_US_EAST,
    "API_ENDPOINT_EU_WEST": API_EU_WEST,
}

REGIONS = {
    "us-east-1": API_US_EAST,
    "eu-west-1": API_EU_WEST,
}

# ── Colours (ANSI) ───────────────────────────────────────────
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RESET = "\033[0m"
BOLD = "\033[1m"


def ok(msg):
    print(f"  {GREEN}✓ PASS{RESET}  {msg}")


def fail(msg):
    print(f"  {RED}✗ FAIL{RESET}  {msg}")


def info(msg):
    print(f"  {CYAN}ℹ{RESET}  {msg}")


# ── Auth ─────────────────────────────────────────────────────
def authenticate(client_id, username, password, region="us-east-1"):
    """Return an ID token from Cognito USER_PASSWORD_AUTH flow."""
    client = boto3.client("cognito-idp", region_name=region)
    resp = client.initiate_auth(
        ClientId=client_id,
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={"USERNAME": username, "PASSWORD": password},
    )
    return resp.get("AuthenticationResult", {}).get("IdToken")


# ── Helpers ──────────────────────────────────────────────────
def deep_find(obj, key):
    """Recursively search for a key in nested dicts/lists."""
    if isinstance(obj, dict):
        if key in obj:
            return obj[key]
        for v in obj.values():
            r = deep_find(v, key)
            if r is not None:
                return r
    elif isinstance(obj, list):
        for item in obj:
            r = deep_find(item, key)
            if r is not None:
                return r
    return None


def parse_response(resp):
    """Parse API Gateway response, unwrapping stringified body if needed."""
    try:
        data = resp.json()
    except ValueError:
        try:
            data = json.loads(resp.text)
        except Exception:
            return {"_raw": resp.text}

    # API GW v2 sometimes wraps: {"body": "<json-string>"}
    if isinstance(data, dict) and "body" in data and isinstance(data["body"], str):
        try:
            data = {**data, **json.loads(data["body"])}
        except Exception:
            pass
    return data


# ── Test Runner ──────────────────────────────────────────────
class TestResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def record(self, success, msg):
        if success:
            ok(msg)
            self.passed += 1
        else:
            fail(msg)
            self.failed += 1

    @property
    def all_passed(self):
        return self.failed == 0


def test_endpoint(region, base_url, path, id_token, results):
    """POST to an endpoint and validate the response."""
    url = f"{base_url}{path}"
    headers = {"Authorization": id_token} if id_token else {}
    payload = {"message": f"integration test ({region})"}

    start = time.perf_counter()
    try:
        resp = requests.post(url, json=payload, headers=headers, timeout=30)
        elapsed_ms = (time.perf_counter() - start) * 1000
    except Exception as e:
        fail(f"[{region}] POST {path} → EXCEPTION: {e}")
        results.failed += 1
        return

    data = parse_response(resp)
    region_field = deep_find(data, "region")

    # Check 1: HTTP 200
    results.record(
        resp.status_code == 200,
        f"[{region}] POST {path} → status={resp.status_code} ({elapsed_ms:.0f}ms)",
    )

    # Check 2: region field matches expected
    if path == "/greet":
        results.record(
            region_field == region,
            f"[{region}] POST {path} → region_field={region_field!r} (expected {region!r})",
        )

    info(f"Response body: {json.dumps(data, indent=2, default=str)[:300]}")


def test_unauthenticated_is_blocked(base_url, results):
    """Verify that requests without a token get 401."""
    url = f"{base_url}/greet"
    try:
        resp = requests.post(url, json={"message": "no-auth"}, timeout=10)
        results.record(
            resp.status_code == 401,
            f"Unauthenticated POST /greet → {resp.status_code} (expected 401)",
        )
    except Exception as e:
        fail(f"Unauthenticated test error: {e}")
        results.failed += 1


# ── Main ─────────────────────────────────────────────────────
def main():
    # Validate env vars
    missing = [k for k, v in REQUIRED_VARS.items() if not v]
    if missing:
        print(f"{RED}ERROR:{RESET} Missing environment variables: {', '.join(missing)}")
        print("Set them before running this script.")
        sys.exit(2)

    results = TestResult()

    # ── 1. Authenticate ──────────────────────────────────────
    print(f"\n{BOLD}{'='*60}")
    print("  Multi-Region API Integration Tests")
    print(f"{'='*60}{RESET}\n")

    print(f"{YELLOW}→ Authenticating with Cognito...{RESET}")
    id_token = authenticate(COGNITO_CLIENT_ID, COGNITO_USERNAME, COGNITO_PASSWORD)
    if not id_token:
        print(f"{RED}ERROR:{RESET} Failed to obtain ID token from Cognito")
        sys.exit(1)
    ok("Cognito authentication successful")

    # ── 2. Test unauthenticated access is blocked ────────────
    print(f"\n{YELLOW}→ Testing unauthenticated access is blocked...{RESET}")
    test_unauthenticated_is_blocked(API_US_EAST, results)

    # ── 3. Test all endpoints ────────────────────────────────
    print(f"\n{YELLOW}→ Testing authenticated endpoints...{RESET}")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = []
        for region, base in REGIONS.items():
            for path in ("/greet", "/dispatch"):
                futures.append(
                    pool.submit(test_endpoint, region, base, path, id_token, results)
                )
        concurrent.futures.wait(futures)

    # ── 4. Summary ───────────────────────────────────────────
    print(f"\n{BOLD}{'='*60}")
    total = results.passed + results.failed
    colour = GREEN if results.all_passed else RED
    print(f"  Results: {colour}{results.passed}/{total} passed{RESET}")
    print(f"{'='*60}{RESET}\n")

    sys.exit(0 if results.all_passed else 1)


if __name__ == "__main__":
    main()