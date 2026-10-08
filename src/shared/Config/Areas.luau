--!strict
--[[
	Gym areas. Each area has a volume in the map (Map.Zones parts with matching
	AreaId) and optional gates (Map models tagged "AreaGate" with AreaId).
	Access:
	  "Open"  always accessible
	  "Level" requires LevelReq (and RebirthReq)
	  "VIP"   VIP game pass OR TrophyCost trophies spent once (no pay-to-win lock-out)
]]

export type AreaDef = {
	Id: string,
	Name: string,
	Subtitle: string,
	Floor: string, -- "B1" | "G" | "L2" | "Roof" | "Yard" | "Annex"
	Access: "Open" | "Level" | "VIP",
	LevelReq: number,
	RebirthReq: number,
	TrophyCost: number?,
	Accent: Color3,
	Ambience: string, -- Config/Audio ambience preset
	Order: number,
}

local A: { [string]: AreaDef } = {}
local order = 0
local function def(d: any)
	order += 1
	d.Order = order
	d.RebirthReq = d.RebirthReq or 0
	d.LevelReq = d.LevelReq or 1
	A[d.Id] = d :: AreaDef
end

def({ Id = "Lobby", Name = "Reception & Atrium", Subtitle = "Welcome to Ironhaven", Floor = "G", Access = "Open", Accent = Color3.fromRGB(214, 168, 96), Ambience = "Lobby" })
def({ Id = "Lounge", Name = "The Lounge", Subtitle = "Juice bar · photo wall · hangout", Floor = "G", Access = "Open", Accent = Color3.fromRGB(118, 160, 120), Ambience = "Lounge" })
def({ Id = "Lockers", Name = "Locker Rooms", Subtitle = "Gear up", Floor = "G", Access = "Open", Accent = Color3.fromRGB(199, 98, 62), Ambience = "Lockers" })
def({ Id = "Beginner", Name = "Beginner Studio", Subtitle = "Every legend starts here", Floor = "G", Access = "Level", LevelReq = 1, Accent = Color3.fromRGB(242, 140, 90), Ambience = "Studio" })
def({ Id = "Cardio", Name = "Cardio Deck", Subtitle = "Treadmills · bikes · rowers", Floor = "G", Access = "Level", LevelReq = 4, Accent = Color3.fromRGB(44, 150, 140), Ambience = "Cardio" })
def({ Id = "FreeWeights", Name = "Free Weights", Subtitle = "Dumbbells · benches", Floor = "G", Access = "Level", LevelReq = 6, Accent = Color3.fromRGB(64, 112, 86), Ambience = "Weights" })
def({ Id = "MainHall", Name = "Main Training Hall", Subtitle = "Machines · functional turf", Floor = "G", Access = "Level", LevelReq = 9, Accent = Color3.fromRGB(226, 166, 52), Ambience = "Hall" })
def({ Id = "Yard", Name = "The Yard", Subtitle = "Track · sprints · obstacles · strongman", Floor = "Yard", Access = "Level", LevelReq = 12, Accent = Color3.fromRGB(181, 83, 60), Ambience = "Outdoor" })
def({ Id = "Cables", Name = "Cable & Machine Room", Subtitle = "Precision strength", Floor = "G", Access = "Level", LevelReq = 15, Accent = Color3.fromRGB(110, 128, 146), Ambience = "Weights" })
def({ Id = "Concourse", Name = "Lower Concourse", Subtitle = "Boxing · recovery · private suites", Floor = "B1", Access = "Level", LevelReq = 18, Accent = Color3.fromRGB(160, 120, 90), Ambience = "Concourse" })
def({ Id = "Boxing", Name = "Boxing Gym", Subtitle = "Bags · ring · footwork", Floor = "B1", Access = "Level", LevelReq = 18, Accent = Color3.fromRGB(178, 58, 46), Ambience = "Boxing" })
def({ Id = "Recovery", Name = "Recovery Studio", Subtitle = "Stretch · sauna · ice", Floor = "B1", Access = "Level", LevelReq = 18, Accent = Color3.fromRGB(143, 166, 139), Ambience = "Recovery" })
def({ Id = "Private", Name = "Private Suites", Subtitle = "Elite one-on-one training", Floor = "B1", Access = "Level", LevelReq = 21, Accent = Color3.fromRGB(150, 110, 80), Ambience = "Private" })
def({ Id = "Mezzanine", Name = "Hall of Fame", Subtitle = "Leaderboards · trophies", Floor = "L2", Access = "Open", Accent = Color3.fromRGB(214, 168, 96), Ambience = "Lobby" })
def({ Id = "Arena", Name = "The Arena", Subtitle = "Competitions · arm-wrestling · tournaments", Floor = "L2", Access = "Open", Accent = Color3.fromRGB(150, 40, 58), Ambience = "Arena" })
def({ Id = "ProFloor", Name = "Pro Floor", Subtitle = "Professional training", Floor = "L2", Access = "Level", LevelReq = 24, Accent = Color3.fromRGB(184, 115, 51), Ambience = "Pro" })
def({ Id = "Foundry", Name = "The Foundry", Subtitle = "Squat · deadlift · heavy bench", Floor = "L2", Access = "Level", LevelReq = 30, Accent = Color3.fromRGB(224, 165, 38), Ambience = "Foundry" })
def({ Id = "VIP", Name = "VIP Club", Subtitle = "Members only", Floor = "L2", Access = "VIP", LevelReq = 1, TrophyCost = 2500, Accent = Color3.fromRGB(46, 120, 92), Ambience = "VIP" })
def({ Id = "Rooftop", Name = "Rooftop", Subtitle = "Running track · skyline · events", Floor = "Roof", Access = "Level", LevelReq = 38, Accent = Color3.fromRGB(181, 83, 60), Ambience = "Rooftop" })
def({ Id = "Apex", Name = "Apex Lab", Subtitle = "Ultimate-tier research gym", Floor = "Annex", Access = "Level", LevelReq = 50, RebirthReq = 1, Accent = Color3.fromRGB(110, 226, 236), Ambience = "Apex" })

local Areas = {}
Areas.Defs = A

Areas.Floors = {
	{ Id = "B1", Name = "Lower Level" },
	{ Id = "G", Name = "Ground Floor" },
	{ Id = "L2", Name = "Second Floor" },
	{ Id = "Roof", Name = "Rooftop" },
}

function Areas.get(id: string): AreaDef?
	return A[id]
end

function Areas.sorted(): { AreaDef }
	local list: { AreaDef } = {}
	for _, a in A do
		table.insert(list, a)
	end
	table.sort(list, function(x: AreaDef, y: AreaDef)
		return x.Order < y.Order
	end)
	return list
end

return Areas
