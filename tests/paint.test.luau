--!strict
local H = require("./harness")
local Inventory = require("../src/shared/Inventory")
local Paint = require("../src/shared/Paint")
local PaintConfig = require("../src/shared/PaintConfig")

print("Paint")

H.test("catalog ids are unique and prices in range", function()
	local seen: { [string]: boolean } = {}
	for _, c in PaintConfig.Colors do
		H.eq(seen[c.id], nil, c.id)
		seen[c.id] = true
		H.truthy(c.price >= 80 and c.price <= 250, c.id)
	end
	for _, s in PaintConfig.Stickers do
		H.eq(seen[s.id], nil, s.id)
		seen[s.id] = true
		H.truthy(s.price >= 120 and s.price <= 300, s.id)
	end
	H.eq(#PaintConfig.Colors, 10)
	H.eq(#PaintConfig.Stickers, 6)
end)

H.test("canBuy reasons and buy", function()
	local p = Inventory.default()
	local ok, why = Paint.canBuy(p, "blue")
	H.eq(ok, false)
	H.eq(why, "coins")
	ok, why = Paint.canBuy(p, "nope")
	H.eq(why, "unknown")
	ok, why = Paint.canBuy(p, 5)
	H.eq(why, "unknown")
	p.coins = 150
	H.truthy(Paint.buy(p, "blue"))
	H.eq(p.coins, 50)
	H.truthy(p.paint.owned.blue)
	ok, why = Paint.canBuy(p, "blue")
	H.eq(why, "owned")
	H.eq(Paint.buy(p, "blue"), false)
	H.eq(p.coins, 50)
	H.eq(Paint.buy(p, "gold"), false)
	H.eq(p.coins, 50)
end)

H.test("equip validates car, kind, id and ownership", function()
	local p = Inventory.default()
	p.coins = 1000
	Paint.buy(p, "blue")
	Paint.buy(p, "star")
	local ok, why = Paint.equip(p, "Compact", "color", "blue")
	H.truthy(ok)
	H.eq(p.paint.equipped.Compact.color, "blue")
	ok, why = Paint.equip(p, "Compact", "sticker", "star")
	H.truthy(ok)
	ok, why = Paint.equip(p, "Compact", "color", "star")
	H.eq(why, "unknown") -- wrong kind
	ok, why = Paint.equip(p, "Compact", "color", "gold")
	H.eq(why, "notowned")
	ok, why = Paint.equip(p, "Compact", "wheels", "blue")
	H.eq(why, "kind")
	ok, why = Paint.equip(p, "NoSuchCar", "color", "blue")
	H.eq(why, "car")
	ok, why = Paint.equip(p, "HotRod", "color", "blue") -- car not owned
	H.eq(why, "car")
	ok, why = Paint.equip(p, "Compact", "color", 7)
	H.eq(why, "unknown")
	-- per car, and clearing
	H.eq(p.paint.equipped.Compact.color, "blue")
	H.truthy(Paint.equip(p, "Compact", "color", nil))
	H.eq(p.paint.equipped.Compact.color, nil)
	H.eq(p.paint.equipped.Compact.sticker, "star")
	H.truthy(Paint.equip(p, "Compact", "sticker", nil))
	H.eq(p.paint.equipped.Compact, nil)
end)

H.test("look resolves equipped color and sticker", function()
	local p = Inventory.default()
	p.coins = 1000
	Paint.buy(p, "gold")
	Paint.equip(p, "Compact", "color", "gold")
	local rgb, sticker = Paint.look(p.paint, "Compact")
	H.eq((rgb :: { number })[1], 225)
	H.eq(sticker, nil)
	rgb, sticker = Paint.look(p.paint, "Sedan")
	H.eq(rgb, nil)
end)

H.test("profile defaults and migrates paint (old saves lack it)", function()
	H.eq(next(Inventory.default().paint.owned), nil)
	local old = Inventory.migrate({ coins = 5, owned = { Compact = true } })
	H.eq(type(old.paint), "table")
	H.eq(next(old.paint.owned), nil)
	H.eq(type(Inventory.migrate({ paint = "x" }).paint.equipped), "table")
	local kept = Inventory.migrate({
		owned = { Compact = true },
		paint = {
			owned = { blue = true, junk = true, star = 1 },
			equipped = {
				Compact = { color = "blue", sticker = "star" }, -- star not owned
				Bogus = { color = "blue" },
			},
		},
	})
	H.truthy(kept.paint.owned.blue)
	H.eq(kept.paint.owned.junk, nil)
	H.eq(kept.paint.owned.star, nil)
	H.eq(kept.paint.equipped.Compact.color, "blue")
	H.eq(kept.paint.equipped.Compact.sticker, nil)
	H.eq(kept.paint.equipped.Bogus, nil)
	-- round trip
	local p = Inventory.default()
	p.coins = 500
	Paint.buy(p, "pink")
	Paint.equip(p, "Compact", "color", "pink")
	local again = Inventory.migrate(p)
	H.truthy(again.paint.owned.pink)
	H.eq(again.paint.equipped.Compact.color, "pink")
end)
