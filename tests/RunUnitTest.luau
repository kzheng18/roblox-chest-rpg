--!strict
local expect = {}

function expect.equal(a: any, b: any)
	assert(a == b, `Expected {tostring(b)}, got {tostring(a)}`)
end

function expect.truthy(value: any)
	assert(value, "Expected truthy")
end

function expect.falsy(value: any)
	assert(not value, "Expected falsy")
end

function expect.near(a: number, b: number, tolerance: number?)
	assert(a == a and math.abs(a - b) <= (tolerance or 1e-6), `Expected {b}, got {a}`)
end

return function(filter: string?)
	local totals = {run = 0, passed = 0, failed = 0}
	for _, module in script.Parent.Cases:GetChildren() do
		if not module:IsA("ModuleScript") or (filter and not string.find(module.Name, filter, 1, true)) then
			continue
		end
		local t = {expect = expect}
		function t.test(name: string, fn: () -> ())
			totals.run += 1
			local ok, err = pcall(fn)
			if ok then
				totals.passed += 1
				print("[PASS] " .. module.Name .. " > " .. name)
			else
				totals.failed += 1
				warn("[FAIL] " .. module.Name .. " > " .. name .. ": " .. tostring(err))
			end
		end
		local ok, err = pcall(function()
			require(module)(t)
		end)
		if not ok then
			totals.run += 1
			totals.failed += 1
			warn("[FAIL] " .. module.Name .. ": " .. tostring(err))
		end
	end
	print(`[SUMMARY] {totals.run} run, {totals.passed} passed, {totals.failed} failed`)
	return totals
end
