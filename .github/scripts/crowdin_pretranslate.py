#!/usr/bin/env python3
"""Upload the English source file to Crowdin and machine-pre-translate
any untranslated strings in every target language.

Runs in CI whenever en-US.json changes on master. The Crowdin GitHub
integration then exports the new translations back to the repository as
a pull request on its next sync.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "https://api.crowdin.com/api/v2"
TOKEN = os.environ["CROWDIN_PERSONAL_TOKEN"]
PROJECT_ID = 918275
MT_ENGINE_ID = 802885  # Crowdin Translate
SOURCE = "SlimSocial_for_Facebook/assets/lang/en-US.json"


LAST_ERROR = None


def api(path, method="GET", body=None, raw=None, filename=None, ok_errors=()):
    global LAST_ERROR
    headers = {"Authorization": "Bearer " + TOKEN}
    data = None
    if raw is not None:
        data = raw
        headers["Content-Type"] = "application/octet-stream"
        headers["Crowdin-API-FileName"] = filename
    elif body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(BASE + path, method=method, headers=headers, data=data)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:400]
            if e.code == 429 and attempt < 3:
                time.sleep(10)
                continue
            if any(s in msg for s in ok_errors):
                LAST_ERROR = msg
                print(f"note: {msg}")
                return None
            sys.exit(f"HTTP {e.code} on {method} {path}: {msg}")


files = api(f"/projects/{PROJECT_ID}/files?limit=100")["data"]
file_id = next(f["data"]["id"] for f in files if f["data"]["name"] == "en-US.json")

storage = api("/storages", "POST", raw=open(SOURCE, "rb").read(),
              filename="en-US.json")["data"]["id"]
api(f"/projects/{PROJECT_ID}/files/{file_id}", "PUT",
    body={"storageId": storage, "updateOption": "keep_translations_and_approvals"},
    ok_errors=("identical",))
print("source uploaded")

def start_pretranslation(language_ids):
    return api(f"/projects/{PROJECT_ID}/pre-translations", "POST",
               body={"languageIds": language_ids, "fileIds": [file_id],
                     "method": "mt", "engineId": MT_ENGINE_ID},
               ok_errors=("notSupportedByMT",))


targets = api(f"/projects/{PROJECT_ID}")["data"]["targetLanguageIds"]
pt = start_pretranslation(targets)
if pt is None:
    # The engine rejected some languages; drop them and retry with the rest.
    # (Unsupported ones keep their English fallback until translated by hand.)
    import re
    listing = re.search(r"Languages \[([^]]*)\]", LAST_ERROR or "")
    unsupported = set(listing.group(1).split(",")) if listing else set()
    targets = [t for t in targets if t not in unsupported]
    print(f"skipping {len(unsupported)} languages not supported by MT: "
          f"{sorted(unsupported)}")
    if not targets:
        sys.exit("no MT-supported target languages left")
    pt = start_pretranslation(targets)
    if pt is None:
        sys.exit("pre-translation request failed twice")
pt_id = pt["data"]["identifier"]
print(f"machine pre-translation started for {len(targets)} languages")

status = None
while True:
    time.sleep(10)
    status = api(f"/projects/{PROJECT_ID}/pre-translations/{pt_id}")["data"]
    print("status:", status["status"], status.get("progress", ""))
    if status["status"] in ("finished", "canceled", "failed"):
        break
if status["status"] != "finished":
    sys.exit(f"pre-translation ended with status {status['status']}")
print("done - translations reach GitHub with the next Crowdin sync PR")
