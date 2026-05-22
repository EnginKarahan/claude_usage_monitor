#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
"""
Poll Claude Code's /api/oauth/usage endpoint and write a status JSON
the KDE plasmoid reads.

Uses the OAuth access token Claude Code already stored in
~/.claude/.credentials.json — no separate auth, no scraping.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

CREDENTIALS_PATH = Path.home() / ".claude" / ".credentials.json"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "claude-widget"
STATUS_PATH = CACHE_DIR / "status.json"
HISTORY_PATH = CACHE_DIR / "history.json"

USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
REFRESH_URL = "https://console.anthropic.com/v1/oauth/token"
USER_AGENT = "claude-widget/0.1 (KDE plasmoid poller)"

# How many recent samples to keep for burn-rate computation.
HISTORY_MAX = 24  # ~2h at 5-min cadence
# Minimum elapsed time between two samples to trust a burn-rate calc.
MIN_BURN_WINDOW_S = 60
# Cap on projected utilization stored in status.json. The classification
# uses the raw value; this only avoids absurd display numbers when a
# short burst gets extrapolated over many hours.
PROJECTION_CAP = 200.0
# Treat a util drop bigger than this (vs. the next-newer sample) as a
# window reset so older samples are excluded from the burn-rate window.
RESET_DROP_THRESHOLD = 5.0
# Don't extrapolate burn rate further than this into the future. The
# weekly window reset can be 7 days away (just after the previous one);
# multiplying a 5-min burn-rate sample by 7 days gives nonsensical
# projections. Project at most this far, regardless of actual window end.
MAX_PROJECTION_HORIZON_S = 4 * 3600  # 4 hours

# Color thresholds applied to PROJECTED utilization at reset time.
#   blue  : will leave tokens on the table
#   green : optimum
#   yellow: at threshold of the limit
#   red   : projected to exceed
THRESH_BLUE_MAX = 95.0
THRESH_GREEN_MAX = 100.0
THRESH_YELLOW_MAX = 103.0


@dataclass
class Bucket:
    utilization: float
    resets_at: datetime

    @classmethod
    def parse(cls, raw: dict) -> "Bucket | None":
        if not raw or raw.get("utilization") is None or not raw.get("resets_at"):
            return None
        return cls(
            utilization=float(raw["utilization"]),
            resets_at=_parse_iso(raw["resets_at"]),
        )


def _parse_iso(s: str) -> datetime:
    # Python's fromisoformat handles "+00:00" but not "Z" until 3.11+.
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def _read_credentials() -> dict:
    if not CREDENTIALS_PATH.exists():
        raise SystemExit(
            f"Credentials not found at {CREDENTIALS_PATH}. "
            "Log into Claude Code first (run `claude` and authenticate)."
        )
    with CREDENTIALS_PATH.open() as f:
        return json.load(f)


def _http_get(url: str, token: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _load_history() -> list[dict]:
    if not HISTORY_PATH.exists():
        return []
    try:
        with HISTORY_PATH.open() as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return []


def _save_history(history: list[dict]) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    HISTORY_PATH.write_text(json.dumps(history))


def _atomic_write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2))
    os.replace(tmp, path)


def _burn_rate_per_second(
    history: list[dict], key: str, now_util: float, now_ts: float
) -> float | None:
    """Average burn rate over the longest valid window.

    "Valid" means: no detected window-reset between the chosen sample and
    now. We walk back from newest to oldest; if a sample's value is
    significantly HIGHER than the next-newer one's, the window must have
    reset between them, so we stop there. Using the oldest still-valid
    sample smooths out short bursts.
    """
    valid_samples: list[dict] = []
    last_val = now_util
    for sample in reversed(history):
        if key not in sample:
            continue
        if sample[key] > last_val + RESET_DROP_THRESHOLD:
            # Sample is higher than newer one ⇒ window reset since then.
            break
        valid_samples.append(sample)
        last_val = sample[key]

    if not valid_samples:
        return None

    oldest = valid_samples[-1]
    elapsed = now_ts - oldest["ts"]
    if elapsed < MIN_BURN_WINDOW_S:
        return None
    delta = now_util - oldest[key]
    if delta <= 0:
        return 0.0
    return delta / elapsed


def _classify(projected: float, current: float, resets_in_s: float) -> str:
    """Return one of: blue, green, yellow, red."""
    # If we're already over (or basically there), no projection ambiguity.
    if current >= THRESH_YELLOW_MAX:
        return "red"
    # Very short window remaining (<5 min): trust current state, not projection.
    if resets_in_s < 300:
        if current >= THRESH_GREEN_MAX:
            return "yellow"
        if current >= THRESH_BLUE_MAX:
            return "green"
        return "blue"
    if projected >= THRESH_YELLOW_MAX:
        return "red"
    if projected >= THRESH_GREEN_MAX:
        return "yellow"
    if projected >= THRESH_BLUE_MAX:
        return "green"
    return "blue"


def _evaluate(
    bucket: Bucket | None,
    key: str,
    history: list[dict],
    now_ts: float,
) -> dict | None:
    if bucket is None:
        return None
    resets_in_s = max(0.0, (bucket.resets_at - datetime.now(timezone.utc)).total_seconds())
    burn = _burn_rate_per_second(history, key, bucket.utilization, now_ts)
    if burn is None:
        projected = bucket.utilization
        forecast_available = False
    else:
        # Don't extrapolate further than MAX_PROJECTION_HORIZON_S — for the
        # weekly bucket, resets_in_s can be ~7 days right after a roll-over,
        # which makes linear projection meaningless.
        horizon_s = min(resets_in_s, MAX_PROJECTION_HORIZON_S)
        projected = bucket.utilization + burn * horizon_s
        forecast_available = True
    state = _classify(projected, bucket.utilization, resets_in_s)
    return {
        "utilization": round(bucket.utilization, 1),
        "projected": round(min(projected, PROJECTION_CAP), 1),
        "projected_capped": projected >= PROJECTION_CAP,
        "resets_at": bucket.resets_at.isoformat(),
        "resets_in_s": int(resets_in_s),
        "burn_rate_per_hour": round(burn * 3600, 2) if burn is not None else None,
        "forecast_available": forecast_available,
        "state": state,
    }


def main() -> int:
    creds = _read_credentials()
    oauth = creds.get("claudeAiOauth", {})
    token = oauth.get("accessToken")
    if not token:
        raise SystemExit("No accessToken in credentials.")

    try:
        raw = _http_get(USAGE_URL, token)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        payload = {
            "ok": False,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "error": f"HTTP {e.code}",
            "body": body[:500],
        }
        _atomic_write(STATUS_PATH, payload)
        # 401 likely means token expired — let user know in stderr.
        print(f"HTTP {e.code} from usage endpoint: {body[:200]}", file=sys.stderr)
        return 2
    except urllib.error.URLError as e:
        payload = {
            "ok": False,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "error": f"Network: {e.reason}",
        }
        _atomic_write(STATUS_PATH, payload)
        print(f"Network error: {e.reason}", file=sys.stderr)
        return 3

    now_ts = time.time()
    session_bucket = Bucket.parse(raw.get("five_hour"))
    weekly_bucket = Bucket.parse(raw.get("seven_day"))

    history = _load_history()

    session = _evaluate(session_bucket, "session_util", history, now_ts)
    weekly = _evaluate(weekly_bucket, "weekly_util", history, now_ts)

    sample = {"ts": now_ts}
    if session_bucket:
        sample["session_util"] = session_bucket.utilization
    if weekly_bucket:
        sample["weekly_util"] = weekly_bucket.utilization
    history.append(sample)
    history = history[-HISTORY_MAX:]
    _save_history(history)

    payload = {
        "ok": True,
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "subscription": creds.get("claudeAiOauth", {}).get("subscriptionType"),
        "session": session,
        "weekly": weekly,
        "raw": raw,
    }
    _atomic_write(STATUS_PATH, payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
