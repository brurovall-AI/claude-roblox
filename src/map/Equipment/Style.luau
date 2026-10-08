--!strict
--[[
	Tier visual language for training equipment. Builders pick finishes from
	here so tiers read instantly and consistently across every machine:

	  1 Beginner     friendly: white powder-coat frames, coral/teal vinyl, rounded
	                 caps, chunky simple forms, coloured vinyl dumbbells
	  2 Amateur      honest: black powder-coat steel, black vinyl, rubber plates,
	                 visible bolts, simple placards
	  3 Professional precise: graphite frames, brushed-steel guide rods, red vinyl,
	                 chrome pins and collars, branded side shrouds
	  4 Elite        crafted: matte graphite + oak trim, tan leather, brass collars,
	                 knurled handles, gusset plates, nameplates
	  5 Legendary    luxurious: black chrome + gold trim, walnut, quilted black
	                 leather (stitch lines), marble or walnut bases
	  6 Ultimate     futuristic: white composite shells, titanium, carbon, floating
	                 elements, thin cyan light lines (the ONLY tier with emissive)

	Higher tiers also add detail density (bolts, cable guards, labels, plates).
]]

local Palette = require("../Palette")

export type TierStyle = {
	Frame: Palette.Finish, -- main structure
	FrameAccent: Palette.Finish, -- secondary structure / caps
	Upholstery: Palette.Finish, -- pads, seats
	Metal: Palette.Finish, -- rods, bars, collars, handles
	Grip: Palette.Finish, -- handles / knurling
	Plate: Palette.Finish, -- weight plates
	PlateAccent: Palette.Finish, -- plate rims / labels
	Trim: Palette.Finish, -- decorative trim
	Base: Palette.Finish, -- floor base / platform
	Light: Palette.Finish?, -- emissive accent (Ultimate only)
	Detail: number, -- 1..6 detail density hint
	Label: string, -- tier name for placards
}

local F = Palette.F

local Style = {}

Style.Tiers = {
	{
		Frame = F.PowderWhite,
		FrameAccent = F.PlasticCoral,
		Upholstery = F.VinylCoral,
		Metal = F.SteelBrushed,
		Grip = F.RubberGrip,
		Plate = F.PlasticTeal,
		PlateAccent = F.PlasticCoral,
		Trim = F.PlasticTeal,
		Base = F.RubberCoral,
		Light = nil,
		Detail = 1,
		Label = "BEGINNER",
	},
	{
		Frame = F.PowderBlack,
		FrameAccent = F.PowderGraphite,
		Upholstery = F.VinylBlack,
		Metal = F.Steel,
		Grip = F.RubberGrip,
		Plate = F.Rubber,
		PlateAccent = F.PowderGraphite,
		Trim = F.PowderGraphite,
		Base = F.RubberFloor,
		Light = nil,
		Detail = 2,
		Label = "AMATEUR",
	},
	{
		Frame = F.PowderGraphite,
		FrameAccent = F.PowderBlack,
		Upholstery = F.VinylRed,
		Metal = F.Chrome,
		Grip = F.SteelBrushed,
		Plate = F.CastIron,
		PlateAccent = F.PowderRed,
		Trim = F.PowderRed,
		Base = F.RubberFleck,
		Light = nil,
		Detail = 3,
		Label = "PROFESSIONAL",
	},
	{
		Frame = Palette.tint("PowderGraphite", Color3.fromRGB(48, 50, 54)),
		FrameAccent = F.OakSolid,
		Upholstery = F.LeatherTan,
		Metal = F.SteelBrushed,
		Grip = F.Steel,
		Plate = F.CastIron,
		PlateAccent = F.Brass,
		Trim = F.Brass,
		Base = F.Oak,
		Light = nil,
		Detail = 4,
		Label = "ELITE",
	},
	{
		Frame = F.BlackChrome,
		FrameAccent = F.Walnut,
		Upholstery = F.LeatherBlack,
		Metal = F.Gold,
		Grip = F.BlackChrome,
		Plate = F.BlackChrome,
		PlateAccent = F.Gold,
		Trim = F.Gold,
		Base = F.MarbleDark,
		Light = nil,
		Detail = 5,
		Label = "LEGENDARY",
	},
	{
		Frame = F.Composite,
		FrameAccent = F.Carbon,
		Upholstery = Palette.tint("LeatherBlack", Color3.fromRGB(40, 44, 50)),
		Metal = F.Titanium,
		Grip = F.Carbon,
		Plate = F.Composite,
		PlateAccent = F.Titanium,
		Trim = F.Titanium,
		Base = F.Carbon,
		Light = F.LightCyan,
		Detail = 6,
		Label = "ULTIMATE",
	},
} :: { TierStyle }

function Style.get(tier: number): TierStyle
	return Style.Tiers[math.clamp(math.floor(tier), 1, 6)]
end

return Style
