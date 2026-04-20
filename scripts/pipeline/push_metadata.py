#!/usr/bin/env python3
"""push_metadata.py — push Simone metadata to App Store Connect, wait for build, submit for review.

Usage:
    push_metadata.py            # push metadata + wait for build + attach + submit
    push_metadata.py --no-submit  # everything except final submit (dry-run safe)
    push_metadata.py --metadata-only  # just push text fields, skip build/submit

Idempotent: safe to re-run. Existing version/localization/submission detected and reused.
"""
import argparse
import datetime
import pathlib
import sys
import time

import jwt
import requests

BUNDLE_ID = "com.simone.ios"
VERSION = "1.2.1"
BUILD_NUMBER = "11"
LOCALE = "en-US"
PLATFORM = "IOS"

SUBTITLE = "AI mood radio. Press play."
PROMOTIONAL = "Evolve got deeper. Music drifts across instruments, density, and energy \u2014 Simone stays fresh for hours."
DESCRIPTION = """Simone is an AI mood radio. Tune a station, press play, let it drift.

Five stations \u2014 Lo-fi, Jazz, R&B, Rock, Electronic. Each with dozens of sub-styles. Swipe up/down to browse. Tap \u25c1 \u25b7 to change station. No playlists. No repeats. No ads. Just instrumental music, generated in real time by Google's Lyria AI, for the mood you're already in.

\u2014 WHAT YOU GET \u2014

\u2022 Five always-on stations, each with its own painted visualizer.
\u2022 Evolve \u2014 music drifts across instruments, density, and energy. Never a jump cut. Stays fresh for hours. Set the pace: 30s / 1m / 5m / Lock.
\u2022 Sleep timer, background play, Now Playing artwork.
\u2022 Free with a built-in trial key. Bring your own Gemini key for unlimited use (stored in iOS Keychain, never leaves your device).

\u2014 PRIVACY \u2014

No accounts. No tracking. No analytics. Direct connection to Google's Lyria API \u2014 nothing routes through our servers, because there are no servers.

\u2014 NOTES \u2014

Internet required. Built-in trial key is shared and rate-limited. Lyria is an experimental AI model \u2014 occasional instrumental quirks are part of the territory.

A calm radio, for any hour."""
KEYWORDS = "ambient,lofi,chill,sleep,focus,study,relax,instrumental,background,generative,jazz,piano,bossa,cafe"
WHATS_NEW = """Evolve got deeper.

\u2022 Music now drifts across instruments, density, and energy \u2014 stays fresh for hours.
\u2022 \u25c1 \u25b7 on the player changes station. Play/pause resizes the cover.
\u2022 Smoother paging. No more surprise style jumps."""
COPYRIGHT = "\u00a9 2026 Simone"
REVIEW_NOTES = """Simone ships with a built-in trial Gemini API key. The app is fully functional on first launch without any setup \u2014 simply tap play on the home screen. If you'd like to test the BYOK (bring-your-own-key) flow, generate a free key at https://aistudio.google.com/apikey and paste it in Settings \u2192 API Key.

Music is generated live over WebSocket via Google's Lyria RealTime API (models/lyria-realtime-exp). An internet connection is required. No user accounts, no analytics, no tracking."""


# -------- env + auth --------
HERE = pathlib.Path(__file__).parent
env_path = HERE / ".env"
env = {}
for line in env_path.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    k, _, v = line.partition("=")
    env[k.strip()] = v.strip()

KEY_ID = env["ASC_KEY_ID"]
ISSUER_ID = env["ASC_ISSUER_ID"]
P8_PATH = pathlib.Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"
PRIVATE_KEY = P8_PATH.read_text()
API = "https://api.appstoreconnect.apple.com/v1"


def jwt_token():
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = {
        "iss": ISSUER_ID,
        "iat": int(now.timestamp()),
        "exp": int((now + datetime.timedelta(minutes=15)).timestamp()),
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, PRIVATE_KEY, algorithm="ES256",
                      headers={"kid": KEY_ID, "typ": "JWT"})


def call(method, path, **kw):
    headers = {"Authorization": f"Bearer {jwt_token()}",
               "Content-Type": "application/json"}
    if "headers" in kw:
        headers.update(kw.pop("headers"))
    url = path if path.startswith("http") else API + path
    r = requests.request(method, url, headers=headers, timeout=30, **kw)
    if r.status_code >= 400:
        sys.stderr.write(f"\nERROR {method} {path}: HTTP {r.status_code}\n{r.text}\n")
        r.raise_for_status()
    return r.json() if r.text else {}


# -------- workflow steps --------
def find_app():
    j = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")
    if not j["data"]:
        sys.exit(f"App with bundleId {BUNDLE_ID} not found")
    return j["data"][0]["id"]


def update_app_info_subtitle(app_id):
    j = call("GET", f"/apps/{app_id}/appInfos")
    editable_states = {"PREPARE_FOR_SUBMISSION", "WAITING_FOR_REVIEW",
                       "DEVELOPER_REJECTED", "REJECTED", "INVALID_BINARY",
                       "REPLACED_WITH_NEW_VERSION"}
    info = next((a for a in j["data"]
                 if a["attributes"]["state"] in editable_states), None)
    if not info:
        info = j["data"][0]
        print(f"[appInfo] no editable found — using {info['id']} state={info['attributes']['state']}")
    else:
        print(f"[appInfo] editable: {info['id']} state={info['attributes']['state']}")
    info_id = info["id"]
    j = call("GET", f"/appInfos/{info_id}/appInfoLocalizations")
    loc = next((l for l in j["data"]
                if l["attributes"]["locale"] == LOCALE), None)
    if not loc:
        sys.exit(f"No {LOCALE} appInfoLocalization on appInfo {info_id}")
    body = {"data": {"type": "appInfoLocalizations", "id": loc["id"],
                     "attributes": {"subtitle": SUBTITLE}}}
    call("PATCH", f"/appInfoLocalizations/{loc['id']}", json=body)
    print(f"[appInfo] subtitle set ({len(SUBTITLE)} chars): \"{SUBTITLE}\"")


def find_or_create_version(app_id):
    j = call("GET",
             f"/apps/{app_id}/appStoreVersions"
             f"?filter[platform]={PLATFORM}&filter[versionString]={VERSION}")
    if j["data"]:
        v = j["data"][0]
        print(f"[version] existing v{VERSION}: {v['id']} state={v['attributes']['appStoreState']}")
        return v["id"]
    print(f"[version] creating new v{VERSION}")
    body = {"data": {"type": "appStoreVersions",
                     "attributes": {"platform": PLATFORM,
                                    "versionString": VERSION,
                                    "copyright": COPYRIGHT},
                     "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    return call("POST", "/appStoreVersions", json=body)["data"]["id"]


def update_version_copyright(version_id):
    body = {"data": {"type": "appStoreVersions", "id": version_id,
                     "attributes": {"copyright": COPYRIGHT}}}
    call("PATCH", f"/appStoreVersions/{version_id}", json=body)
    print(f"[version] copyright: {COPYRIGHT}")


def update_version_localization(version_id):
    j = call("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    loc = next((l for l in j["data"]
                if l["attributes"]["locale"] == LOCALE), None)
    if not loc:
        body = {"data": {"type": "appStoreVersionLocalizations",
                         "attributes": {"locale": LOCALE},
                         "relationships": {"appStoreVersion": {"data": {
                             "type": "appStoreVersions", "id": version_id}}}}}
        loc_id = call("POST", "/appStoreVersionLocalizations",
                      json=body)["data"]["id"]
        print(f"[loc] created en-US: {loc_id}")
    else:
        loc_id = loc["id"]
        print(f"[loc] existing en-US: {loc_id}")
    body = {"data": {"type": "appStoreVersionLocalizations", "id": loc_id,
                     "attributes": {"description": DESCRIPTION,
                                    "keywords": KEYWORDS,
                                    "promotionalText": PROMOTIONAL,
                                    "whatsNew": WHATS_NEW}}}
    call("PATCH", f"/appStoreVersionLocalizations/{loc_id}", json=body)
    print(f"[loc] description {len(DESCRIPTION)}c / keywords {len(KEYWORDS)}c "
          f"/ promotional {len(PROMOTIONAL)}c / whatsNew {len(WHATS_NEW)}c")


def update_review_notes(version_id):
    j = call("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")
    if j.get("data"):
        rd_id = j["data"]["id"]
        body = {"data": {"type": "appStoreReviewDetails", "id": rd_id,
                         "attributes": {"notes": REVIEW_NOTES}}}
        call("PATCH", f"/appStoreReviewDetails/{rd_id}", json=body)
        print(f"[review] notes updated on {rd_id}")
    else:
        body = {"data": {"type": "appStoreReviewDetails",
                         "attributes": {"notes": REVIEW_NOTES},
                         "relationships": {"appStoreVersion": {"data": {
                             "type": "appStoreVersions", "id": version_id}}}}}
        rd_id = call("POST", "/appStoreReviewDetails", json=body)["data"]["id"]
        print(f"[review] notes created: {rd_id}")


def find_build(app_id, max_wait_s=1800):
    deadline = time.time() + max_wait_s
    last_state = None
    while time.time() < deadline:
        j = call("GET",
                 f"/builds?filter[app]={app_id}"
                 f"&filter[version]={BUILD_NUMBER}"
                 f"&filter[preReleaseVersion.version]={VERSION}"
                 f"&include=preReleaseVersion&limit=10&sort=-uploadedDate")
        builds = j.get("data", [])
        if builds:
            b = builds[0]
            state = b["attributes"]["processingState"]
            if state != last_state:
                print(f"[build] {b['id']} v{VERSION}({BUILD_NUMBER}) state={state}")
                last_state = state
            if state == "VALID":
                return b["id"]
            if state == "FAILED":
                sys.exit(f"Build processing FAILED — check ASC")
        else:
            if last_state != "WAITING":
                print(f"[build] not yet visible in API — waiting…")
                last_state = "WAITING"
        time.sleep(20)
    sys.exit(f"Build did not become VALID within {max_wait_s}s")


def attach_build(version_id, build_id):
    body = {"data": {"type": "builds", "id": build_id}}
    call("PATCH", f"/appStoreVersions/{version_id}/relationships/build",
         json=body)
    print(f"[attach] build {build_id} → version {version_id}")


def submit_for_review(app_id, version_id):
    j = call("GET",
             f"/reviewSubmissions?filter[app]={app_id}"
             f"&filter[platform]={PLATFORM}")
    sub = next((s for s in j["data"]
                if s["attributes"]["state"]
                in ("READY_FOR_SUBMISSION", "UNRESOLVED_ISSUES")), None)
    if sub:
        sub_id = sub["id"]
        print(f"[submit] existing draft submission: {sub_id} "
              f"state={sub['attributes']['state']}")
    else:
        body = {"data": {"type": "reviewSubmissions",
                         "attributes": {"platform": PLATFORM},
                         "relationships": {"app": {"data": {
                             "type": "apps", "id": app_id}}}}}
        sub_id = call("POST", "/reviewSubmissions", json=body)["data"]["id"]
        print(f"[submit] created submission: {sub_id}")
    j = call("GET", f"/reviewSubmissions/{sub_id}/items")
    if not j.get("data"):
        body = {"data": {"type": "reviewSubmissionItems",
                         "relationships": {
                             "reviewSubmission": {"data": {
                                 "type": "reviewSubmissions", "id": sub_id}},
                             "appStoreVersion": {"data": {
                                 "type": "appStoreVersions", "id": version_id}}}}}
        call("POST", "/reviewSubmissionItems", json=body)
        print(f"[submit] item added (appStoreVersion {version_id})")
    else:
        print(f"[submit] item already present")
    body = {"data": {"type": "reviewSubmissions", "id": sub_id,
                     "attributes": {"submitted": True}}}
    call("PATCH", f"/reviewSubmissions/{sub_id}", json=body)
    print(f"[submit] \u2705 SUBMITTED FOR REVIEW")


def cancel_review_submission(app_id):
    j = call("GET", f"/reviewSubmissions?filter[app]={app_id}&filter[platform]={PLATFORM}")
    cancellable_states = {"WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"}
    targets = [s for s in j.get("data", [])
               if s["attributes"]["state"] in cancellable_states]
    if not targets:
        print("[cancel] no in-flight submission to cancel")
        for s in j.get("data", []):
            print(f"   - {s['id']} state={s['attributes']['state']}")
        return
    for s in targets:
        sub_id = s["id"]
        state = s["attributes"]["state"]
        print(f"[cancel] PATCH {sub_id} (state was {state})")
        body = {"data": {"type": "reviewSubmissions", "id": sub_id,
                         "attributes": {"canceled": True}}}
        call("PATCH", f"/reviewSubmissions/{sub_id}", json=body)
        print(f"[cancel] \u2705 cancelled {sub_id}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--no-submit", action="store_true",
                   help="push everything but don't submit for review")
    p.add_argument("--metadata-only", action="store_true",
                   help="only push text metadata; skip build polling/attach/submit")
    p.add_argument("--cancel", action="store_true",
                   help="cancel any in-flight review submission and exit")
    args = p.parse_args()

    print(f"=== Simone v{VERSION} ({BUILD_NUMBER}) push_metadata ===\n")
    app_id = find_app()
    print(f"[app] {app_id} ({BUNDLE_ID})\n")

    if args.cancel:
        cancel_review_submission(app_id)
        return

    version_id = find_or_create_version(app_id)
    update_version_copyright(version_id)
    update_version_localization(version_id)
    update_review_notes(version_id)
    print()
    update_app_info_subtitle(app_id)
    print()

    if args.metadata_only:
        print("\u2705 metadata pushed (--metadata-only). Skipping build/attach/submit.")
        return

    build_id = find_build(app_id)
    print()
    attach_build(version_id, build_id)
    print()

    if args.no_submit:
        print("\u2705 build attached (--no-submit). Submit manually in ASC web UI.")
        return

    submit_for_review(app_id, version_id)
    print(f"\n\u2705 DONE \u2014 Simone v{VERSION} ({BUILD_NUMBER}) submitted for App Review.")


if __name__ == "__main__":
    main()
