local Test = require("./Test")
local suites = {
	require("./StateMachine.spec"),
	require("./Targeting.spec"),
	require("./Progression.spec"),
	require("./Movement.spec"),
	require("./Loader.spec"),
}
for _, suite in suites do
	suite(Test)
end
print(string.format("\n%d passed, %d failed", Test.passed, Test.failed))
assert(Test.failed == 0, "Test suite failed")
