#!/usr/bin/env python3
"""Build a separate AppKit regression runner from the app's real object files.

Run after cmake --build build. Requires a logged-in macOS GUI session.
The runner uses its own bundle ID and a fresh temporary configuration directory.
"""
from pathlib import Path
import os
import plistlib
import subprocess
import sys
import shutil

root = Path(__file__).resolve().parent.parent
build = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "build"
bundle = build / "NextpadRegressionTests.app"
contents = bundle / "Contents"
binary = contents / "MacOS" / "native_tests"
binary.parent.mkdir(parents=True, exist_ok=True)
with (contents / "Info.plist").open("wb") as stream:
    plistlib.dump({"CFBundleIdentifier": "org.nextpadplusplus.regressiontests",
                  "CFBundleExecutable": "native_tests", "CFBundlePackageType": "APPL",
                  "CFBundleName": "Nextpad Regression Tests"}, stream)
resources = contents / "Resources"
if not resources.exists():
    resources.symlink_to(build / "Nextpad++.app/Contents/Resources", target_is_directory=True)
objects = sorted((build / "CMakeFiles/NotepadPlusPlusMac.dir/src").glob("*.o"))
objects = [str(path) for path in objects if path.name != "main.mm.o"]
assert objects, "Build the application first"
command = ["clang++", "-std=c++17", "-fobjc-arc", "-arch", "arm64",
           "-I" + str(root / "src"), "-I" + str(root / "scintilla/include"),
           "-I" + str(root / "scintilla/cocoa"), str(root / "tests/test_native.mm")]
command += objects + [str(build / name) for name in ("libscintilla.a", "libscintilla_core.a", "liblexilla.a")]
command += ["-framework", "Cocoa", "-framework", "QuartzCore", "-framework", "UniformTypeIdentifiers", "-o", str(binary)]
subprocess.run(command, check=True)
# A copy of the real CLI binary uses the runner's bundle ID. It must forward
# into this already-running process, so its sender path is tested end-to-end.
probe = build / "NextpadCLIProbe.app/Contents"
(probe / "MacOS").mkdir(parents=True, exist_ok=True)
shutil.copy2(build / "Nextpad++.app/Contents/MacOS/Nextpad++", probe / "MacOS/Nextpad++")
with (probe / "Info.plist").open("wb") as stream:
    plistlib.dump({"CFBundleIdentifier": "org.nextpadplusplus.regressiontests",
                  "CFBundleExecutable": "Nextpad++", "CFBundlePackageType": "APPL"}, stream)
os.environ["NEXTPAD_CLI_PROBE"] = str(probe / "MacOS/Nextpad++")
os.execv(str(binary), [str(binary)])
