--!strict
export type CurrencyId = "Cash" | "Trophies" | "RebirthTokens"
export type Cost = { Currency: CurrencyId, Amount: number }

local Currency = {}
Currency.Defs = {
	Cash = { Name = "Cash", Short = "$", Color = Color3.fromRGB(122, 214, 120) },
	Trophies = { Name = "Trophies", Short = "TR", Color = Color3.fromRGB(240, 186, 80) },
	RebirthTokens = { Name = "Rebirth Tokens", Short = "RT", Color = Color3.fromRGB(196, 140, 255) },
}
return Currency
