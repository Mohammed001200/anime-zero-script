-- Rojo maps this LocalScript to StarterPlayerScripts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packageRoot = ReplicatedStorage:WaitForChild("MohammadAndAli", 15)
assert(packageRoot, "MohammadAndAli package is missing; check the Rojo project mapping")
require(packageRoot.Bootstrap).start()
