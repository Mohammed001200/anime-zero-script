-- Adapters supply a coherent snapshot without yielding. The input trial labels
-- client observations explicitly and does not claim authoritative HP/run identity.
export type Point = { x: number, y: number, z: number }
export type Target = {
	id: string,
	name: string,
	dungeonId: string,
	runId: string,
	area: number,
	position: Point,
	health: number?,
	maxHealth: number?,
	healthKnown: boolean?,
	observedPresence: boolean?,
	alive: boolean,
}
export type Entrance = { id: string, dungeonId: string, runId: string, area: number, position: Point }
export type Snapshot = {
	ready: boolean,
	blocked: boolean?,
	paused: boolean?,
	source: string?,
	observedHUD: { [string]: string }?,
	objectiveReason: string?,
	waitReason: string?,
	manualObjective: boolean?,
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
	inputTrial: boolean?,
	snapshot: boolean?,
	attack: boolean,
	breakRubble: boolean,
	replay: boolean,
	preferences: boolean,
	movementSpeed: boolean,
}
return {}
