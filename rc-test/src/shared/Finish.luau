--!strict
-- Surface finishes for decor pieces (carter 2026-10-25: "make the game look better"): bushes look
-- leafy, wood looks like wood, cloth like cloth, poles like metal. Only for looks pieces built
-- with Garage.adder (plot decor, tile looks, the car show): never the road, curbs or anything
-- the car drives on, so grip never changes. A piece keeps any material it was given already.

local Finish = {}

-- part name -> material
Finish.BY_NAME = {
	Bush = "Grass",
	TreeTop = "Grass",
	Cactus = "Grass",
	CactusArm = "Grass",
	TreeTrunk = "Wood",
	FlowerBed = "Wood",
	SignPost = "Wood",
	TentRoof = "Fabric",
	Flag = "Fabric",
	JumpFlag = "Fabric",
	Pennant = "Fabric",
	Cloth = "Fabric",
	Awning = "Fabric",
	Valance = "Fabric",
	GantryPost = "Metal",
	GantryBeam = "Metal",
	FlagPole = "Metal",
	TentPole = "Metal",
	JumpPost = "Metal",
	WarnPost = "Metal",
	SplitPost = "Metal",
	Pole = "Metal",
	Barrel = "Metal",
	BarrelBand = "Metal",
	SkinDrum = "Metal",
	SkinDrumBand = "Metal",
	Barrier = "Plastic",
	SkinBarrier = "Plastic",
	Cooler = "Plastic",
} :: { [string]: string }

-- Gives each SmoothPlastic piece in `pieces` its finish by name; returns the same list.
function Finish.apply<T>(pieces: T): T
	for _, p in pieces :: any do
		local m = Finish.BY_NAME[p.name]
		if m and p.material == "SmoothPlastic" then
			p.material = m
		end
	end
	return pieces
end

return Finish
