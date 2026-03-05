local Types = {}

-- World Scroll

export type LaneConfig = {
	ModelName: string,
	Direction: number,
	PoolSize: number?,
	CenterPool: number?,
}

export type SpeedSegment = {
	StartSpeed: number,
	EndSpeed: number,
	StartTime: number,
	Duration: number,
}

export type ScrollState = {
	BaseDistance: number,
	BaseTime: number,
	Speed: number,
	Transition: SpeedSegment?,
}

export type SceneryPhase = "Looping" | "TunnelDraining" | "TunnelIncoming" | "SceneStopping" | "SceneStopped" | "SceneResuming"

return Types
