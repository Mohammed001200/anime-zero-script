"""Dependency/build regressions. No Roblox or third-party Python packages needed."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("bundle", ROOT / "scripts/bundle.py")
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class BundleTests(unittest.TestCase):
    def test_complete_project_dependencies_resolve_in_order(self):
        outputs = bundle.artifacts(ROOT)
        manifest = json.loads(outputs[ROOT / "dist/manifest.json"])
        order = manifest["dependencyOrder"]
        self.assertEqual(len(order), len(list((ROOT / "src").rglob("*.lua"))))
        for key, details in manifest["modules"].items():
            for dependency in details["dependencies"]:
                self.assertLess(order.index(dependency), order.index(key))
        self.assertEqual(outputs[ROOT / "loader.lua"], outputs[ROOT / "dist/MohammadAndAli.client.lua"])

    def test_comments_and_strings_are_not_rewritten(self):
        source = '''-- require(script.Parent.Missing)
local text = "require(script.Parent.Missing)"
--[=[ require(script.Parent.Missing) ]=]
local text2 = [=[require(script.Parent.Missing)]=]
return require(if script then script.Parent.B else "./B")'''
        result, dependencies = bundle.rewrite("A", source, {"A", "B"})
        self.assertEqual(dependencies, ["B"])
        self.assertIn('return __require("B")', result)
        self.assertIn('local text = "require(script.Parent.Missing)"', result)

    def test_missing_module_is_a_build_error(self):
        with self.assertRaisesRegex(bundle.BuildError, "missing dependency"):
            bundle.rewrite("A", "return require(script.Parent.Missing)", {"A"})

    def test_dynamic_require_and_leftover_script_fail(self):
        for source in ("return require(path)", "local root = script.Parent; return {}"):
            with self.assertRaises(bundle.BuildError):
                bundle.rewrite("A", source, {"A"})

    def test_roblox_and_lune_dependency_disagreement_fails(self):
        with self.assertRaisesRegex(bundle.BuildError, "mismatch"):
            bundle.rewrite("A", 'return require(if script then script.Parent.B else "./C")', {"A", "B", "C"})

    def test_cycle_has_an_actionable_error(self):
        with self.assertRaisesRegex(bundle.BuildError, "A -> B -> A"):
            bundle.dependency_order({"A": ["B"], "B": ["A"]})

    def test_build_is_deterministic(self):
        self.assertEqual(bundle.artifacts(ROOT), bundle.artifacts(ROOT))

    def test_duplicate_module_keys_and_missing_entry_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "src").mkdir()
            with self.assertRaisesRegex(bundle.BuildError, "Missing Bootstrap"):
                bundle.artifacts(root)
            (root / "src/Bootstrap.lua").write_text("return {}", encoding="utf-8")
            (root / "src/Bootstrap.luau").write_text("return {}", encoding="utf-8")
            with self.assertRaisesRegex(bundle.BuildError, "Duplicate module"):
                bundle.artifacts(root)


if __name__ == "__main__":
    unittest.main()
