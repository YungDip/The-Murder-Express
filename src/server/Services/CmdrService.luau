local CmdrService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local Cmdr = require(ServerScriptService.ServerPackages.cmdr)

Cmdr:RegisterDefaultCommands()
Cmdr:RegisterTypesIn(script.Parent.Parent.CmdrTypes)
Cmdr:RegisterCommandsIn(script.Parent.Parent.CmdrCommands)

Cmdr:AddHook("BeforeRun", function()
	return nil
end)

return CmdrService
