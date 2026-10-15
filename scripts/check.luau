-- Compile every source/test file, including modules that require Roblox services.
-- Compilation checks syntax; this does not claim Roblox API/type validation.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local count = 0
local function check(path)
	for _, name in fs.readDir(path) do
		local file = path .. "/" .. name
		if fs.isDir(file) then
			check(file)
		elseif string.match(file, "%.lua$") or string.match(file, "%.luau$") then
			local ok, err = pcall(luau.compile, fs.readFile(file))
			assert(ok, file .. ": " .. tostring(err))
			count += 1
		end
	end
end
for _, path in { "src", "demo", "tests", "scripts" } do
	check(path)
end
for _, path in { "main.client.lua", "loader.lua", "dist/MohammadAndAli.client.lua" } do
	luau.compile(fs.readFile(path))
	count += 1
end
print("Compiled " .. count .. " Luau files successfully")
