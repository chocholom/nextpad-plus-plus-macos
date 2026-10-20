#!/usr/bin/env python3
"""Exercise production startup and macOS file-open Apple events in an isolated app.

Requires a logged-in macOS GUI session. Build the app first. Optional file arguments
are read-only fixtures: verify their UTF-8 text reaches the editor without writing
to them. Reports contain hashes, never buffer contents.
"""
from pathlib import Path
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
import unicodedata

root = Path(__file__).resolve().parent.parent
build = root / "build"
work = Path(tempfile.mkdtemp(prefix="nextpad-file-open-")).resolve()
app = work / "NextpadFileOpenTests.app"
contents = app / "Contents"
binary = contents / "MacOS/file_open_tests"
binary.parent.mkdir(parents=True)
with (build / "Nextpad++.app/Contents/Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
info.update(CFBundleIdentifier="org.nextpadplusplus.fileopentests.run" + uuid.uuid4().hex, CFBundleExecutable=binary.name,
            CFBundleName="Nextpad File Open Tests", CFBundleDisplayName="Nextpad File Open Tests")
with (contents / "Info.plist").open("wb") as stream:
    plistlib.dump(info, stream)
(contents / "Resources").symlink_to(build / "Nextpad++.app/Contents/Resources", target_is_directory=True)
objects = sorted((build / "CMakeFiles/NotepadPlusPlusMac.dir/src").glob("*.o"))
objects = [str(path) for path in objects if path.name != "main.mm.o"]
assert objects, "Build the application first"
command = ["clang++", "-std=c++17", "-fobjc-arc", "-arch", "arm64",
           "-I" + str(root / "src"), "-I" + str(root / "scintilla/include"),
           "-I" + str(root / "scintilla/cocoa"), str(root / "tests/test_file_open.mm")]
command += objects + [str(build / name) for name in ("libscintilla.a", "libscintilla_core.a", "liblexilla.a")]
command += ["-framework", "Cocoa", "-framework", "QuartzCore", "-framework", "UniformTypeIdentifiers", "-o", str(binary)]
subprocess.run(command, check=True)
subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
report = work / "file-open-state.json"
fixture = work / "cold launch.csv"
fixture.write_bytes(b"name,value\r\nalpha,123\r\nbeta,456\r\n")
second = work / "warm launch \u017elu\u0165ou\u010dk\u00fd.txt"
second.write_text("Second file through a running app.\nP\u0159\u00edli\u0161 \u017elu\u0165ou\u010dk\u00fd k\u016f\u0148.\n")
third = work / "another file.json"
third.write_text('{"opened": true}\n')
result_path = build / "file-open-validation.json"
results = []
pid = None


def wait_for_files(paths, label, same_pid=None):
    global pid
    deadline = time.monotonic() + 12
    expected = {unicodedata.normalize("NFC", str(path)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    last = {}
    while time.monotonic() < deadline:
        if report.exists():
            last = json.loads(report.read_text())
            pid = last["pid"]
            if last.get("exceptions"):
                raise AssertionError(f"{label}: application exception: {last['exceptions']}")
            actual = {unicodedata.normalize("NFC", str(Path(item["path"]).resolve())): item["sha256"] for item in last.get("editors", []) if item["path"]}
            if last.get("finishedLaunching") and all(actual.get(path) == digest for path, digest in expected.items()):
                assert any(window["visible"] for window in last["windows"]), "No visible document window"
                assert same_pid is None or pid == same_pid, "File open unexpectedly launched another process"
                result = {"check": label, "passed": True, "pid": pid,
                          "files": [{"path": path, "sha256": digest} for path, digest in expected.items()],
                          "editorCount": len(last["editors"]), "windows": last["windows"]}
                results.append(result)
                print("PASS:", label, flush=True)
                return last
        time.sleep(0.1)
    raise AssertionError(f"{label}: timeout; last app state: {last}")


try:
    subprocess.run(["open", "-n", "-a", str(app), str(fixture), "--args", "-nosession", "-noPlugin",
                    "-settingsDir=" + str(work / "profile")], check=True)
    initial = wait_for_files([fixture], "cold Finder/Launch Services open loads exact CSV bytes")
    original_pid = pid
    count = len(initial["editors"])
    subprocess.run(["open", "-a", str(app), str(fixture)], check=True)
    time.sleep(0.4)
    duplicate = wait_for_files([fixture], "opening the same file reuses its existing tab", original_pid)
    assert len(duplicate["editors"]) == count, "Duplicate open created an extra tab"
    subprocess.run(["open", "-a", str(app), str(second), str(third)], check=True)
    wait_for_files([fixture, second, third], "warm multi-file open preserves filenames and UTF-8 text", original_pid)
    for name in sys.argv[1:]:
        path = Path(name).expanduser().resolve()
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        subprocess.run(["open", "-a", str(app), str(path)], check=True)
        wait_for_files([path], "read-only verification of supplied CSV", original_pid)
        assert hashlib.sha256(path.read_bytes()).hexdigest() == before, "Supplied file changed"
    result_path.write_text(json.dumps({"passed": True, "checks": results}, indent=2) + "\n")
finally:
    if sys.exc_info()[0] is not None:
        state = json.loads(report.read_text()) if report.exists() else {}
        result_path.write_text(json.dumps({"passed": False, "checks": results, "lastState": state}, indent=2) + "\n")
    # These are isolated test processes only. Their documents are never edited.
    matches = subprocess.run(["pgrep", "-f", str(binary)], capture_output=True, text=True)
    for value in matches.stdout.split():
        try:
            os.kill(int(value), 15)
        except ProcessLookupError:
            pass
    print("Report:", result_path, flush=True)
