local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function GetZoneNames(): { string }
	local ZoneModels = ReplicatedStorage:FindFirstChild("ZoneModels")
	if not ZoneModels then
		return {}
	end
	local Names = {}
	for _, Child in ZoneModels:GetChildren() do
		table.insert(Names, Child.Name)
	end
	table.sort(Names)
	return Names
end

return function(Registry)
	Registry:RegisterType("zone", {
		Transform = function(Text)
			return Text
		end,

		Validate = function(Value)
			local ZoneModels = ReplicatedStorage:FindFirstChild("ZoneModels")
			if ZoneModels and ZoneModels:FindFirstChild(Value) then
				return true
			end
			return false, string.format("%q is not a valid zone model.", Value)
		end,

		Autocomplete = function(Value)
			local Names = GetZoneNames()
			local Matches = {}
			local LowerValue = Value:lower()
			for _, Name in Names do
				if Name:lower():find(LowerValue, 1, true) then
					table.insert(Matches, Name)
				end
			end
			return Matches
		end,

		Parse = function(Value)
			return Value
		end,
	})

	local ZoneType = Registry.Types.zone
	Registry:RegisterType("zones", Registry.Cmdr.Util.MakeListableType(ZoneType))
end
