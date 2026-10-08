#!/usr/bin/env python3
"""Block a release while a fresh or confirmed bug report is untriaged.

A release must not go out while users are reporting a bug that nobody has
looked at. This script asks GitHub for open issues, except those labelled as
a feature request, wontfix, duplicate or stale, and fails when one
of them:
  - carries the `regression` label, or
  - has at least --min-reporters distinct people on it (the author plus
    everyone who commented, the repository owner excluded), or
  - was opened in the last --fresh-days days and has no `triaged` label.

To clear an issue: fix it, or read it and add the `triaged` label (the bug is
real but does not stop the release), or pass --allow <n> for this run only.
A `triaged` label does not clear the first two rules.

Usage:
  scripts/release_gate.py                      # check now
  scripts/release_gate.py --allow 375          # accept a known issue this run
  scripts/release_gate.py --as-of 2026-09-25T11:00:00Z   # replay a past date

--as-of reads labels as they are now, not as they were then. A time without a
timezone is UTC.

Exit code 0 = clear to release, 1 = blocked, 2 = could not check.
Needs the `gh` CLI, signed in.
"""
import argparse
import datetime as dt
import json
import subprocess
import sys

REPO = "rignaneseleo/SlimSocial-for-Facebook"
OWNER = "rignaneseleo"
# Issues with any of these labels are not bug reports. Unlabelled issues count:
# users do not always pick the bug template.
NOT_BUGS = ("FEAT", "wontfix", "duplicate", "stale")


def gh(*args):
    out = subprocess.run(["gh", *args], capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or "gh failed")
    return json.loads(out.stdout)


def parse_time(value):
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def open_at(issue, as_of):
    """Whether the issue was open at `as_of`."""
    if parse_time(issue["createdAt"]) > as_of:
        return False
    closed = issue.get("closedAt")
    return not closed or parse_time(closed) > as_of


def reporters(issue, as_of):
    """Distinct people on the issue at `as_of`, the owner excluded."""
    people = set()
    if issue["author"]["login"] != OWNER:
        people.add(issue["author"]["login"])
    for comment in issue.get("comments", []):
        if parse_time(comment["createdAt"]) > as_of:
            continue
        login = comment["author"]["login"]
        if login != OWNER:
            people.add(login)
    return people


def blocking_reason(issue, as_of, args):
    """Why this issue blocks the release, or None."""
    labels = {label["name"] for label in issue["labels"]}
    people = reporters(issue, as_of)
    age = as_of - parse_time(issue["createdAt"])
    if "regression" in labels:
        return "labelled regression"
    if len(people) >= args.min_reporters:
        return f"{len(people)} people report it"
    if age <= dt.timedelta(days=args.fresh_days) and "triaged" not in labels:
        return f"opened {age.days} day(s) ago, not triaged"
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--min-reporters", type=int, default=3,
                    help="block when this many distinct people are on one "
                         "issue (default 3: the author and two confirmations)")
    ap.add_argument("--fresh-days", type=int, default=7,
                    help="an untriaged issue younger than this blocks "
                         "(default 7)")
    ap.add_argument("--days", type=int, default=60,
                    help="only look at issues created in the last N days")
    ap.add_argument("--allow", type=int, action="append", default=[],
                    help="issue number to accept for this run (repeatable)")
    ap.add_argument("--as-of", help="replay the check at this ISO time")
    args = ap.parse_args()

    now = dt.datetime.now(dt.timezone.utc)
    as_of = parse_time(args.as_of) if args.as_of else now
    since = (as_of - dt.timedelta(days=args.days)).date().isoformat()

    search = " ".join([f"created:>={since}"]
                      + [f"-label:{label}" for label in NOT_BUGS])
    try:
        found = gh("issue", "list", "-R", REPO, "--state", "all",
                   "--limit", "300", "--search", search,
                   "--json", "number,title,author,createdAt,closedAt,"
                             "labels,comments,url")
        issues = {issue["number"]: issue for issue in found}
    except (RuntimeError, json.JSONDecodeError) as err:
        print(f"release gate: could not read issues: {err}", file=sys.stderr)
        return 2

    blockers = []
    for issue in sorted(issues.values(), key=lambda i: i["number"]):
        if not open_at(issue, as_of) or issue["number"] in args.allow:
            continue
        reason = blocking_reason(issue, as_of, args)
        if reason:
            blockers.append((issue, reason))

    if not blockers:
        print(f"release gate: clear ({len(issues)} bug issues checked, "
              f"as of {as_of.isoformat(timespec='minutes')})")
        return 0

    print("release gate: BLOCKED. Fix each issue, or read it and add the "
          "`triaged` label, or pass --allow <n>:")
    for issue, reason in blockers:
        print(f"  #{issue['number']} {issue['title']} ({reason})\n"
              f"      {issue['url']}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
