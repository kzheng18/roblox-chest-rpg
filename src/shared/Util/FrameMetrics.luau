--!strict
-- Fixed-memory histogram: no per-frame tables, remotes, or inventory updates.
local FrameMetrics = {}
function FrameMetrics.new()
	local bins = table.create(256, 0)
	local frames, seconds, worst = 0, 0, 0
	local metrics = {}
	function metrics.Add(delta: number)
		if delta ~= delta or delta <= 0 or delta == math.huge then return end
		frames += 1; seconds += delta; worst = math.max(worst, delta)
		local bin = math.clamp(math.ceil(delta * 4000), 1, 256)
		bins[bin] += 1
	end
	function metrics.Read(): any
		local cutoff, count, p95 = math.ceil(frames * .95), 0, 0
		for index, frequency in bins do
			count += frequency
			if frames > 0 and count >= cutoff then p95 = if index == 256 then worst * 1000 else index / 4; break end
		end
		return {FPS = if seconds > 0 then frames / seconds else 0, Frames = frames,
			AverageMs = if frames > 0 then seconds * 1000 / frames else 0, P95Ms = p95, WorstMs = worst * 1000}
	end
	function metrics.Reset()
		for index = 1, #bins do bins[index] = 0 end
		frames = 0; seconds = 0; worst = 0
	end
	return metrics
end
return FrameMetrics
