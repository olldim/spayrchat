"""Test CI orchestration with fake tools; this does not compile an iOS app."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")
if not BASH and os.name == "nt":
    candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
    if candidate.is_file():
        BASH = str(candidate)

FAKE_TOOL = r'''
import json, os, pathlib, shutil, sys, zipfile

def path(value):
    # Native Python may receive MSYS paths from Git Bash on Windows.
    if os.name == "nt" and len(value) > 3 and value[0] == "/" and value[2] == "/":
        value = value[1].upper() + ":" + value[2:]
    return pathlib.Path(value)

tool, args = sys.argv[1], sys.argv[2:]
mode = os.environ.get("CI_TEST_MODE", "success")
with open(os.environ["CI_TEST_TRACE"], "a", encoding="utf-8") as log:
    log.write(json.dumps([tool, *args]) + "\n")

config = path(os.environ["XCODE_XCCONFIG_FILE"]).read_text(encoding="utf-8")
assert "CODE_SIGNING_ALLOWED = NO" in config

if tool == "flutter":
    assert "--config-only" in args and "--no-codesign" in args
    print("Flutter configuration diagnostic", flush=True)
    if mode == "configure-failure":
        sys.exit(23)
elif tool == "xcodebuild":
    if args == ["-version"]:
        print("Xcode 26.3 (TEST DOUBLE)")
        sys.exit(0)
    assert "CODE_SIGNING_ALLOWED=NO" in args
    assert "CODE_SIGNING_REQUIRED=NO" in args
    assert "CODE_SIGN_IDENTITY=" in args
    derived = path(args[args.index("-derivedDataPath") + 1])
    result = path(args[args.index("-resultBundlePath") + 1])
    result.mkdir(parents=True)
    (result / "diagnostic.txt").write_text("Original Xcode diagnostic", encoding="utf-8")
    if mode.startswith("xcode-failure"):
        print("REAL XCODE ERROR: test compiler failure", file=sys.stderr, flush=True)
        sys.exit(65)
    app = derived / "Build/Products/Release-iphoneos/Runner.app"
    framework = app / "Frameworks/WebRTC.framework"
    framework.mkdir(parents=True)
    (app / "Runner").write_bytes(b"TEST ONLY - NOT AN EXECUTABLE")
    (app / "Info.plist").write_text("test metadata", encoding="utf-8")
    (framework / "WebRTC").write_bytes(b"test framework")
elif tool == "ditto":
    source, target = path(args[-2]), path(args[-1])
    if "-c" in args:
        if mode == "xcode-failure-diagnostic-failure":
            sys.exit(7)
        with zipfile.ZipFile(target, "w") as archive:
            for item in source.rglob("*"):
                if item.is_file():
                    archive.write(item, item.relative_to(source.parent))
    else:
        shutil.copytree(source, target)
elif tool == "zip":
    target, source = path(args[-2]), path(args[-1])
    with zipfile.ZipFile(target, "w") as archive:
        for item in source.rglob("*"):
            if item.is_file():
                archive.write(item, item.as_posix())
else:
    raise AssertionError(tool)
'''


@unittest.skipUnless(BASH, "Install Git for Windows (Bash), or run on macOS/Linux")
class CIScriptsTest(unittest.TestCase):
    def test_bash_syntax(self):
        for script in (ROOT / "ci").glob("*.sh"):
            with self.subTest(script=script.name):
                subprocess.run([BASH, "-n", str(script)], check=True, timeout=15)

    def run_case(self, mode):
        base = ROOT / "build/ci-script-tests"
        base.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="case with spaces-", dir=base)
        self.addCleanup(temporary.cleanup)
        project = Path(temporary.name)
        shutil.copytree(ROOT / "ci", project / "ci")
        bin_dir = project / "mock-bin"
        bin_dir.mkdir()
        helper = project / "fake_tool.py"
        helper.write_text(FAKE_TOOL, encoding="utf-8")
        for tool in ["flutter", "xcodebuild", "ditto", "zip"]:
            wrapper = bin_dir / tool
            wrapper.write_text(
                '#!/usr/bin/env bash\nexec "$CI_TEST_PYTHON" "$CI_TEST_HELPER" '
                + tool + ' "$@"\n', encoding="utf-8", newline="\n"
            )
            wrapper.chmod(0o755)
        output = project / "build/ios/ipa/Spayr-unsigned.ipa"
        output.parent.mkdir(parents=True)
        output.write_bytes(b"stale IPA from a previous run")
        trace = project / "calls.jsonl"
        env = dict(os.environ)
        env.update({
            "PATH": str(bin_dir) + os.pathsep + env.get("PATH", ""),
            "CI_TEST_PYTHON": sys.executable,
            "CI_TEST_HELPER": str(helper),
            "CI_TEST_TRACE": str(trace),
            "CI_TEST_MODE": mode,
        })
        result = subprocess.run(
            [BASH, "ci/build_ios_unsigned.sh"], cwd=project, env=env,
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=45
        )
        calls = [json.loads(line) for line in trace.read_text(encoding="utf-8").splitlines()] if trace.exists() else []
        return project, output, calls, result

    def test_success_packages_the_entire_app_in_a_fresh_ipa(self):
        project, output, calls, result = self.run_case("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with zipfile.ZipFile(output) as archive:
            self.assertIsNone(archive.testzip())
            self.assertIn("Payload/Runner.app/Runner", archive.namelist())
            self.assertIn("Payload/Runner.app/Info.plist", archive.namelist())
            self.assertIn("Payload/Runner.app/Frameworks/WebRTC.framework/WebRTC", archive.namelist())
        self.assertTrue((project / "build/ci-logs/xcode-result.zip").is_file())
        self.assertTrue(any(call[0] == "zip" for call in calls))

    def test_xcode_failure_is_preserved_with_diagnostics_and_no_stale_ipa(self):
        for mode in ["xcode-failure", "xcode-failure-diagnostic-failure"]:
            with self.subTest(mode=mode):
                project, output, calls, result = self.run_case(mode)
                self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
                self.assertFalse(output.exists())
                self.assertFalse(any(call[0] == "zip" for call in calls))
                log = (project / "build/ci-logs/ios-xcodebuild.log").read_text(encoding="utf-8")
                self.assertIn("REAL XCODE ERROR", log)

    def test_flutter_configuration_failure_stops_before_xcode_compilation(self):
        project, output, calls, result = self.run_case("configure-failure")
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertFalse(output.exists())
        self.assertFalse(any(call[0] == "xcodebuild" and call[1:] != ["-version"] for call in calls))
        self.assertIn("Flutter configuration diagnostic", (project / "build/ci-logs/ios-configure.log").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
