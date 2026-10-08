--!strict
-- Number / time formatting used by every UI surface (keep output short and consistent).

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 999 -> "999", 1234 -> "1.23K", 98765 -> "98.8K", 1.5e6 -> "1.5M"
function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local neg = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = if n == math.floor(n) then tostring(math.floor(n)) else string.format("%.1f", n)
		return (if neg then "-" else "") .. s
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local s: string
	if n >= 100 then
		s = string.format("%d", math.floor(n))
	elseif n >= 10 then
		s = string.format("%.1f", math.floor(n * 10) / 10)
	else
		s = string.format("%.2f", math.floor(n * 100) / 100)
	end
	s = string.gsub(s, "%.?0+$", "") :: string
	return (if neg then "-" else "") .. s .. SUFFIXES[i]
end

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (if n < 0 then "-" else "") .. out
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- 3725 -> "1h 2m", 95 -> "1m 35s", 40 -> "40s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

-- 0.153 -> "+15%"
function Format.percentBonus(mult: number): string
	return string.format("+%d%%", math.floor((mult - 1) * 100 + 0.5))
end

-- 12.345 -> "12.35s"
function Format.seconds(t: number): string
	return string.format("%.2fs", t)
end

return Format
