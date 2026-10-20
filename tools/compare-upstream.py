#!/usr/bin/env python3
"""Compare the integration manifest with a future upstream Git ref.

Evidence of commit/patch inclusion does not establish semantic feature parity.
Use the native regression runner and the report's manual checks for that.
"""
from pathlib import Path
import argparse
import json
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--ref", required=True, help="A fetched release tag or commit")
parser.add_argument("--repo", type=Path, default=Path.cwd())
parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().parents[1] / "docs/integration-manifest.json")
parser.add_argument("--github", action="store_true", help="Also inspect each PR's actual merge commit using gh")
parser.add_argument("--patches", action="store_true", help="Check stable patch IDs, including squash merges, over the last 1000 commits")
parser.add_argument("--json", action="store_true")
args = parser.parse_args()
def git(*command, data=None):
    return subprocess.run(["git", *command], cwd=args.repo, input=data, capture_output=True)
target = git("rev-parse", "--verify", args.ref + "^{commit}")
if target.returncode:
    parser.error("Fetch the release ref into --repo before comparing it.")
manifest = json.loads(args.manifest.read_text())
def present(commit):
    return bool(commit) and git("merge-base", "--is-ancestor", commit, args.ref).returncode == 0
patch_ids = set()
if args.patches:
    history = git("log", "--no-ext-diff", "--no-merges", "--format=commit %H", "--max-count=1000", "-p", args.ref)
    result = git("patch-id", "--stable", data=history.stdout)
    patch_ids = {line.split()[0] for line in result.stdout.decode().splitlines() if line.split()}
rows = []
for item in manifest["pullRequests"]:
    evidence = "not-confirmed"
    if present(item["headCommit"]):
        evidence = "commit-present"
    elif args.patches:
        diff = git("diff", "--no-ext-diff", "--no-textconv", item["patchBase"], item["headCommit"])
        if diff.returncode == 0:
            result = git("patch-id", "--stable", data=diff.stdout)
            ids = [line.split()[0] for line in result.stdout.decode().splitlines() if line.split()]
            if ids and all(value in patch_ids for value in ids):
                evidence = "patch-present"
    if evidence == "not-confirmed" and args.github:
        response = subprocess.run(["gh", "pr", "view", str(item["number"]), "--repo", manifest["upstream"],
                                   "--json", "state,mergeCommit,mergedAt"], capture_output=True, text=True)
        if response.returncode == 0:
            pr = json.loads(response.stdout)
            merge_commit = (pr.get("mergeCommit") or {}).get("oid")
            if present(merge_commit):
                evidence = "PR-merge-present"
            elif pr.get("state") == "CLOSED":
                evidence = "PR-closed-unmerged"
    rows.append({"number": item["number"], "title": item["title"], "evidence": evidence,
                 "url": item["url"], "requiresBehaviorCheck": True})
if args.json:
    print(json.dumps({"target": target.stdout.decode().strip(), "results": rows}, indent=2))
else:
    print("PR     Inclusion evidence       Change")
    for row in rows:
        print(f"#{row['number']:<5} {row['evidence']:<24} {row['title']}")
    print("\nUnconfirmed inclusion requires inspection; refactors and rewritten patches may still implement the feature.")
    print("Run behavior checks before treating an item as implemented or missing.")
