--!strict
-- Reward bundle used by missions, achievements, daily rewards, events, codes.
export type Reward = {
	Cash: number?,
	XP: number?,
	Trophies: number?,
	RebirthTokens: number?,
	Boosts: { [string]: number }?, -- boostId -> count added to boost inventory
	Title: string?,
	Emote: string?,
	Aura: string?,
	Decor: string?,
	Companion: string?,
}
return {}
