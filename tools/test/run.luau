--[[
	Unit tests + balance simulation for the pure shared modules.
	Run: lune run tools/test/run.luau
]]

local shim = require("./shim")

local passed, failed = 0, 0
local function check(name: string, cond: boolean, detail: string?)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (if detail then " :: " .. detail else ""))
	end
end

local Format = shim.shared("Util/Format")
check("short 999", Format.short(999) == "999", Format.short(999))
check("short 1234", Format.short(1234) == "1.23K", Format.short(1234))
check("short 98765", Format.short(98765) == "98.7K", Format.short(98765))
check("short 1.5e6", Format.short(1.5e6) == "1.5M", Format.short(1.5e6))
check("short 1e9", Format.short(1e9) == "1B", Format.short(1e9))
check("short 12.34", Format.short(12.34) == "12.3", Format.short(12.34))
check("commas", Format.commas(1234567) == "1,234,567", Format.commas(1234567))
check("commas small", Format.commas(12) == "12", Format.commas(12))
check("clock", Format.clock(75) == "1:15", Format.clock(75))
check("clock h", Format.clock(3725) == "1:02:05", Format.clock(3725))
check("duration", Format.duration(95) == "1m 35s", Format.duration(95))

local TableUtil = shim.shared("Util/TableUtil")
do
	local t = { a = 1 }
	TableUtil.reconcile(t, { a = 2, b = { c = 3 }, m = {} })
	check("reconcile keeps", t.a == 1)
	check("reconcile fills", t.b and t.b.c == 3)
	check("reconcile map", type(t.m) == "table")
end

local DataSchema = shim.shared("DataSchema")
-- 2026-10-12 is a Monday; 2026-10-11 a Sunday
local mon = os.time({ year = 2026, month = 10, day = 12, hour = 0, min = 30 })
local sun = os.time({ year = 2026, month = 10, day = 11, hour = 23, min = 30 })
check("week boundary on Monday", DataSchema.weekNumber(mon) == DataSchema.weekNumber(sun) + 1)

local Stations = shim.shared("Config/Stations")
local Tiers = shim.shared("Config/Tiers")
local Minigames = shim.shared("Config/Minigames")
local Formulas = shim.shared("Formulas")
local Progression = shim.shared("Config/Progression")
local Gear = shim.shared("Config/Gear")
local Missions = shim.shared("Config/Missions")
local Areas = shim.shared("Config/Areas")
local Achievements = shim.shared("Config/Achievements")
local Cosmetics = shim.shared("Config/Cosmetics")

-- every station tier exists and every pose is non-empty
for id, def in Stations.Defs do
	for _, t in def.Tiers do
		check("tier exists " .. id, Tiers.List[t] ~= nil)
	end
	check("minigame params " .. id, Minigames.Params[def.Minigame] ~= nil)
	local r = Formulas.rep(id, def.Tiers[1], 3, 0, Formulas.defaultMultipliers())
	check("rep gains " .. id, r.StatGain > 0 and r.XP >= 1, tostring(r.StatGain))
	if def.Restores then
		check("restores energy " .. id, r.EnergyDelta > 0)
	else
		check("costs energy " .. id, r.EnergyDelta < 0)
	end
end

-- achievements reference valid rewards
for _, a in Achievements.List do
	if a.Reward.Title then
		check("ach title " .. a.Id, Cosmetics.Titles[a.Reward.Title] ~= nil, a.Reward.Title)
	end
	if a.Reward.Emote then
		check("ach emote " .. a.Id, Cosmetics.Emotes[a.Reward.Emote] ~= nil, a.Reward.Emote)
	end
	if a.Reward.Aura then
		check("ach aura " .. a.Id, Cosmetics.Auras[a.Reward.Aura] ~= nil)
	end
end
for _, m in Missions.Daily do
	check("mission target " .. m.Id, Missions.target(m, 1) >= 1)
	local r = m.Reward(10)
	check("mission reward " .. m.Id, (r.Cash or 0) > 0)
end

---------------------------------------------------------------------------
-- Balance simulation: a decent player (60% perfect, 30% good, 10% ok),
-- always on the best tier they can use, 1.5 s per rep, buying gear when affordable,
-- drinking nothing, resting when out of energy (regen while idle).
---------------------------------------------------------------------------
local function bestTier(level: number, rebirths: number): number
	local best = 1
	for _, t in Tiers.List do
		if level >= t.LevelReq and rebirths >= t.RebirthReq then
			best = t.Index
		end
	end
	return best
end

local function simulate(hours: number, rebirths: number)
	local level, xp, cash = 1, 0, 0
	local stats = { Strength = 0, Endurance = 0, Speed = 0, Agility = 0, Energy = 0 }
	local energy = 100
	local gearTier = { Gloves = 0, Shoes = 0, Belt = 0, Wraps = 0, Headband = 0 }
	local t = 0
	local combo = 0
	local seed = 7
	local rng = {
		NextNumber = function(_self)
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end,
	}
	local milestones = {}
	local rotation = { "DumbbellCurl", "Treadmill", "Rower", "AgilityLadder", "BenchPress" }
	local rot = 1
	local reps = 0
	while t < hours * 3600 do
		local tier = bestTier(level, rebirths)
		local station = rotation[rot]
		local def = Stations.Defs[station]
		-- pick the highest tier this station supports that we can use
		local useTier = def.Tiers[1]
		for _, st in def.Tiers do
			if st <= tier then
				useTier = st
			end
		end
		local roll = rng:NextNumber()
		local q = if roll < 0.6 then 3 elseif roll < 0.9 then 2 else 1
		combo = if q >= 2 then combo + 1 else 0
		local m = Formulas.defaultMultipliers()
		m.Rebirths = rebirths
		m.Endurance = stats.Endurance
		local slotFor = { Strength = "Gloves", Speed = "Shoes", Endurance = "Belt", Agility = "Wraps", Energy = "Headband" }
		local gt = gearTier[slotFor[def.Stat]]
		if gt > 0 then
			m.Gear = Gear.Defs[slotFor[def.Stat] .. gt].Mult
		end
		local r = Formulas.rep(station, useTier, q, combo, m)
		local maxE = Progression.maxEnergy(stats.Energy)
		if energy + r.EnergyDelta < 0 then
			-- recover on a yoga mat (Energy station) until full
			while energy < maxE * 0.95 do
				local rr = Formulas.rep("YogaMat", 1, 3, 0, m)
				energy = math.min(maxE, energy + rr.EnergyDelta)
				stats.Energy += rr.StatGain
				xp += rr.XP
				t += 2.2
			end
		end
		energy = math.min(maxE, energy + r.EnergyDelta)
		stats[r.Stat] += r.StatGain
		xp += r.XP
		cash += r.Cash
		reps += 1
		t += 1.5
		if reps % 25 == 0 then
			rot = rot % #rotation + 1
		end
		while xp >= Progression.xpToNext(level) and level < Progression.MaxLevel do
			xp -= Progression.xpToNext(level)
			level += 1
			if level == 5 or level == 10 or level == 20 or level == 32 or level == 50 then
				table.insert(milestones, string.format("L%d at %.1f min", level, t / 60))
			end
		end
		-- buy the next gear tier when affordable
		for slot, cur in gearTier do
			local nextDef = Gear.Defs[slot .. (cur + 1)]
			if nextDef and cash >= nextDef.Price and level >= nextDef.LevelReq then
				cash -= nextDef.Price
				gearTier[slot] = cur + 1
			end
		end
	end
	local power = 0
	for _, v in stats do
		power += v
	end
	return level, power, cash, milestones, gearTier, reps
end

for _, rb in { 0, 1 } do
	local level, power, cash, ms, gear, reps = simulate(8, rb)
	print(string.format("[sim] rebirths=%d after 8h: level %d, power %s, cash %s, reps %d, gloves T%d", rb, level, Format.short(power), Format.short(cash), reps, gear.Gloves))
	print("      " .. table.concat(ms, " | "))
end

local _ = Areas
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	local process = require("@lune/process")
	process.exit(1)
end
