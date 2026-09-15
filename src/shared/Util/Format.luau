--!strict
-- Number formatting: 1234 -> "1.23K", 5e11 -> "500B"
local Format = {}

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local neg = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = if n == math.floor(n) then tostring(n) else string.format("%.1f", n)
		return (neg and "-" or "") .. s
	end
	local idx = 1
	while n >= 1000 and idx < #suffixes do
		n /= 1000
		idx += 1
	end
	local s: string
	if n >= 100 then
		s = string.format("%.0f", n)
	elseif n >= 10 then
		s = string.format("%.1f", n)
	else
		s = string.format("%.2f", n)
	end
	if s:find("%.") then
		s = s:gsub("0+$", ""):gsub("%.$", "")
	end
	return (neg and "-" or "") .. s .. suffixes[idx]
end

function Format.cash(n: number): string
	return "$" .. Format.short(n)
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return string.format("%ds", seconds)
end

function Format.comma(n: number): string
	local s = string.format("%d", math.floor(n))
	local reversed = s:reverse():gsub("(%d%d%d)", "%1,")
	local out = reversed:reverse():gsub("^,", "")
	return out
end

return Format
