-- Focused input/controller/bundle checks. Does not run the full test suite.
local Test = require("./Test")
for _, suite in
	{
		require("./M1Input.spec"),
		require("./ObservedIntegration.spec"),
		require("./Integration.spec"),
		require("./Loader.spec"),
	}
do
	suite(Test)
end
print(string.format("\n%d focused checks passed, %d failed", Test.passed, Test.failed))
assert(Test.failed == 0, "Focused input checks failed")
