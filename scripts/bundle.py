"""Build a deterministic, readable, single-file Roblox client. Python stdlib only.

This deliberately supports this project's static requires, not arbitrary Luau.
Unknown requires or leftover script references fail the build rather than guessing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRY = "Bootstrap"


class BuildError(ValueError):
    pass


def tokens(source: str):
    """Yield (text, start, end, kind), excluding whitespace and comments."""
    index = 0
    while index < len(source):
        start = index
        char = source[index]
        if char.isspace():
            index += 1
            continue
        comment = source.startswith("--", index)
        long_start = index + 2 if comment else index
        long = re.match(r"\[(=*)\[", source[long_start:])
        if long:
            end = source.find("]" + long.group(1) + "]", long_start + len(long.group()))
            if end < 0:
                raise BuildError("Unterminated long string/comment")
            index = end + len(long.group(1)) + 2
            if not comment:
                yield source[start:index], start, index, "string"
            continue
        if comment:
            end = source.find("\n", index)
            index = len(source) if end < 0 else end + 1
            continue
        if char in "\"'":
            index += 1
            while index < len(source):
                if source[index] == "\\":
                    index += 2
                elif source[index] == char:
                    index += 1
                    break
                else:
                    index += 1
            else:
                raise BuildError("Unterminated quoted string")
            yield source[start:index], start, index, "string"
            continue
        if char == "`":
            # Interpolated strings could contain dynamic dependencies. Reject them
            # until the builder explicitly supports their expression grammar.
            raise BuildError("Interpolated strings are not supported by this bundler")
        match = re.match(r"[A-Za-z_][A-Za-z_0-9]*", source[index:])
        if match:
            index += len(match.group())
            yield source[start:index], start, index, "identifier"
        else:
            index += 1
            yield char, start, index, "symbol"


def script_path(key: str, expression: list[str]) -> str:
    if not expression or expression[0] != "script":
        raise BuildError(f"{key}: unsupported require expression")
    parts = key.split("/")
    if len(expression) % 2 != 1:
        raise BuildError(f"{key}: malformed script path")
    for index in range(1, len(expression), 2):
        if expression[index] != "." or not re.fullmatch(r"[A-Za-z_]\w*", expression[index + 1]):
            raise BuildError(f"{key}: unsupported script path")
        child = expression[index + 1]
        if child == "Parent":
            if not parts:
                raise BuildError(f"{key}: require escapes src/")
            parts.pop()
        else:
            parts.append(child)
    return "/".join(parts)


def resolve(key: str, expression: list[str]) -> str:
    if expression[:3] == ["if", "script", "then"]:
        try:
            otherwise = expression.index("else")
        except ValueError as error:
            raise BuildError(f"{key}: conditional require has no else") from error
        target = script_path(key, expression[3:otherwise])
        fallback = expression[otherwise + 1:]
        if len(fallback) != 1 or not re.fullmatch(r'''["'][./A-Za-z_0-9-]+["']''', fallback[0]):
            raise BuildError(f"{key}: fallback must be a static relative path")
        relative = fallback[0][1:-1]
        if not relative.startswith("."):
            raise BuildError(f"{key}: fallback must be relative")
        other = posixpath.normpath(posixpath.join(posixpath.dirname(key), relative))
        if other != target:
            raise BuildError(f"{key}: Roblox/Lune dependency mismatch: {target} != {other}")
        return target
    return script_path(key, expression)


def rewrite(key: str, source: str, available: set[str]):
    stream = list(tokens(source))
    replacements, dependencies = [], set()
    index = 0
    while index < len(stream):
        token, start, _, kind = stream[index]
        if kind != "identifier" or token != "require":
            index += 1
            continue
        if index + 1 >= len(stream) or stream[index + 1][0] != "(":
            raise BuildError(f"{key}: dynamic require references are unsupported")
        end, depth = index + 2, 1
        while end < len(stream):
            if stream[end][0] == "(":
                depth += 1
            elif stream[end][0] == ")":
                depth -= 1
                if depth == 0:
                    break
            end += 1
        if depth:
            raise BuildError(f"{key}: unclosed require call")
        target = resolve(key, [item[0] for item in stream[index + 2:end]])
        if target not in available:
            raise BuildError(f"{key}: missing dependency {target}")
        replacements.append((start, stream[end][2], "__require(" + json.dumps(target) + ")"))
        dependencies.add(target)
        index = end + 1
    for start, end, replacement in reversed(replacements):
        source = source[:start] + replacement + source[end:]
    if any(item[0] == "script" and item[3] == "identifier" for item in tokens(source)):
        raise BuildError(f"{key}: leftover script reference would break standalone execution")
    return source, sorted(dependencies)


def dependency_order(graph: dict[str, list[str]]) -> list[str]:
    done, visiting, order = set(), [], []

    def visit(key):
        if key in visiting:
            raise BuildError("Dependency cycle: " + " -> ".join(visiting + [key]))
        if key in done:
            return
        if key not in graph:
            raise BuildError(f"Missing module {key}")
        visiting.append(key)
        for child in graph[key]:
            visit(child)
        visiting.pop()
        done.add(key)
        order.append(key)

    for key in sorted(graph):
        visit(key)
    return order


RUNTIME = '''
local __cache, __loading = {}, {}
local function __trace(message)
    return debug.traceback(tostring(message), 2)
end
local function __require(id)
    if __cache[id] ~= nil then return __cache[id] end
    if __loading[id] then error("Bundled dependency cycle at " .. id, 0) end
    local factory = __factories[id]
    if not factory then error("Bundled module missing: " .. id, 0) end
    __loading[id] = true
    local ok, value = xpcall(function() return factory(__require) end, __trace)
    __loading[id] = nil
    if not ok then error("Module " .. id .. " failed:\\n" .. tostring(value), 0) end
    if value == nil then error("Bundled module returned nil: " .. id, 0) end
    __cache[id] = value
    return value
end
local ok, result = xpcall(function()
    if game == nil or Instance == nil then
        error("This bundle requires a Roblox client runtime. It cannot open a GUI in plain Lua/Lune.", 0)
    end
    local runService = game:GetService("RunService")
    if not runService:IsClient() then
        error("This bundle requires client execution, not a server Script or server loadstring.", 0)
    end
    return __require("Bootstrap").start()
end, __trace)
if not ok then
    local message = "[Mohammad & Ali] Startup failed:\\n" .. tostring(result)
    warn(message)
    error(message, 0)
end
return result
'''


def artifacts(root: Path) -> dict[Path, str]:
    files = sorted((root / "src").rglob("*.lua"))
    files += sorted((root / "src").rglob("*.luau"))
    sources = {}
    paths = {}
    for path in files:
        key = path.relative_to(root / "src").with_suffix("").as_posix()
        if key in sources:
            raise BuildError(f"Duplicate module key {key}")
        sources[key] = path.read_text(encoding="utf-8-sig")
        paths[key] = path.relative_to(root).as_posix()
    if ENTRY not in sources:
        raise BuildError("Missing Bootstrap entry point")
    rewritten, graph = {}, {}
    for key, source in sources.items():
        rewritten[key], graph[key] = rewrite(key, source, set(sources))
    order = dependency_order(graph)
    fingerprint = hashlib.sha256(json.dumps(sources, sort_keys=True).encode()).hexdigest()
    header = (
        "--!nocheck\n-- GENERATED by python scripts/bundle.py. Edit src/, then rebuild.\n"
        "-- Mohammad and Ali Script | self-contained Roblox client | no secondary downloads\n"
        "-- Live Anime Zero integration is NOT verified or configured.\n"
        f"-- Source fingerprint: {fingerprint}\n"
        f"-- Embedded modules: {len(sources)}; dependency graph: dist/manifest.json\n"
        "local __factories = {}\n"
    )
    sections = [header]
    for key in order:
        sections.append(f'\n-- Module: {paths[key]}\n__factories[{json.dumps(key)}] = function(__require)\n')
        sections.append("\n".join("\t" + line if line else "" for line in rewritten[key].splitlines()))
        sections.append("\nend\n")
    bundle = "".join(sections) + RUNTIME
    manifest = {
        "format": 1, "entry": ENTRY, "moduleCount": len(sources),
        "sourceFingerprint": fingerprint,
        "bundleSha256": hashlib.sha256(bundle.encode("utf-8")).hexdigest(),
        "dependencyOrder": order,
        "modules": {key: {"source": paths[key], "dependencies": graph[key],
                          "sourceSha256": hashlib.sha256(sources[key].encode()).hexdigest()}
                    for key in sorted(sources)},
        "excluded": ["demo/Dungeon.server.lua", "tests/", "scripts/", "main.client.lua"],
    }
    return {
        root / "loader.lua": bundle,
        root / "dist/MohammadAndAli.client.lua": bundle,
        root / "dist/manifest.json": json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if tracked distribution differs from src/")
    args = parser.parse_args()
    try:
        outputs = artifacts(ROOT)
        for path, content in outputs.items():
            if args.check:
                if not path.is_file() or path.read_bytes() != content.encode("utf-8"):
                    raise BuildError(f"Stale/missing {path.relative_to(ROOT)}; run python scripts/bundle.py")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content.encode("utf-8"))
    except (BuildError, OSError) as error:
        parser.exit(1, f"Bundle error: {error}\n")
    print("Distribution is current" if args.check else "Built loader.lua, standalone client, and dependency manifest")


if __name__ == "__main__":
    main()
