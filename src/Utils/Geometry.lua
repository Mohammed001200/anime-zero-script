-- Plain point records keep the decision engine runnable outside Roblox.
local Geometry = {}
export type Point = { x: number, y: number, z: number }

function Geometry.finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Geometry.valid(point)
	return type(point) == "table"
		and Geometry.finite(point.x)
		and Geometry.finite(point.y)
		and Geometry.finite(point.z)
end

function Geometry.distance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

return Geometry
