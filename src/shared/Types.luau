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

-- Round

export type Role = "Murderer" | "Detective" | "Innocent"

export type RoundPhase = "Intermission" | "Teleporting" | "RoleReveal" | "InProgress" | "PostRound"

export type PostRoundResult = "MurdererWin" | "DetectiveWin" | "PassengersWin"

export type EliminatedEntry = {
	Name: string,
	Role: Role,
	UserId: number,
}

return Types
