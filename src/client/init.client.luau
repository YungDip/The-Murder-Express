local Controllers = script:FindFirstChild("Controllers")

for _, Module in Controllers:GetChildren() do
	if Module:IsA("ModuleScript") then
		task.spawn(require, Module)
	end
end
