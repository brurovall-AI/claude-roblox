--!strict
--[[
	Server-wide competitions rotate automatically. Each event has a short
	sign-up window (join from the HUD banner or by walking onto the event pad),
	a live phase and a results phase. Scores are skill + progression based.

	Location: map models/parts tagged "EventSpot" with attribute EventId mark
	where an event happens (lanes, stage, course start). RepRush is gym-wide.
]]

export type EventDef = {
	Id: string,
	Name: string,
	Tagline: string,
	Location: string, -- area id (for "head to" hints)
	SignupTime: number,
	Duration: number,
	MinPlayers: number,
	MaxPlayers: number,
	ScoreLabel: string,
	LowerIsBetter: boolean,
}

local Competitions = {}

Competitions.Events = {
	RepRush = { Id = "RepRush", Name = "Rep Rush", Tagline = "Most Perfect reps in 2 minutes. Any machine counts.", Location = "Lobby", SignupTime = 30, Duration = 120, MinPlayers = 1, MaxPlayers = 50, ScoreLabel = "Perfect reps", LowerIsBetter = false },
	MaxLift = { Id = "MaxLift", Name = "Max Lift", Tagline = "Five attempts on the Arena platform. Strength + timing.", Location = "Arena", SignupTime = 40, Duration = 75, MinPlayers = 1, MaxPlayers = 8, ScoreLabel = "kg lifted", LowerIsBetter = false },
	SprintRace = { Id = "SprintRace", Name = "Sprint Race", Tagline = "100-stud dash on the Yard lanes. Speed decides.", Location = "Yard", SignupTime = 40, Duration = 45, MinPlayers = 1, MaxPlayers = 6, ScoreLabel = "seconds", LowerIsBetter = true },
	EnduranceHold = { Id = "EnduranceHold", Name = "Endurance Hold", Tagline = "Hold the rhythm as long as you can. Last one standing.", Location = "Arena", SignupTime = 40, Duration = 240, MinPlayers = 1, MaxPlayers = 12, ScoreLabel = "seconds held", LowerIsBetter = false },
	ObstacleDash = { Id = "ObstacleDash", Name = "Obstacle Dash", Tagline = "Race the Yard obstacle course. Agility decides.", Location = "Yard", SignupTime = 40, Duration = 120, MinPlayers = 1, MaxPlayers = 8, ScoreLabel = "seconds", LowerIsBetter = true },
} :: { [string]: EventDef }

Competitions.Rotation = { "RepRush", "MaxLift", "SprintRace", "RepRush", "EnduranceHold", "ObstacleDash" }
Competitions.Gap = 90 -- seconds of downtime between events

-- Placement rewards (index = place). Cash is scaled by level on the server.
Competitions.PlaceTrophies = { 60, 40, 25 }
Competitions.ParticipationTrophies = 8
Competitions.PlaceCash = { 3000, 2000, 1200 }
Competitions.ParticipationCash = 400

-- Arm-wrestling (1v1 duels at Arena tables) and the bracket tournament.
Competitions.Duel = {
	PushPerTap = 0.035, -- base bar movement per graded tap (scaled by strength ratio)
	MaxDuration = 30,
	WinnerTrophies = 10,
	LoserTrophies = 2,
	ChallengeTimeout = 20,
}

Competitions.Tournament = {
	Interval = 15 * 60, -- seconds between tournaments
	SignupTime = 60,
	MinPlayers = 4,
	MaxPlayers = 8,
	Trophies = { 250, 120, 60, 60 }, -- 1st, 2nd, semifinalists
}

return Competitions
