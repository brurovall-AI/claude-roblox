--!strict
--[[
	Props library: furniture, fixtures and small details that make every area
	feel lived-in. Area dressing modules call these; keep signatures stable.

	All `cf` arguments are FLOOR-LEVEL CFrames (bottom-centre of the prop) unless
	noted. Wall-mounted props take the CFrame of the wall SURFACE point where the
	prop is centred, with LookVector pointing OUT of the wall into the room.
	Every prop returns its Model. Small parts never collide (Kit.DETAIL).

	The implementations live in Props/*.luau modules registered below; this file
	is the stable facade.
]]

local Kit = require("../Kit")

export type Finish = Kit.FinishArg

local Props = {}

---------------------------------------------------------------------------
-- Registry: modules in Props/List.luau provide implementations by name.
---------------------------------------------------------------------------
local impl: { [string]: (...any) -> Model } = {}

function Props.register(name: string, fn: (...any) -> Model)
	impl[name] = fn
end

-- Generic placeholder so missing props never break a bake (visible magenta box).
local function placeholder(parent: Instance, cf: CFrame, size: Vector3, name: string): Model
	local m = Kit.model(parent, name, cf)
	Kit.box(m, cf * CFrame.new(0, size.Y / 2, 0), size, "PlasticCoral", Kit.DETAIL)
	return m
end

local function call(name: string, fallbackSize: Vector3, parent: Instance, cf: CFrame, ...: any): Model
	local fn = impl[name]
	if fn then
		return fn(parent, cf, ...)
	end
	return placeholder(parent, cf, fallbackSize, name)
end

---------------------------------------------------------------------------
-- Nature
---------------------------------------------------------------------------
-- kind: "Fiddle" | "Snake" | "Olive" | "Palm" | "Bush" | "Fern" | "Monstera"
function Props.plant(parent: Instance, cf: CFrame, kind: string?, scale: number?): Model
	return call("plant", Vector3.new(2, 5, 2), parent, cf, kind or "Fiddle", scale or 1)
end
-- Planter box with plants. size = (X, height, Z)
function Props.planter(parent: Instance, cf: CFrame, size: Vector3, finish: Finish?, plantKind: string?): Model
	return call("planter", size, parent, cf, size, finish or "ConcreteDark", plantKind or "Bush")
end
-- kind: "Oak" | "Birch" | "Pine" | "Street"
function Props.tree(parent: Instance, cf: CFrame, kind: string?, scale: number?): Model
	return call("tree", Vector3.new(6, 18, 6), parent, cf, kind or "Oak", scale or 1)
end
function Props.hangingPlant(parent: Instance, cf: CFrame): Model -- cf = ceiling anchor point
	return call("hangingPlant", Vector3.new(1.5, 2, 1.5), parent, cf)
end

---------------------------------------------------------------------------
-- Furniture
---------------------------------------------------------------------------
function Props.bench(parent: Instance, cf: CFrame, length: number, finish: Finish?): Model
	return call("bench", Vector3.new(length, 1.6, 1.6), parent, cf, length, finish or "Oak")
end
-- kind: "Velvet" | "Leather" | "Fabric"; seats 1-4
function Props.sofa(parent: Instance, cf: CFrame, seats: number, kind: string?): Model
	return call("sofa", Vector3.new(seats * 3, 3, 3.2), parent, cf, seats, kind or "Velvet")
end
function Props.armchair(parent: Instance, cf: CFrame, kind: string?): Model
	return call("armchair", Vector3.new(3, 3, 3), parent, cf, kind or "Leather")
end
function Props.stool(parent: Instance, cf: CFrame, finish: Finish?): Model
	return call("stool", Vector3.new(1.4, 3, 1.4), parent, cf, finish or "LeatherBlack")
end
function Props.coffeeTable(parent: Instance, cf: CFrame, size: Vector3?, finish: Finish?): Model
	return call("coffeeTable", size or Vector3.new(4, 1.4, 2.4), parent, cf, size or Vector3.new(4, 1.4, 2.4), finish or "Walnut")
end
function Props.table(parent: Instance, cf: CFrame, size: Vector3?, finish: Finish?): Model
	return call("table", size or Vector3.new(4, 2.6, 4), parent, cf, size or Vector3.new(4, 2.6, 4), finish or "Oak")
end
function Props.umbrellaTable(parent: Instance, cf: CFrame, canopy: Finish?): Model
	return call("umbrellaTable", Vector3.new(8, 8, 8), parent, cf, canopy or "FabricCream")
end
function Props.rug(parent: Instance, cf: CFrame, size: Vector2, finish: Finish?): Model
	return call("rug", Vector3.new(size.X, 0.1, size.Y), parent, cf, size, finish or "Carpet")
end
-- Counter (reception, juice bar, café). length along cf.RightVector, customers stand on the LookVector side.
function Props.counter(parent: Instance, cf: CFrame, length: number, depth: number, top: Finish?, body: Finish?): Model
	return call("counter", Vector3.new(length, 3.6, depth), parent, cf, length, depth, top or "Marble", body or "Walnut")
end
-- Wall shelving with stock. items: "Supplements" | "Towels" | "Merch" | "Shakers" | "Trophies" | "Books"
function Props.shelf(parent: Instance, cf: CFrame, width: number, height: number, items: string?): Model
	return call("shelf", Vector3.new(width, height, 1.6), parent, cf, width, height, items or "Supplements")
end
-- Locker bank: columns x rows of doors. Front faces cf.LookVector.
function Props.lockers(parent: Instance, cf: CFrame, columns: number, rows: number, finish: Finish?): Model
	return call("lockers", Vector3.new(columns * 2, rows * 3.2, 2), parent, cf, columns, rows, finish or "Oak")
end
function Props.bleachers(parent: Instance, cf: CFrame, width: number, rows: number, finish: Finish?): Model
	return call("bleachers", Vector3.new(width, rows * 1.6, rows * 2.6), parent, cf, width, rows, finish or "PowderGraphite")
end
function Props.trophyCase(parent: Instance, cf: CFrame, width: number): Model
	return call("trophyCase", Vector3.new(width, 7, 2), parent, cf, width)
end
function Props.vending(parent: Instance, cf: CFrame, kind: string?): Model -- "Drinks" | "Snacks"
	return call("vending", Vector3.new(3.4, 7, 3), parent, cf, kind or "Drinks")
end
function Props.fridge(parent: Instance, cf: CFrame): Model
	return call("fridge", Vector3.new(3, 7, 2.4), parent, cf)
end
function Props.waterFountain(parent: Instance, cf: CFrame): Model -- wall mounted
	return call("waterFountain", Vector3.new(2, 3.6, 1.4), parent, cf)
end
function Props.massageTable(parent: Instance, cf: CFrame): Model
	return call("massageTable", Vector3.new(3, 2.6, 7), parent, cf)
end

---------------------------------------------------------------------------
-- Gym clutter / small details
---------------------------------------------------------------------------
function Props.towel(parent: Instance, cf: CFrame, color: Color3?): Model -- folded towel
	return call("towel", Vector3.new(1.2, 0.3, 0.8), parent, cf, color or Color3.fromRGB(240, 240, 236))
end
function Props.towelStack(parent: Instance, cf: CFrame, count: number?, color: Color3?): Model
	return call("towelStack", Vector3.new(1.2, 1.4, 0.8), parent, cf, count or 5, color or Color3.fromRGB(240, 240, 236))
end
function Props.towelRack(parent: Instance, cf: CFrame): Model
	return call("towelRack", Vector3.new(3, 5, 1.4), parent, cf)
end
function Props.waterBottle(parent: Instance, cf: CFrame, color: Color3?): Model
	return call("waterBottle", Vector3.new(0.35, 0.9, 0.35), parent, cf, color or Color3.fromRGB(60, 168, 156))
end
function Props.shaker(parent: Instance, cf: CFrame, color: Color3?): Model
	return call("shaker", Vector3.new(0.4, 0.8, 0.4), parent, cf, color or Color3.fromRGB(30, 30, 32))
end
function Props.gymBag(parent: Instance, cf: CFrame, color: Color3?): Model
	return call("gymBag", Vector3.new(2.2, 1.2, 1.1), parent, cf, color or Color3.fromRGB(40, 42, 46))
end
-- Cleaning station: spray bottles, paper-towel dispenser, wipes, bin.
function Props.cleaningStation(parent: Instance, cf: CFrame): Model
	return call("cleaningStation", Vector3.new(2.4, 4.5, 1.6), parent, cf)
end
function Props.trashBin(parent: Instance, cf: CFrame, finish: Finish?): Model
	return call("trashBin", Vector3.new(1.4, 2.4, 1.4), parent, cf, finish or "SteelBrushed")
end
function Props.chalkBowl(parent: Instance, cf: CFrame): Model
	return call("chalkBowl", Vector3.new(2, 3.6, 2), parent, cf)
end
function Props.foamRollers(parent: Instance, cf: CFrame): Model
	return call("foamRollers", Vector3.new(3, 3, 1.4), parent, cf)
end
function Props.medBalls(parent: Instance, cf: CFrame): Model -- rack of medicine balls
	return call("medBalls", Vector3.new(5, 4, 1.6), parent, cf)
end
function Props.kettlebells(parent: Instance, cf: CFrame, count: number?): Model -- floor row / shelf
	return call("kettlebells", Vector3.new(6, 2, 1.6), parent, cf, count or 6)
end
function Props.plateStack(parent: Instance, cf: CFrame, finish: Finish?, count: number?): Model -- loose plates on the floor
	return call("plateStack", Vector3.new(2.6, 1.2, 2.6), parent, cf, finish or "Rubber", count or 4)
end
function Props.firstAid(parent: Instance, cf: CFrame): Model -- wall mounted
	return call("firstAid", Vector3.new(1.4, 1.2, 0.4), parent, cf)
end
function Props.fireExtinguisher(parent: Instance, cf: CFrame): Model -- wall mounted
	return call("fireExtinguisher", Vector3.new(0.6, 1.8, 0.6), parent, cf)
end
function Props.exitSign(parent: Instance, cf: CFrame): Model -- wall mounted
	return call("exitSign", Vector3.new(1.8, 0.7, 0.3), parent, cf)
end
function Props.stanchions(parent: Instance, a: Vector3, b: Vector3): Model -- queue rope posts on the floor between a and b
	return call("stanchions", Vector3.new(1, 3, 1), parent, CFrame.new(a), b)
end

---------------------------------------------------------------------------
-- Walls, signage, screens
---------------------------------------------------------------------------
-- Mirror wall panel (cf = centre of the mirror on the wall, facing the room).
function Props.mirror(parent: Instance, cf: CFrame, width: number, height: number, frame: Finish?): Model
	return call("mirror", Vector3.new(width, height, 0.3), parent, cf, width, height, frame or "PowderBlack")
end
-- Branded wall sign. style: "Brand" | "Area" | "Motto" | "Wayfinding" | "Neon"
function Props.wallSign(parent: Instance, cf: CFrame, text: string, size: Vector2, style: string?): Model
	return call("wallSign", Vector3.new(size.X, size.Y, 0.4), parent, cf, text, size, style or "Area")
end
-- Ironhaven logo mark (shield + wordmark). size = overall width.
function Props.logo(parent: Instance, cf: CFrame, width: number, variant: string?): Model -- "Light" | "Dark" | "Brass"
	return call("logo", Vector3.new(width, width * 0.4, 0.4), parent, cf, width, variant or "Light")
end
-- Framed poster. theme: "Strength" | "Speed" | "Endurance" | "Agility" | "Recovery" | "Boxing" | "Vintage"
function Props.poster(parent: Instance, cf: CFrame, size: Vector2, theme: string?): Model
	return call("poster", Vector3.new(size.X, size.Y, 0.2), parent, cf, size, theme or "Strength")
end
function Props.tv(parent: Instance, cf: CFrame, width: number, content: string?): Model -- wall TV; content text shown
	return call("tv", Vector3.new(width, width * 0.58, 0.3), parent, cf, width, content or "")
end
function Props.clock(parent: Instance, cf: CFrame, diameter: number?): Model
	return call("clock", Vector3.new(2, 2, 0.3), parent, cf, diameter or 2)
end
function Props.speaker(parent: Instance, cf: CFrame): Model -- wall/ceiling speaker
	return call("speaker", Vector3.new(1.2, 1.8, 1), parent, cf)
end
function Props.acousticPanels(parent: Instance, cf: CFrame, width: number, height: number, finish: Finish?): Model
	return call("acousticPanels", Vector3.new(width, height, 0.4), parent, cf, width, height, finish or "FabricGrey")
end
function Props.woodSlats(parent: Instance, cf: CFrame, width: number, height: number, finish: Finish?): Model
	return call("woodSlats", Vector3.new(width, height, 0.5), parent, cf, width, height, finish or "Walnut")
end

---------------------------------------------------------------------------
-- Lighting & services (include the Light instances)
---------------------------------------------------------------------------
-- kind: "Panel" (recessed LED panel) | "Linear" (suspended linear) | "Pendant" (warm dome)
--       | "Industrial" (high-bay) | "Spot" (track spot) | "Globe" | "Downlight"
-- cf = ceiling point (underside of the ceiling), fixture hangs down from it.
-- opts: { Color, Brightness, Range, Shadows, Length }
function Props.ceilingLight(parent: Instance, cf: CFrame, kind: string?, opts: { [string]: any }?): Model
	return call("ceilingLight", Vector3.new(4, 0.4, 1), parent, cf, kind or "Panel", opts or {})
end
-- kind: "Sconce" | "Strip" | "Wash" ; wall mounted
function Props.wallLight(parent: Instance, cf: CFrame, kind: string?, opts: { [string]: any }?): Model
	return call("wallLight", Vector3.new(1, 1.4, 0.5), parent, cf, kind or "Sconce", opts or {})
end
-- Exposed ventilation duct run between two points (round, with hangers/joints).
function Props.duct(parent: Instance, a: Vector3, b: Vector3, diameter: number?, finish: Finish?): Model
	return call("duct", Vector3.new(diameter or 2.4, diameter or 2.4, 1), parent, CFrame.new(a), b, diameter or 2.4, finish or "SteelBrushed")
end
function Props.pipe(parent: Instance, a: Vector3, b: Vector3, diameter: number?, finish: Finish?): Model
	return call("pipe", Vector3.new(0.4, 0.4, 1), parent, CFrame.new(a), b, diameter or 0.4, finish or "SteelDark")
end
function Props.cableTray(parent: Instance, a: Vector3, b: Vector3): Model
	return call("cableTray", Vector3.new(1.4, 0.4, 1), parent, CFrame.new(a), b)
end
-- Industrial steel truss between two points (for exposed ceilings).
function Props.truss(parent: Instance, a: Vector3, b: Vector3, depth: number?, finish: Finish?): Model
	return call("truss", Vector3.new(1, depth or 3, 1), parent, CFrame.new(a), b, depth or 3, finish or "SteelDark")
end
function Props.column(parent: Instance, cf: CFrame, height: number, kind: string?): Model -- "Concrete" | "Steel" | "Clad" | "Round"
	return call("column", Vector3.new(2.4, height, 2.4), parent, cf, height, kind or "Concrete")
end
function Props.fan(parent: Instance, cf: CFrame, kind: string?): Model -- "Ceiling" (cf = ceiling point) | "Standing" | "Wall"
	return call("fan", Vector3.new(3, 4, 3), parent, cf, kind or "Standing")
end
function Props.ringLight(parent: Instance, cf: CFrame): Model -- photo ring light on a tripod
	return call("ringLight", Vector3.new(2, 6, 2), parent, cf)
end

---------------------------------------------------------------------------
-- Outdoor
---------------------------------------------------------------------------
function Props.lampPost(parent: Instance, cf: CFrame, kind: string?): Model -- "Street" | "Park" | "Flood"
	return call("lampPost", Vector3.new(1, 16, 1), parent, cf, kind or "Park")
end
-- kind: "Chainlink" | "Rail" | "Glass" | "Timber" ; floor points a -> b
function Props.fence(parent: Instance, a: Vector3, b: Vector3, height: number?, kind: string?): Model
	return call("fence", Vector3.new(1, height or 6, 1), parent, CFrame.new(a), b, height or 6, kind or "Chainlink")
end
function Props.parkBench(parent: Instance, cf: CFrame): Model
	return call("parkBench", Vector3.new(5, 2.6, 2), parent, cf)
end
function Props.car(parent: Instance, cf: CFrame, color: Color3?): Model -- parked car, low detail
	return call("car", Vector3.new(6.5, 4.6, 15), parent, cf, color or Color3.fromRGB(60, 64, 70))
end
function Props.bikeRack(parent: Instance, cf: CFrame): Model
	return call("bikeRack", Vector3.new(6, 2.6, 2), parent, cf)
end
function Props.bollard(parent: Instance, cf: CFrame): Model
	return call("bollard", Vector3.new(0.8, 2.6, 0.8), parent, cf)
end
function Props.flag(parent: Instance, cf: CFrame, color: Color3?): Model
	return call("flag", Vector3.new(4, 20, 1), parent, cf, color or Color3.fromRGB(242, 169, 59))
end

-- Implementations
local list = require("./List")
for _, mod in list do
	mod(Props)
end

return Props
