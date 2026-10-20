#!/usr/bin/env python3
"""Package the validated universal app with its own application/settings identity."""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--build", type=Path, default=Path("build"))
parser.add_argument("--output", type=Path, default=Path(".."))
parser.add_argument("--build-number", default="2026.10.20")
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
app = output / "Nextpad++ Integration.app"
archive = output / "Nextpad++-Integration-universal.zip"
if app.exists() or archive.exists():
    parser.error("The output already contains a package; choose a new output directory.")
shutil.copytree(args.build / "Nextpad++.app", app, symlinks=True)
info_path = app / "Contents/Info.plist"
with info_path.open("rb") as stream:
    info = plistlib.load(stream)
source_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
info.update({"CFBundleIdentifier": "org.nextpadplusplus.mac.integration",
             "CFBundleName": "Nextpad++ Integration",
             "CFBundleDisplayName": "Nextpad++ Integration",
             "CFBundleVersion": args.build_number,
             "CFBundleShortVersionString": "1.1.2",
             "NextpadSettingsProfile": "Nextpad++ Integration",
             "NextpadIntegrationSourceCommit": source_commit})
with info_path.open("wb") as stream:
    plistlib.dump(info, stream)
subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True)
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).strip().split()
if set(architectures) != {"arm64", "x86_64"}:
    raise RuntimeError(f"Expected a universal binary, got {architectures}")
subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)], check=True)
metadata = {"archive": archive.name, "app": app.name, "architectures": architectures,
            "sourceCommit": source_commit, "buildNumber": args.build_number,
            "bundleIdentifier": info["CFBundleIdentifier"],
            "settingsProfile": info["NextpadSettingsProfile"],
            "signing": "ad-hoc; not notarized",
            "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
(output / "artifact.json").write_text(json.dumps(metadata, indent=2) + "\n")
print(json.dumps(metadata, indent=2))
