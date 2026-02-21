local Services = script:FindFirstChild("Services")

for _, Module in Services:GetChildren() do
	if Module:IsA("ModuleScript") then
		task.spawn(require, Module)
	end
end
