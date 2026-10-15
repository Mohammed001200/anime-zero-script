-- An adapter must provide one coherent, authoritative snapshot without yielding.
export type Point = { x: number, y: number, z: number }
export type Target = {
	id: string,
	name: string,
	dungeonId: string,
	runId: string,
	area: number,
	position: Point,
	health: number,
	alive: boolean,
}
export type Entrance = { id: string, dungeonId: string, runId: string, area: number, position: Point }
export type Snapshot = {
	ready: boolean,
	blocked: boolean?,
	reason: string?,
	dungeonId: string,
	runId: string,
	area: number,
	totalAreas: number,
	completed: boolean,
	areaCleared: boolean,
	spawnPending: boolean,
	characterReady: boolean,
	characterId: string,
	position: Point,
	npcs: { Target },
	rubble: { Target },
	nextEntrance: Entrance?,
}
export type Capabilities = {
	snapshot: boolean?,
	attack: boolean,
	breakRubble: boolean,
	replay: boolean,
	preferences: boolean,
	movementSpeed: boolean,
}
return {}
