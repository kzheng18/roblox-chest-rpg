--!strict

return function(t)
	local RarityFormat = require(game.ReplicatedStorage.Shared.Util.RarityFormat)

	t.test("formats rarity as one in N", function()
		t.expect.equal(RarityFormat.Rate(1), "1/1")
		t.expect.equal(RarityFormat.Rate(500), "1/500")
	end)

	t.test("normalizes non-integer rates", function()
		t.expect.equal(RarityFormat.Rate(12.49), "1/12")
		t.expect.equal(RarityFormat.Rate(12.5), "1/13")
	end)
end
