--!strict
--[[
	Robux products. Set real ids after creating them on the Creator Dashboard.
	An id of 0 disables the item in the shop ("coming soon").

	Fairness rules: nothing sold here is required to progress. VIP Club access can
	also be unlocked with Trophies; boosts can be bought with Cash at the Juice Bar.
]]

local Monetization = {}

Monetization.GamePasses = {
	VIP = { Id = 0, Name = "VIP Membership", Description = "VIP Club access, VIP title, +1 daily reward boost, exclusive emerald nameplate." },
	DoubleCash = { Id = 0, Name = "2x Cash", Description = "Double cash from training. Stats are not affected." },
}

Monetization.Products = {
	CashSmall = { Id = 0, Name = "Cash Stack", Kind = "Cash", Amount = 25000 },
	CashLarge = { Id = 0, Name = "Cash Vault", Kind = "Cash", Amount = 250000 },
	BoostPack = { Id = 0, Name = "Boost Crate", Kind = "Boosts", Boosts = { PreWorkout = 3, Protein = 3, Focus = 3 } },
}

return Monetization
