#!/usr/bin/env python3
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "FamilyTracker")
IGNORE_DIRS = {"DerivedData", ".build", "Pods", "Carthage", "build", "Build", "xcuserdata"}

TYPE_RE = re.compile(r"^\s*(public\s+|internal\s+|open\s+)?(final\s+)?(class|struct|enum|actor|protocol|extension)\s+")
MEMBER_RE = re.compile(r"^\s*(public\s+|internal\s+)?(static\s+|class\s+)?(let|var|func|init|subscript)\b")
MULTILINE_RE = re.compile(r"^\s*(public\s+|internal\s+)?(static\s+|class\s+)?(func|init|subscript)\b")
ATTR_RE = re.compile(r"^\s*@(MainActor|Observable|Published|objc|available|Sendable)\b")
PRIVATE_RE = re.compile(r"^\s*(private|fileprivate)\b")


def interesting_swift_files(root: Path):
    for path in sorted(root.rglob("*.swift")):
        if any(part in IGNORE_DIRS for part in path.parts):
            continue
        yield path


def brace_delta(line: str) -> int:
    stripped = re.sub(r'".*?"', '""', line)
    return stripped.count("{") - stripped.count("}")


def should_capture(line: str, depth: int) -> bool:
    stripped = line.strip()
    if PRIVATE_RE.match(line) or " private " in f" {stripped} " or stripped.startswith("@objc private"):
        return False
    if TYPE_RE.match(line):
        return True
    if depth <= 1 and MEMBER_RE.match(line):
        return True
    if depth <= 1 and ATTR_RE.match(line):
        return True
    return False


def clean_signature(line: str) -> str:
    line = line.rstrip()
    if "{" in line:
        line = line.split("{", 1)[0].rstrip()
    return line


def skeleton(path: Path):
    output = []
    pending = []
    depth = 0

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        stripped = line.strip()

        if not stripped or stripped.startswith("//"):
            depth += brace_delta(line)
            continue

        if pending:
            pending.append(clean_signature(line))
            if "{" in line or stripped.endswith(")") or stripped.endswith("-> Void"):
                output.extend(pending)
                pending = []
            depth += brace_delta(line)
            continue

        if should_capture(line, depth):
            sig = clean_signature(line)
            if MULTILINE_RE.match(line) and "{" not in line and not stripped.endswith(")") and not stripped.endswith("}"):
                pending.append(sig)
            else:
                output.append(sig)

        depth += brace_delta(line)
        depth = max(depth, 0)

    if pending:
        output.extend(pending)

    return output


def main():
    if not ROOT.is_dir():
        print(f"Directory not found: {ROOT}", file=sys.stderr)
        return 1

    for file in interesting_swift_files(ROOT):
        lines = skeleton(file)
        if not lines:
            continue
        print(f"===== {file} =====")
        for line in lines:
            print(line)
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
