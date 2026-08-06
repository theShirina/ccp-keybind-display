from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon" / "CCPKeybindDisplay"
RELEASE_FILES = [
    "CCPKeybindDisplay.lua",
    "CCPKeybindDisplay.toc",
    "CCPKeybindDisplayOptions.lua",
    "LICENSE",
    "README.txt",
]
PUBLIC_FILES = {
    ".gitattributes",
    ".github/workflows/ci.yml",
    ".gitignore",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "LICENSE",
    "README.md",
    "addon/CCPKeybindDisplay/CCPKeybindDisplay.lua",
    "addon/CCPKeybindDisplay/CCPKeybindDisplay.toc",
    "addon/CCPKeybindDisplay/CCPKeybindDisplayOptions.lua",
    "addon/CCPKeybindDisplay/LICENSE",
    "addon/CCPKeybindDisplay/README.txt",
    "scripts/build_release.py",
    "tests/migration_harness.lua",
    "tests/runtime_harness.lua",
    "tests/ui_harness.lua",
    "tests/validate.py",
}


def run(args: list[str], cwd: Path = ROOT) -> str:
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, errors="replace")
    if result.returncode:
        detail = (result.stdout + "\n" + result.stderr).strip()
        raise AssertionError("command failed: " + " ".join(args) + ("\n" + detail if detail else ""))
    return result.stdout.strip()


def parse_toc(path: Path) -> tuple[dict[str, str], list[str]]:
    metadata: dict[str, str] = {}
    files: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("## ") and ":" in line:
            key, value = line[3:].split(":", 1)
            metadata[key.strip()] = value.strip()
        elif not line.startswith("#"):
            files.append(line.replace("\\", "/"))
    return metadata, files


def public_files() -> set[str]:
    ignored = {".git", "dist", ".lua-build", "__pycache__"}
    found: set[str] = set()
    for path in ROOT.rglob("*"):
        if not path.is_file() or any(part in ignored for part in path.relative_to(ROOT).parts):
            continue
        if path.suffix in {".pyc", ".pyo"}:
            continue
        found.add(path.relative_to(ROOT).as_posix())
    return found


def validate_public_boundary() -> None:
    found = public_files()
    assert found == PUBLIC_FILES, "unexpected public file set: " + repr(sorted(found ^ PUBLIC_FILES))
    forbidden_names = {"CCP.lua", "CCP.toc", "CCP.xml", "Bindings.xml", "microbot.tga"}
    assert not (forbidden_names & {Path(name).name for name in found}), "CCP-owned file included"
    text = "\n".join(
        (ROOT / relative).read_text(encoding="utf-8", errors="replace")
        for relative in sorted(found)
    )
    assert re.search(r"(?<![A-Za-z])[A-Z]:[\\/]", text) is None, "absolute Windows path found"
    assert re.search(r"[A-Za-z0-9._%+-]+@(gmail|hotmail|outlook)\\.[A-Za-z]+", text, re.IGNORECASE) is None, "personal email found"
    assert (ROOT / "LICENSE").read_bytes() == (ADDON / "LICENSE").read_bytes()


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate CCP Keybind Display")
    parser.add_argument("--lua", required=True)
    parser.add_argument("--luac", required=True)
    args = parser.parse_args()

    validate_public_boundary()

    toc = ADDON / "CCPKeybindDisplay.toc"
    metadata, runtime_files = parse_toc(toc)
    assert metadata.get("Interface") == "11200"
    assert metadata.get("Dependencies") == "CCP"
    assert metadata.get("SavedVariables") == "CCPKeybindDisplayDB"
    assert metadata.get("Author") == "Shirina"
    assert runtime_files == ["CCPKeybindDisplay.lua", "CCPKeybindDisplayOptions.lua"]
    for relative in runtime_files:
        assert (ADDON / relative).is_file(), relative

    addon_text = "\n".join((ADDON / relative).read_text(encoding="utf-8") for relative in runtime_files)
    assert "CCP_Settings" not in addon_text
    assert "GetNumBindings" in addon_text
    assert "GetBinding(index)" in addon_text
    assert 'string.sub(action or "", 1, 4) == "CCP_"' in addon_text
    assert "UPDATE_BINDINGS" in addon_text
    assert "SaveBindings(GetCurrentBindingSet())" in addon_text

    for relative in runtime_files:
        run([args.luac, "-p", str(ADDON / relative)])

    runtime_output = run([args.lua, str(ROOT / "tests" / "runtime_harness.lua"), str(ADDON / "CCPKeybindDisplay.lua")])
    for marker in (
        "RUNTIME_DEFAULT_DISCOVERY=PASS",
        "RUNTIME_CUSTOM_FILTERS=PASS",
        "RUNTIME_BINDING_EDITOR=PASS",
        "RUNTIME_FUTURE_CCP_REFRESH=PASS",
    ):
        assert marker in runtime_output

    migration_output = run([args.lua, str(ROOT / "tests" / "migration_harness.lua"), str(ADDON / "CCPKeybindDisplay.lua")])
    assert "RUNTIME_MIGRATION=PASS" in migration_output

    ui_output = run([
        args.lua,
        str(ROOT / "tests" / "ui_harness.lua"),
        str(ADDON / "CCPKeybindDisplay.lua"),
        str(ADDON / "CCPKeybindDisplayOptions.lua"),
    ])
    for marker in ("UI_DEFAULT_OVERLAY=PASS", "UI_VISUAL_SETTINGS=PASS", "UI_LAYOUT_OPTIONS=PASS", "UI_OPTIONS_PANEL=PASS"):
        assert marker in ui_output

    build_script = ROOT / "scripts" / "build_release.py"
    run([sys.executable, str(build_script)])
    release = ROOT / "dist" / ("CCPKeybindDisplay-" + metadata["Version"] + ".zip")
    first_zip = release.read_bytes()
    run([sys.executable, str(build_script)])
    second_zip = release.read_bytes()
    assert first_zip == second_zip, "release ZIP is not reproducible"

    expected_members = ["CCPKeybindDisplay/" + relative for relative in RELEASE_FILES]
    with zipfile.ZipFile(release, "r") as archive:
        assert archive.testzip() is None
        assert archive.namelist() == expected_members

    with tempfile.TemporaryDirectory(prefix="ccpkd-crlf-") as temporary:
        alternate_root = Path(temporary)
        alternate_addon = alternate_root / "addon" / "CCPKeybindDisplay"
        alternate_addon.mkdir(parents=True)
        for relative in RELEASE_FILES:
            payload = (ADDON / relative).read_bytes()
            payload = payload.replace(b"\r\n", b"\n").replace(b"\r", b"\n").replace(b"\n", b"\r\n")
            (alternate_addon / relative).write_bytes(payload)
        alternate_script = alternate_root / "scripts" / "build_release.py"
        alternate_script.parent.mkdir(parents=True)
        alternate_script.write_bytes(build_script.read_bytes())
        environment = os.environ.copy()
        environment["CCPKD_ROOT"] = str(alternate_root)
        result = subprocess.run([sys.executable, str(alternate_script)], capture_output=True, text=True, errors="replace", env=environment)
        assert result.returncode == 0, result.stdout + result.stderr
        assert (alternate_root / "dist" / release.name).read_bytes() == first_zip, "release changes between LF and CRLF checkouts"

    print("CCP_KEYBIND_DISPLAY_VALIDATION=PASS")
    print("PUBLIC_FILES=" + str(len(PUBLIC_FILES)))
    print("RELEASE_FILES=" + str(len(RELEASE_FILES)))
    print("SOURCE_SHA256=" + hashlib.sha256(addon_text.encode("utf-8")).hexdigest())
    print("ZIP_SHA256=" + hashlib.sha256(first_zip).hexdigest())
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AssertionError, OSError, ValueError, zipfile.BadZipFile) as exc:
        print("VALIDATION_FAILED: " + str(exc), file=sys.stderr)
        sys.exit(1)
