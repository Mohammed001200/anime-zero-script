local Test = { passed = 0, failed = 0 }

function Test.equal(actual, expected, message)
	assert(
		actual == expected,
		(message or "Values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)
	)
end

function Test.it(name, callback)
	local ok, err = xpcall(callback, debug.traceback)
	if ok then
		Test.passed += 1
		print("  PASS " .. name)
	else
		Test.failed += 1
		print("  FAIL " .. name .. "\n" .. tostring(err))
	end
end

return Test
