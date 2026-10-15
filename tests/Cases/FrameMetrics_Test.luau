--!strict
return function(t: any)
	local Metrics = require(game.ReplicatedStorage.Shared.Util.FrameMetrics)
	t.test("240 FPS frame budget is measured without frame-rate assumptions", function()
		local m = Metrics.new()
		for _ = 1, 240 do m.Add(1/240) end
		local sample = m.Read()
		t.expect.near(sample.FPS, 240); t.expect.near(sample.AverageMs, 1000/240)
		t.expect.truthy(sample.P95Ms >= 1000/240 and sample.P95Ms <= 4.5)
	end)
	t.test("frame spikes and reset remain observable", function()
		local m = Metrics.new()
		for _ = 1, 100 do m.Add(.004) end
		m.Add(.150); m.Add(0/0); m.Add(math.huge); m.Add(0)
		t.expect.equal(m.Read().Frames, 101); t.expect.near(m.Read().WorstMs, 150)
		m.Reset(); t.expect.equal(m.Read().Frames, 0); t.expect.equal(m.Read().FPS, 0)
	end)
end
