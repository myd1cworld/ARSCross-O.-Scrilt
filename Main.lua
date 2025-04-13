local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local MainFolder = workspace:FindFirstChild("__Main")
local NpcFolder = MainFolder and MainFolder:FindFirstChild("__Enemies")
local Worlds = MainFolder and MainFolder:FindFirstChild("__World")
local Dungeons = MainFolder and MainFolder:FindFirstChild("__Dungeon")

local Extra = workspace:FindFirstChild("__Extra")
local Appear = Extra and Extra:FindFirstChild("__Appear")


local plr = Players.LocalPlayer
local Character = plr.Character or plr.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
StarterPlayer.CharacterUseJumpPower = true
Humanoid.UseJumpPower = true

local Mouse = plr:GetMouse()

pcall(function() game.CoreGui.AmassaMenu:Destroy() end)
local Menus = plr.PlayerGui:FindFirstChild("Menus")

local Places = {
	MainMap = 87039211657390,
	DungeonMap = 128336380114944,
}

local WhiteList = {
	2803380818,
	719096876,
}

local IslandsPositions = {
	["World 1"] = CFrame.new(54, 28, 57.225196838378906),
	["World 2"] = CFrame.new(-3445, 31, 2754.11474609375),
	["World 3"] = CFrame.new(-3261, 200, -2274.491455078125),
	["World 4"] = CFrame.new(2989, 68, -3061),
	["World 5"] = CFrame.new(108, 38, 4700),
	["World 6"] = CFrame.new(218, 33, -4917),
	["World 7"] = CFrame.new(5354, 40, -116),
	["World 8"] = CFrame.new(-6537, 27, -74),
	["JejuIsland"] = CFrame.new(3316, 59, 2949),
	["GuildHall"] = CFrame.new(289, 31, 157),
}

local Screen = Instance.new("ScreenGui", game.CoreGui)
Screen.Name = "AmassaMenu"
Screen.ScreenInsets = Enum.ScreenInsets.None
Screen.ClipToDeviceSafeArea = false

local Area = "1"
local NpcId = "DB1"

local TweenSpeeds = {
	IslandTweenSpeed = 400,
	DungeonTweenSpeed = 200,
	FarmTweenSpeed = 400,
	WildMountTweenSpeed = 700,
	FindDungeonTweenSpeed = 600,
}

local Config = {
	AutoStartDungeon = true,
	AntiBanEnabled = false,
}

local AutoFarms = {
	AutoFarmAreaEnabled = false,
	AutoFarmUniqueEnabled = false,
	AutoDungeonEnabled = false,
	AutoWildMountEnabled = false,
	AutoFindDungeonEnabled = false,
}

local function ClickButton(button)
	local absPos = button.AbsolutePosition
	local absSize = button.AbsoluteSize
	local centerPos = absPos + (absSize / 2)

	button.Size = UDim2.new(20, 0, 20, 0)

	if button.Visible == false then
		if button.Parent:FindFirstChild("Completed") then
			local Completed = button.Parent.Parent:FindFirstChild("Completed")
			local Gems = Completed and Completed:FindFirstChild("Gems")

			if Gems then
				task.wait(0.05)
				Gems.Size = UDim2.new(20, 0, 20, 0)
			end
		end
	end

	VirtualInputManager:SendMouseButtonEvent(
		centerPos.X, centerPos.Y,
		0,
		true,
		game,
		0
	)
	task.wait(0.05)
	VirtualInputManager:SendMouseButtonEvent(
		centerPos.X, centerPos.Y,
		0,
		false,
		game,
		0
	)

	if button.Parent.Parent:FindFirstChild("InDungeon") then
		local InDungeon = button.Parent.Parent:FindFirstChild("InDungeon")
		local Start = InDungeon and InDungeon:FindFirstChild("Start")

		if Start then
			task.wait(0.05)
			ClickButton(Start)
		end
	end
end

local CurrentNpc

local function SendNotification(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title;
			Text = text;
			Duration = duration or 5;
		})
	end)
end

local function ContainsWord(source, keyword)
	source = string.lower(source)
	keyword = string.lower(keyword)

	return string.find(source, keyword) ~= nil
end

local function ToggleAutoFarmEnable(AutoFarmEnable, Enable)
	for key, _ in pairs(AutoFarms) do
		if key == AutoFarmEnable then
			AutoFarms[key] = Enable or false
		else
			AutoFarms[key] = false
		end
	end
end


local TweenInProgress = {}

local function AutoTween(Object, Properties, Duration, Style, Direction)
	if not Object or not Properties then return end
	return TweenService:Create(Object, TweenInfo.new(Duration or 1, Style or Enum.EasingStyle.Linear, Direction or Enum.EasingDirection.Out), Properties)
end


local function SmoothTeleport(targetCFrame, Speed)
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	local distance = (HumanoidRootPart.Position - targetCFrame.Position).Magnitude
	local travelTime = distance / Speed

	local teleportTween = AutoTween(HumanoidRootPart, {
		CFrame = targetCFrame
	}, travelTime)

	TweenInProgress[HumanoidRootPart] = teleportTween
	teleportTween:Play()

	return teleportTween
end

local function SafeSmoothTeleport(cframe, speed)
	local tween = SmoothTeleport(cframe, speed)

	task.spawn(function()
		while tween.PlaybackState ~= Enum.PlaybackState.Completed do
			if DungeonFound or not AutoFarms["AutoFindDungeonEnabled"] then
				tween:Cancel()
				break
			end
			task.wait(0.05)
		end
	end)

	tween.Completed:Wait()
end


local function AutoDungeon()
	plr:SetAttribute("AutoClick", true)

	task.spawn(function()
		while AutoFarms["AutoDungeonEnabled"] == true and task.wait() do
			local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
			if not HumanoidRootPart then return end

			if CurrentNpc and CurrentNpc:GetAttribute("Dead") == true then
				CurrentNpc = nil
			end

			if not CurrentNpc then
				local ClosestNpcs = {}

				for _, Npc in NpcFolder:FindFirstChild("Server"):GetDescendants() do
					if Npc:IsA("BasePart") and Npc:GetAttribute("Dead") == false then
						local Distance = (HumanoidRootPart.Position - Npc.Position).Magnitude
						table.insert(ClosestNpcs, {Npc = Npc, Distance = Distance})
					end
				end

				table.sort(ClosestNpcs, function(a, b)
					return a.Distance < b.Distance
				end)

				if #ClosestNpcs > 0 then
					local Selected = ClosestNpcs[1].Npc
					CurrentNpc = Selected
					local TravelTime = ClosestNpcs[1].Distance / TweenSpeeds["DungeonTweenSpeed"]
					local TeleportTween = AutoTween(HumanoidRootPart, {CFrame = Selected.CFrame}, TravelTime)
					TweenInProgress[HumanoidRootPart] = TeleportTween
					TeleportTween:Play()
				end
			end
		end
	end)
end


local function IslandTeleport(Island, TweenSpeed)
	local success, err = pcall(function()

		local Character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then return end
		local IslandCFrame = IslandsPositions[Island.Name] or Island:GetPivot()
		local Distance = math.min((HumanoidRootPart.Position - IslandCFrame.Position).Magnitude / TweenSpeed or 400, 8)
		local TeleportTween = AutoTween(HumanoidRootPart, {CFrame = IslandCFrame}, Distance)
		TweenInProgress[HumanoidRootPart] = TeleportTween
		TeleportTween:Play()

		return TeleportTween
	end)
end

local function AutoFindDungeon()
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	pcall(function()
		DungeonFound = false
		
		task.spawn(function()
			while AutoFarms["AutoFindDungeonEnabled"] == true and DungeonFound == false and task.wait(0.5) do
				HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
				if not HumanoidRootPart then return end

				for _, Island in Worlds:GetChildren() do
					if Island:IsA("Model") and ContainsWord(Island.Name, "world") then
						for i = 1, 20 do
							for _, Dungeon in Dungeons:GetChildren() do
								if Dungeon:IsA("BasePart") then
									SafeSmoothTeleport(Dungeon.CFrame, TweenSpeeds["FindDungeonTweenSpeed"])
								elseif Dungeon:IsA("Model") then
									SafeSmoothTeleport(Dungeon:GetPivot(), TweenSpeeds["FindDungeonTweenSpeed"])
								end

								local Menus = plr:WaitForChild("PlayerGui"):WaitForChild("Menus", 5)
								if not Menus then return end

								task.spawn(function()
									local DungeonFrame = Menus:FindFirstChild("Dungeon")
									if DungeonFrame then
										DungeonFound = true
										AutoFarms["AutoFindDungeonEnabled"] = false

										local CreateSection = DungeonFrame:FindFirstChild("Create")
										local Button = CreateSection and CreateSection:FindFirstChild("Create")
										if Button and Config["AutoStartDungeon"] then
											ClickButton(Button)
										end
									end
								end)

								task.spawn(function()
									local CastleFrame = Menus:FindFirstChild("Castle")
									if CastleFrame then
										DungeonFound = true
										AutoFarms["AutoFindDungeonEnabled"] = false

										local CreateSection = CastleFrame:FindFirstChild("Main")
										local Button = CreateSection and CreateSection:FindFirstChild("Create")
										if Button and Config["AutoStartDungeon"] then
											ClickButton(Button)
										end
									end
								end)
							end
							if DungeonFound then break end
							task.wait(0.05)
						end

						if DungeonFound then break end
						SafeSmoothTeleport(Island:GetPivot(), TweenSpeeds["FindDungeonTweenSpeed"])
					end
				end
			end
		end)
	end)
end


local AutoFarmCenterTeleport
local function AutoFarmUnique()
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	local success, errorMsg = pcall(function()
		local SelectedArea = Worlds:FindFirstChild("World "..Area)
		if SelectedArea and SelectedArea:IsA("Model") then

			IslandTeleport(SelectedArea)
		end
	end)
	
	plr:SetAttribute("AutoClick", true)
	
	task.spawn(function()
		while AutoFarms["AutoFarmUniqueEnabled"] == true and task.wait() do
			local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
			if not HumanoidRootPart then return end

			if not CurrentNpc then
				local ClosestNpc = nil
				local ShortestDistance = math.huge

				for _, Npc in NpcFolder:FindFirstChild("Server"):GetDescendants() do
					if Npc:IsA("BasePart") and Npc:GetAttribute("Id") == NpcId and not Npc:GetAttribute("Dead") then
						local distance = (HumanoidRootPart.Position - Npc.Position).Magnitude
						if distance < ShortestDistance then
							ShortestDistance = distance
							ClosestNpc = Npc
						end
					end
				end

				if ClosestNpc then
					if AutoFarmCenterTeleport then
						AutoFarmCenterTeleport:Cancel()
						AutoFarmCenterTeleport = nil
					end

					CurrentNpc = ClosestNpc
					local TravelTime = ShortestDistance / TweenSpeeds["FarmTweenSpeed"]

					local TeleportTween = AutoTween(HumanoidRootPart, {
						CFrame = ClosestNpc.CFrame * CFrame.new(0, 0, -1)
					}, TravelTime)
					TweenInProgress[HumanoidRootPart] = TeleportTween
					
					TeleportTween:Play()
				end

			elseif CurrentNpc:GetAttribute("Dead") then
				if AutoFarmCenterTeleport then
					AutoFarmCenterTeleport:Cancel()
					AutoFarmCenterTeleport = nil
				end

				local SelectedArea = Worlds:FindFirstChild("World "..Area)
				if SelectedArea and SelectedArea:IsA("Model") then

					IslandTeleport(SelectedArea)
				end

				CurrentNpc = nil
			end
		end
	end)
end

local function AutoFarmArea()
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return end

	local success, errorMsg = pcall(function()
		local SelectedArea = Worlds:FindFirstChild("World "..Area)
		if SelectedArea and SelectedArea:IsA("Model") then
			IslandTeleport(SelectedArea)
		end
	end)

	plr:SetAttribute("AutoClick", true)

	task.spawn(function()
		while AutoFarms["AutoFarmAreaEnabled"] == true and task.wait() do
			local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
			if not HumanoidRootPart then return end

			if not CurrentNpc then
				local StrongestNpc = nil
				local HighestHP = 0

				for _, Npc in NpcFolder:FindFirstChild("Server"):GetDescendants() do
					if Npc:IsA("BasePart") and not Npc:GetAttribute("Dead") then
						local NpcHP = Npc:GetAttribute("HP") or 0
						if NpcHP > HighestHP then
							HighestHP = NpcHP
							StrongestNpc = Npc
						end
					end
				end

				if StrongestNpc then
					if AutoFarmCenterTeleport then
						AutoFarmCenterTeleport:Cancel()
						AutoFarmCenterTeleport = nil
					end

					CurrentNpc = StrongestNpc
					local distance = (HumanoidRootPart.Position - StrongestNpc.Position).Magnitude
					local TravelTime = distance / TweenSpeeds["FarmTweenSpeed"]

					local TeleportTween = AutoTween(HumanoidRootPart, {
						CFrame = StrongestNpc.CFrame * CFrame.new(0, 0, -1)
					}, TravelTime)
					TweenInProgress[HumanoidRootPart] = TeleportTween

					TeleportTween:Play()
				end

			elseif CurrentNpc:GetAttribute("Dead") then

				if AutoFarmCenterTeleport then
					AutoFarmCenterTeleport:Cancel()
					AutoFarmCenterTeleport = nil
				end

				local SelectedArea = Worlds:FindFirstChild("World "..Area)
				if SelectedArea and SelectedArea:IsA("Model") then
					IslandTeleport(SelectedArea)
				end

				CurrentNpc = nil
			end
		end
	end)
end

local function AutoWildMount()
	plr:SetAttribute("AutoClick", false)

	local success, err = pcall(function()

		while AutoFarms["AutoWildMountEnabled"] and task.wait(1) do
			local Wilds = Worlds:FindFirstChild("Wilds")
			local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
			if not Wilds or not HumanoidRootPart then break end

			local Islands = {}
			for _, WildIsland in Wilds:GetChildren() do
				if WildIsland:IsA("Model") then
					local Distance = (HumanoidRootPart.Position - WildIsland:GetPivot().Position).Magnitude
					table.insert(Islands, {Island = WildIsland, Distance = Distance})
				end
			end

			table.sort(Islands, function(a, b)
				return a.Distance < b.Distance
			end)

			for _, data in ipairs(Islands) do
				if not AutoFarms["AutoWildMountEnabled"] then break end

				local WildIsland = data.Island
				local teleportTween = SmoothTeleport(WildIsland:GetPivot(), TweenSpeeds["WildMountTweenSpeed"])
				teleportTween:Play()

				local mountFound = false

				while teleportTween.PlaybackState == Enum.PlaybackState.Playing do
					if not AutoFarms["AutoWildMountEnabled"] then
						teleportTween:Cancel()
					end

					task.wait(0.1)

					if Appear and #Appear:GetChildren() > 0 then
						local wildMountModel = Appear:GetChildren()[1]

						if wildMountModel and wildMountModel:IsA("Model") then

							teleportTween:Cancel()

							local pivot = wildMountModel:GetPivot()
							SmoothTeleport(pivot, 400)

							VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
							task.wait(2)
							VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)

							mountFound = true
							AutoFarms["AutoWildMountEnabled"] = false
							break
						end
					end
				end

				if mountFound then
					break
				end
			end
		end
	end)
end

local function AntiBan()
	task.spawn(function()
		while task.wait(0.5) and Config["AntiBanEnabled"] do
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= plr then
					if table.find(WhiteList, player.UserId) then
						continue
					end

					Screen:Destroy()
					ToggleAutoFarmEnable("AutoWildMountEnabled", false)
					ToggleAutoFarmEnable("AutoFarmAreaEnabled", false)
					ToggleAutoFarmEnable("AutoFarmUniqueEnabled", false)
					ToggleAutoFarmEnable("AutoDungeonEnabled", false)

					for _, Tween in pairs(TweenInProgress) do
						Tween:Cancel()
					end

					SendNotification("Anti Ban Actived!", "An Unverified Player Joined The Server, So The Script Was Completely Disabled", 5)

					if game.PlaceId == Places["DungeonMap"] then
						Config["AntiBanEnabled"] = false
						break
					end

					local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
					if not HumanoidRootPart then return end

					local strongestNpc = nil
					local highestPower = -math.huge

					for _, npc in pairs(NpcFolder:FindFirstChild("Server"):GetDescendants()) do
						if npc:IsA("BasePart") and npc:GetAttribute("Power") and type(npc:GetAttribute("Power")) == "number" then
							local power = npc:GetAttribute("Power")
							if power > highestPower then
								highestPower = power
								strongestNpc = npc
							end
						end
					end

					if strongestNpc then
						local travelTime = (HumanoidRootPart.Position - strongestNpc:GetPivot().Position).Magnitude / 500

						local teleportTween = AutoTween(HumanoidRootPart, {
							CFrame = strongestNpc:GetPivot() * CFrame.new(0, 0, -1)
						}, travelTime)

						teleportTween:Play()

						pcall(function()
							plr:SetAttribute("AutoClick", true)
						end)
					end

					Config["AntiBanEnabled"] = false
					break
				end
			end
		end
	end)
end

local InfiniteJumpConnection
local function EnableInfiniteJump()
	local UIS = game:GetService("UserInputService")
	local Player = game:GetService("Players").LocalPlayer
	local Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")

	if InfiniteJumpConnection then InfiniteJumpConnection:Disconnect() end

	InfiniteJumpConnection = UIS.JumpRequest:Connect(function()
		if Config["InfiniteJumpEnabled"] and Humanoid then
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end




local function CreateUIStroke(Settings)
	local UIStroke = Instance.new("UIStroke")
	UIStroke.Parent = Settings.Parent or Screen
	UIStroke.Color = Settings.Color or Color3.new(0, 0, 0)
	UIStroke.Thickness = Settings.Thickness or 1
	UIStroke.Transparency = Settings.Transparency or 0
	UIStroke.ApplyStrokeMode = Settings.ApplyStrokeMode or Enum.ApplyStrokeMode.Border
	UIStroke.Name = Settings.Name or "UIStroke"

	return UIStroke
end

local function CreateUICorner(Settings)
	local UICorner = Instance.new("UICorner")
	UICorner.Parent = Settings.Parent or Screen
	UICorner.CornerRadius = Settings.CornerRadius or UDim.new(0, 16)
	return UICorner
end

local function CreateUIARC(Settings)
	local UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	UIAspectRatioConstraint.Parent = Settings.Parent or Screen
	UIAspectRatioConstraint.AspectRatio = Settings.AspectRatio or 1
	UIAspectRatioConstraint.AspectType = Settings.AspectType or Enum.AspectType.FitWithinMaxSize
	return UIAspectRatioConstraint
end

local function CreateButton(Settings)
	local Button = Instance.new("TextButton")
	Button.Parent = Settings.Parent or Screen
	Button.Name = Settings.Name or "Button"
	Button.Position = Settings.Position or UDim2.new(0.5, 0, 0.5, 0)
	Button.Size = Settings.Size or UDim2.new(0.1, 0, 0.1, 0)
	Button.BackgroundColor3 = Settings.BackgroundColor3 or Color3.new(0, 0, 0)
	Button.Text = Settings.Text or "Button"
	Button.TextColor3 = Settings.TextColor3 or Color3.new(1, 1, 1)
	Button.Font = Settings.Font or Enum.Font.Highway
	Button.Transparency = Settings.Transparency or 0
	Button.TextScaled = true
	Button.TextWrapped = true
	Button.AutoButtonColor = true
	Button.Visible = Settings.Visible ~= false

	return Button
end


local function CreateTextLabel(Settings)
	local TextLabel = Instance.new("TextLabel")
	TextLabel.Interactable = false
	TextLabel.Parent = Settings.Parent or Screen
	TextLabel.Name = Settings.Name or "TextLabel"
	TextLabel.Position = Settings.Position or UDim2.new(0.5, 0, 0.5, 0)
	TextLabel.Size = Settings.Size or UDim2.new(0.1, 0, 0.1, 0)
	TextLabel.BackgroundTransparency = Settings.BackgroundTransparency or 1
	TextLabel.BackgroundColor3 = Settings.BackgroundColor3 or Color3.new(0, 0, 0)
	TextLabel.Text = Settings.Text or "TextLabel"
	TextLabel.TextColor3 = Settings.TextColor3 or Color3.new(1, 1, 1)
	TextLabel.Font = Settings.Font or Enum.Font.Highway
	TextLabel.TextScaled = Settings.TextScaled or true
	TextLabel.TextWrapped = Settings.TextWrapped or true
	return TextLabel
end

local DragLimitFrame = Instance.new("Frame", Screen)
DragLimitFrame.Transparency = 1
DragLimitFrame.AnchorPoint = Vector2.new(0.5, 0.5)
DragLimitFrame.Size = UDim2.new(1, 0, 1, 0)
DragLimitFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

local DragDetector = Instance.new("Frame", Screen)
DragDetector.Name = "DragDetector"
DragDetector.Size = UDim2.new(0.25, 0, 0.03, 0)
DragDetector.Position = UDim2.new(0.35, 0, 0.1, 0)
DragDetector.BackgroundColor3 = Color3.new(0, 0, 0)
DragDetector.Transparency = 1
DragDetector.Visible = true

CreateUIARC({Parent = DragDetector, AspectRatio = 8, AspectType = Enum.AspectType.ScaleWithParentSize})

local MainBackground = Instance.new("Frame", DragDetector)
MainBackground.Name = "MainBackground"
MainBackground.Size = UDim2.new(1, 0, 8, 0)
MainBackground.Position = UDim2.new(0, 0, 0, 0)
MainBackground.BackgroundColor3 = Color3.new(0, 0, 0)
MainBackground.Transparency = 0.5

local DivisionLine = Instance.new("Frame", MainBackground)
DivisionLine.Name = "DivisionLine"
DivisionLine.Size = UDim2.new(0.005, 0, 1, 0)
DivisionLine.Position = UDim2.new(0.15, 0, 0.5, 0)
DivisionLine.AnchorPoint = Vector2.new(0.5, 0.5)
DivisionLine.BackgroundColor3 = Color3.new(0, 0, 0)

local DivisionLine = Instance.new("Frame", MainBackground)
DivisionLine.Name = "DivisionLine"
DivisionLine.Size = UDim2.new(1, 0, 0.005, 0)
DivisionLine.Position = UDim2.new(0.5, 0, 0.115, 0)
DivisionLine.AnchorPoint = Vector2.new(0.5, 0.5)
DivisionLine.BackgroundColor3 = Color3.new(0, 0, 0)

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = MainBackground})
CreateUICorner({CornerRadius = UDim.new(0, 8), Parent = MainBackground})



local GameOptions = Instance.new("ScrollingFrame", MainBackground)
GameOptions.Name = "GameOptions"
GameOptions.Position = UDim2.new(0.575, 0,0.56, 0)
GameOptions.Size = UDim2.new(0.85, 0,0.885, 0)
GameOptions.AnchorPoint = Vector2.new(0.5, 0.5)
GameOptions.BackgroundColor3 = Color3.new(0, 0, 0)
GameOptions.Transparency = 1
GameOptions.Visible = true

local UIPadding = Instance.new("UIPadding", GameOptions)
UIPadding.PaddingTop = UDim.new(0, 5)

local UIGridLayout = Instance.new("UIGridLayout", GameOptions)
UIGridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
UIGridLayout.CellSize = UDim2.new(0.85, 0, 0.05, 0)
UIGridLayout.FillDirection = Enum.FillDirection.Horizontal
UIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center



local PlayerOptionsF = Instance.new("ScrollingFrame", MainBackground)
PlayerOptionsF.Name = "ConfigsOptions"
PlayerOptionsF.Position = UDim2.new(0.575, 0,0.56, 0)
PlayerOptionsF.Size = UDim2.new(0.85, 0,0.885, 0)
PlayerOptionsF.AnchorPoint = Vector2.new(0.5, 0.5)
PlayerOptionsF.BackgroundColor3 = Color3.new(0, 0, 0)
PlayerOptionsF.Transparency = 1
PlayerOptionsF.Visible = true

local UIPadding = Instance.new("UIPadding", PlayerOptionsF)
UIPadding.PaddingTop = UDim.new(0, 5)

local UIGridLayout = Instance.new("UIGridLayout", PlayerOptionsF)
UIGridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
UIGridLayout.CellSize = UDim2.new(0.85, 0, 0.05, 0)
UIGridLayout.FillDirection = Enum.FillDirection.Horizontal
UIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center



local ConfigsOptions = Instance.new("ScrollingFrame", MainBackground)
ConfigsOptions.Name = "ConfigsOptions"
ConfigsOptions.Position = UDim2.new(0.575, 0,0.56, 0)
ConfigsOptions.Size = UDim2.new(0.85, 0,0.885, 0)
ConfigsOptions.AnchorPoint = Vector2.new(0.5, 0.5)
ConfigsOptions.BackgroundColor3 = Color3.new(0, 0, 0)
ConfigsOptions.Transparency = 1
ConfigsOptions.Visible = true

local UIPadding = Instance.new("UIPadding", ConfigsOptions)
UIPadding.PaddingTop = UDim.new(0, 5)

local UIGridLayout = Instance.new("UIGridLayout", ConfigsOptions)
UIGridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
UIGridLayout.CellSize = UDim2.new(0.85, 0, 0.05, 0)
UIGridLayout.FillDirection = Enum.FillDirection.Horizontal
UIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center


local DragIcon = Instance.new("ImageLabel", DragDetector)
DragIcon.Name = "DragIcon"
DragIcon.Size = UDim2.new(0.085, 0, 0.6, 0)
DragIcon.BackgroundTransparency = 1
DragIcon.Image = "rbxassetid://5172066892"
DragIcon.AnchorPoint = Vector2.new(0.5, 0.5)
DragIcon.Interactable = false
DragIcon.Position = UDim2.new(0.075, 0, 0.45, 0)

local UIDragDetector = Instance.new("UIDragDetector", DragDetector)
UIDragDetector.BoundingUI = DragLimitFrame

local ShowButton = CreateButton({
	Parent = Screen,
	Name = "MenuOpen",
	Position = UDim2.new(0.5, 0, 0.015, 0),
	Size = UDim2.new(0.075, 0, 0.075, 0),
	Text = "",
	BackgroundColor3 = Color3.new(0, 0, 0),
	Transparency = 0.5,
})

local ShowButtonTextLabel = CreateTextLabel({
	Parent = ShowButton,
	Name = "ShowButtonText",
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(1, 0, 1, 0),
	Text = "Amassa Menu",
	TextColor3 = Color3.new(1, 1, 1),
}) ShowButtonTextLabel.AnchorPoint = Vector2.new(0.5, 0.5)

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = ShowButtonTextLabel, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = ShowButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
CreateUICorner({Parent = ShowButton, CornerRadius = UDim.new(1,0)})
CreateUIARC({Parent = ShowButton})



ShowButton.MouseButton1Click:Connect(function()
	DragDetector.Visible = not DragDetector.Visible
end)

local MinimizeButton = CreateButton({
	Parent = MainBackground,
	Position = UDim2.new(0.9, 0, 0.02, 0),
	Size = UDim2.new(0.08, 0, 0.08, 0),
	Transparency = 0.5,
	BackgroundColor3 = Color3.new(0, 0, 0),
	Text = ""
})

local MinimizeTextLabel = CreateTextLabel({
	Parent = MinimizeButton,
	Name = "MinimizeTextLabel",
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(1.4, 0, 1.4, 0),
	Text = "-",
	TextColor3 = Color3.new(1, 1, 1),
}) MinimizeTextLabel.AnchorPoint = Vector2.new(0.5, 0.5)

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = MinimizeTextLabel, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = MinimizeButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
CreateUICorner({Parent = MinimizeButton, CornerRadius = UDim.new(0, 8)})

MinimizeButton.MouseButton1Click:Connect(function()
	DragDetector.Visible = not DragDetector.Visible
end)

local AutoFarmStateLabels = {}

local function CreateAutoFarmButton(configName, displayName, parent, callbackFunc, requiresPlaceId)
	local button = CreateButton({
		Parent = parent,
		Position = UDim2.new(0.05, 0, 0.25, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		Transparency = 0.5,
		BackgroundColor3 = Color3.new(0, 0, 0)
	})

	button.Interactable = true
	button.BackgroundTransparency = 0.5

	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = button, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	CreateUICorner({Parent = button, CornerRadius = UDim.new(0, 12)})

	local label = CreateTextLabel({
		Parent = button,
		Name = "AutoFarmText",
		Position = UDim2.new(0.375, 0, 0.5, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
		Text = displayName,
		TextColor3 = Color3.new(1, 1, 1),
	})
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = label, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local stateText = CreateTextLabel({
		Parent = button,
		Name = configName .. "StateText",
		Position = UDim2.new(0.85, 0, 0.5, 0),
		Size = UDim2.new(0.25, 0, 1, 0),
		Text = "Off",
		TextColor3 = Color3.new(1, 0, 0.0156863),
	})
	stateText.AnchorPoint = Vector2.new(0.5, 0.5)
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = stateText, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	AutoFarmStateLabels[configName] = stateText

	local line = Instance.new("Frame", button)
	line.Size = UDim2.new(0.005, 0, 1, 0)
	line.Position = UDim2.new(0.725, 0, 0.5, 0)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = Color3.new(0, 0, 0)

	local function Toggle()
		if requiresPlaceId and game.PlaceId ~= requiresPlaceId then
			AutoFarms[configName] = false
			SendNotification("Incorrect Place!", "This is not the correct place to run this AutoFarm.", 3)
			return
		end

		local enable = not AutoFarms[configName]
		ToggleAutoFarmEnable(configName, enable)

		if enable and typeof(callbackFunc) == "function" then
			callbackFunc()
		end
	end

	button.MouseButton1Click:Connect(Toggle)
end

CreateAutoFarmButton("AutoFarmUniqueEnabled", "Auto Farm Unique", GameOptions, AutoFarmUnique)

CreateAutoFarmButton("AutoFarmAreaEnabled", "Auto Farm Area", GameOptions, AutoFarmArea)

CreateAutoFarmButton("AutoDungeonEnabled", "Auto Dungeon", GameOptions, AutoDungeon, Places["DungeonMap"])

CreateAutoFarmButton("AutoWildMountEnabled", "Auto WindMount", GameOptions, AutoWildMount)

CreateAutoFarmButton("AutoFindDungeonEnabled", "Auto Find Dungeon", GameOptions, AutoFindDungeon)


RunService.RenderStepped:Connect(function()
	for configName, label in pairs(AutoFarmStateLabels) do
		local enabled = AutoFarms[configName]
		label.Text = enabled and "On" or "Off"
		label.TextColor3 = enabled and Color3.new(0.333333, 1, 0.498039) or Color3.new(1, 0, 0)
	end
end)












local OptionScrollings = {
	GameOptions = true,
	ConfigOptions = false,
	PlayerOptions = false
}

local function ToggleOptionScrolling(Option, Enable)
	for key, _ in pairs(OptionScrollings) do
		if key == Option then
			OptionScrollings[key] = Enable or false
		else
			OptionScrollings[key] = false
		end
	end
end

RunService.RenderStepped:Connect(function(DeltaTime)
	if OptionScrollings["GameOptions"] == true then
		ConfigsOptions.Visible = false
		PlayerOptionsF.Visible = false

		GameOptions.Visible = true
	elseif OptionScrollings["GameOptions"] == false then
		GameOptions.Visible = false
	end

	if OptionScrollings["ConfigOptions"] == true then
		GameOptions.Visible = false
		PlayerOptionsF.Visible = false

		ConfigsOptions.Visible = true

	elseif OptionScrollings["ConfigOptions"] == false then
		ConfigsOptions.Visible = false
	end

	if OptionScrollings["PlayerOptions"] == true then
		GameOptions.Visible = false
		ConfigsOptions.Visible = false

		PlayerOptionsF.Visible = true

	elseif OptionScrollings["ConfigOptions"] == false then
		PlayerOptionsF.Visible = false
	end
end)

local MainImageButton = Instance.new("ImageButton", MainBackground)
MainImageButton.Image = "rbxassetid://7539983773"
MainImageButton.Size = UDim2.new(0.125, 0, 0.125, 0)
MainImageButton.AnchorPoint = Vector2.new(0.5, 0.5)
MainImageButton.Position = UDim2.new(0.0735, 0, 0.2, 0)
MainImageButton.BackgroundTransparency = 0.5
MainImageButton.Interactable = true
MainImageButton.BackgroundColor3 = Color3.new(0, 0, 0)
MainImageButton.Visible = true

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = MainImageButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
CreateUICorner({Parent = MainImageButton, CornerRadius = UDim.new(1, 0)})

MainImageButton.MouseButton1Up:Connect(function()
	local Enable = not OptionScrollings["GameOptions"]
	ToggleOptionScrolling("GameOptions", Enable)
end)




local PlayerImageButton = Instance.new("ImageButton", MainBackground)
PlayerImageButton.Image = "rbxassetid://17412890873"
PlayerImageButton.Size = UDim2.new(0.125, 0, 0.125, 0)
PlayerImageButton.AnchorPoint = Vector2.new(0.5, 0.5)
PlayerImageButton.Position = UDim2.new(0.0735, 0, 0.35, 0)
PlayerImageButton.BackgroundTransparency = 0.5
PlayerImageButton.Interactable = true
PlayerImageButton.BackgroundColor3 = Color3.new(0, 0, 0)
PlayerImageButton.Visible = true

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = PlayerImageButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
CreateUICorner({Parent = PlayerImageButton, CornerRadius = UDim.new(1, 0)})

PlayerImageButton.MouseButton1Up:Connect(function()
	local Enable = not OptionScrollings["PlayerOptions"]
	ToggleOptionScrolling("PlayerOptions", Enable)
end)



local ConfigImageButton = Instance.new("ImageButton", MainBackground)
ConfigImageButton.Image = "rbxassetid://120417399323751"
ConfigImageButton.Size = UDim2.new(0.125, 0, 0.125, 0)
ConfigImageButton.AnchorPoint = Vector2.new(0.5, 0.5)
ConfigImageButton.Position = UDim2.new(0.0735, 0, 0.5, 0)
ConfigImageButton.BackgroundTransparency = 0.5
ConfigImageButton.Interactable = true
ConfigImageButton.BackgroundColor3 = Color3.new(0, 0, 0)
ConfigImageButton.Visible = true

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = ConfigImageButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
CreateUICorner({Parent = ConfigImageButton, CornerRadius = UDim.new(1, 0)})

ConfigImageButton.MouseButton1Up:Connect(function()
	local Enable = not OptionScrollings["ConfigOptions"]
	ToggleOptionScrolling("ConfigOptions", Enable)
end)



















local function CreateTweenSpeedInput(Name, DisplayName, parent)
	local button = CreateTextLabel({
		Parent = parent,
		Position = UDim2.new(0.05, 0, 0.25, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		Transparency = 0.5,
		BackgroundColor3 = Color3.new(0, 0, 0)
	})

	button.Interactable = true
	button.BackgroundTransparency = 0.5

	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = button, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	CreateUICorner({Parent = button, CornerRadius = UDim.new(0, 12)})

	local label = CreateTextLabel({
		Parent = button,
		Name = "TweenSpeedText",
		Position = UDim2.new(0.375, 0, 0.5, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
		Text = DisplayName,
		TextColor3 = Color3.new(1, 1, 1),
	})
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = label, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local textbox = Instance.new("TextBox", button)
	textbox.Position = UDim2.new(0.865, 0, 0.5, 0)
	textbox.Size = UDim2.new(0.25, 0, 1, 0)
	textbox.PlaceholderText = "Put Speed (The Bigger The Faster)"
	textbox.Text = tostring(TweenSpeeds[Name])
	textbox.TextColor3 = Color3.new(1, 1, 1)
	textbox.PlaceholderColor3 = Color3.new(1, 1, 1)
	textbox.AnchorPoint = Vector2.new(0.5, 0.5)
	textbox.Font = Enum.Font.Highway
	textbox.TextScaled = true
	textbox.TextWrapped = true
	textbox.BackgroundTransparency = 1
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = textbox, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local line = Instance.new("Frame", button)
	line.Size = UDim2.new(0.005, 0, 1, 0)
	line.Position = UDim2.new(0.725, 0, 0.5, 0)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = Color3.new(0, 0, 0)

	textbox:GetPropertyChangedSignal("Text"):Connect(function()
		pcall(function()
			local CleanText = string.gsub(textbox.Text, "%D", "")
			local Value = tonumber(CleanText)
			if Value and Value > 0 then
				textbox.Text = CleanText
				TweenSpeeds[Name] = Value
			end
		end)
	end)
end


local function CreateConfigToggleButton(configName, displayName, parent)
	local button = CreateButton({
		Parent = parent,
		Position = UDim2.new(0.05, 0, 0.25, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		Transparency = 0.5,
		BackgroundColor3 = Color3.new(0, 0, 0)
	})

	button.Interactable = true
	button.BackgroundTransparency = 0.5

	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = button, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	CreateUICorner({Parent = button, CornerRadius = UDim.new(0, 12)})

	local label = CreateTextLabel({
		Parent = button,
		Name = "ConfigText",
		Position = UDim2.new(0.375, 0, 0.5, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
		Text = displayName,
		TextColor3 = Color3.new(1, 1, 1),
	})
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = label, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local line = Instance.new("Frame", button)
	line.Size = UDim2.new(0.005, 0, 1, 0)
	line.Position = UDim2.new(0.725, 0, 0.5, 0)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = Color3.new(0, 0, 0)

	local stateText = CreateTextLabel({
		Parent = button,
		Name = configName .. "StateText",
		Position = UDim2.new(0.85, 0, 0.5, 0),
		Size = UDim2.new(0.25, 0, 1, 0),
		Text = Config[configName] and "On" or "Off",
		TextColor3 = Config[configName] and Color3.new(0.333333, 1, 0.498039) or Color3.new(1, 0, 0),
	})
	stateText.AnchorPoint = Vector2.new(0.5, 0.5)
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = stateText, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local function Toggle()
		Config[configName] = not Config[configName]
		stateText.Text = Config[configName] and "On" or "Off"
		stateText.TextColor3 = Config[configName] and Color3.new(0.333333, 1, 0.498039) or Color3.new(1, 0, 0)

		if configName == "AntiBanEnabled" and Config[configName] == true then
			AntiBan()
		end
	end

	button.MouseButton1Click:Connect(Toggle)

	return button
end

local function CreatePlayerStatInput(statName, displayName, parent)
	local button = CreateTextLabel({
		Parent = parent,
		Position = UDim2.new(0.05, 0, 0.25, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		Transparency = 0.5,
		BackgroundColor3 = Color3.new(0, 0, 0)
	})

	button.Interactable = true
	button.BackgroundTransparency = 0.5

	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = button, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	CreateUICorner({Parent = button, CornerRadius = UDim.new(0, 12)})

	local label = CreateTextLabel({
		Parent = button,
		Name = "PlayerStatText",
		Position = UDim2.new(0.375, 0, 0.5, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
		Text = displayName,
		TextColor3 = Color3.new(1, 1, 1),
	})
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = label, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local textbox = Instance.new("TextBox", button)
	textbox.Position = UDim2.new(0.865, 0, 0.5, 0)
	textbox.Size = UDim2.new(0.25, 0, 1, 0)
	textbox.PlaceholderText = "Insert Value"
	textbox.Text = tostring(Config[statName])
	textbox.TextColor3 = Color3.new(1, 1, 1)
	textbox.PlaceholderColor3 = Color3.new(1, 1, 1)
	textbox.AnchorPoint = Vector2.new(0.5, 0.5)
	textbox.Font = Enum.Font.Highway
	textbox.TextScaled = true
	textbox.TextWrapped = true
	textbox.BackgroundTransparency = 1
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = textbox, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local line = Instance.new("Frame", button)
	line.Size = UDim2.new(0.005, 0, 1, 0)
	line.Position = UDim2.new(0.725, 0, 0.5, 0)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = Color3.new(0, 0, 0)

	local Character = plr.Character
	local Humanoid = Character:WaitForChild("Humanoid")

	if statName == "WalkSpeed" then
		textbox.Text = Humanoid.WalkSpeed
	elseif statName == "JumpPower" then
		textbox.Text = Humanoid.JumpPower
	end

	textbox:GetPropertyChangedSignal("Text"):Connect(function()
		pcall(function()
			local CleanText = string.gsub(textbox.Text, "%D", "")
			local Value = tonumber(CleanText)
			if Value and Value > 0 then
				textbox.Text = CleanText

				local Character = plr.Character
				local Humanoid = Character:WaitForChild("Humanoid")

				if statName == "WalkSpeed" then
					Humanoid.WalkSpeed = Value
				elseif statName == "JumpPower" then
					Humanoid.JumpPower = Value
				end
			end
		end)
	end)
end

local function CreatePlayerToggleButton(configName, displayName, parent)
	local button = CreateButton({
		Parent = parent,
		Position = UDim2.new(0.05, 0, 0.25, 0),
		Size = UDim2.new(1, 0, 1, 0),
		Text = "",
		Transparency = 0.5,
		BackgroundColor3 = Color3.new(0, 0, 0)
	})

	button.Interactable = true
	button.BackgroundTransparency = 0.5

	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = button, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
	CreateUICorner({Parent = button, CornerRadius = UDim.new(0, 12)})

	local label = CreateTextLabel({
		Parent = button,
		Name = "ToggleText",
		Position = UDim2.new(0.375, 0, 0.5, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
		Text = displayName,
		TextColor3 = Color3.new(1, 1, 1),
	})
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = label, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local stateText = CreateTextLabel({
		Parent = button,
		Name = configName .. "StateText",
		Position = UDim2.new(0.85, 0, 0.5, 0),
		Size = UDim2.new(0.25, 0, 1, 0),
		Text = Config[configName] and "On" or "Off",
		TextColor3 = Config[configName] and Color3.new(0.333333, 1, 0.498039) or Color3.new(1, 0, 0),
	})
	stateText.AnchorPoint = Vector2.new(0.5, 0.5)
	CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = stateText, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

	local line = Instance.new("Frame", button)
	line.Size = UDim2.new(0.005, 0, 1, 0)
	line.Position = UDim2.new(0.725, 0, 0.5, 0)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = Color3.new(0, 0, 0)

	local function Toggle()
		Config[configName] = not Config[configName]
		stateText.Text = Config[configName] and "On" or "Off"
		stateText.TextColor3 = Config[configName] and Color3.new(0.333333, 1, 0.498039) or Color3.new(1, 0, 0)

		if configName == "InfiniteJumpEnabled" and Config[configName] then
			EnableInfiniteJump()
		end
	end

	button.MouseButton1Click:Connect(Toggle)
	return button
end


CreateTweenSpeedInput("IslandTweenSpeed", "Island Tween Speed", ConfigsOptions)

CreateTweenSpeedInput("DungeonTweenSpeed", "Dungeon Tween Speed", ConfigsOptions)

CreateTweenSpeedInput("FarmTweenSpeed", "Farm Tween Speed", ConfigsOptions)

CreateTweenSpeedInput("WildMountTweenSpeed", "WildMount Tween Speed", ConfigsOptions)

CreateTweenSpeedInput("FindDungeonTweenSpeed", "Find Dungeon Tween Speed", ConfigsOptions)

CreateConfigToggleButton("AutoStartDungeon", "Auto Start Dungeon", ConfigsOptions)

CreateConfigToggleButton("AntiBanEnabled", "Anti Ban", ConfigsOptions)

CreatePlayerStatInput("WalkSpeed", "WalkSpeed", PlayerOptionsF)
CreatePlayerStatInput("JumpPower", "JumpPower", PlayerOptionsF)

CreatePlayerToggleButton("InfiniteJumpEnabled", "Infinite Jump", PlayerOptionsF)


















local IslandTeleportButton = CreateButton({
	Parent = GameOptions,
	Position = UDim2.new(0.05, 0, 0.25, 0),
	Size = UDim2.new(1, 0, 1, 0),
	Text = "",
	Transparency = 0.5,
	BackgroundColor3 = Color3.new(0, 0, 0)
})

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = IslandTeleportButton, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
CreateUICorner({Parent = IslandTeleportButton, CornerRadius = UDim.new(0, 12)})

local IslandTeleportText = CreateTextLabel({
	Parent = IslandTeleportButton,
	Name = "TeleportText",
	Position = UDim2.new(0.375, 0,0.5, 0),
	Size = UDim2.new(0.7, 0,1, 0),
	Text = "Islands Teleport",
	TextColor3 = Color3.new(1, 1, 1),
}) IslandTeleportText.AnchorPoint = Vector2.new(0.5, 0.5) IslandTeleportText.TextXAlignment = Enum.TextXAlignment.Left

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = IslandTeleportText, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

local IslandTeleportButtonEnabledText = CreateTextLabel({
	Parent = IslandTeleportButton,
	Name = "AutoFarmButtonEnabledText",
	Position = UDim2.new(0.85, 0,0.5, 0),
	Size = UDim2.new(0.25, 0,1, 0),
	Text = "Show",
	TextColor3 = Color3.new(1, 1, 1),
}) IslandTeleportButtonEnabledText.AnchorPoint = Vector2.new(0.5, 0.5)

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = IslandTeleportButtonEnabledText, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})

local DivisionLine = Instance.new("Frame", IslandTeleportButton)
DivisionLine.Size = UDim2.new(0.005, 0, 1, 0)
DivisionLine.Position = UDim2.new(0.725, 0,0.5, 0)
DivisionLine.AnchorPoint = Vector2.new(0.5, 0.5)
DivisionLine.BackgroundColor3 = Color3.new(0, 0, 0)

local IslandFrameList = Instance.new("ScrollingFrame", MainBackground)
IslandFrameList.Name = "IslandFrameList"
IslandFrameList.Position = UDim2.new(-0.35, 0, 0.325, 0)
IslandFrameList.Size = UDim2.new(0.6, 0, 0.65, 0)
IslandFrameList.AnchorPoint = Vector2.new(0.5, 0.5)
IslandFrameList.Transparency = 0.5
IslandFrameList.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
IslandFrameList.Visible = false
IslandFrameList.CanvasSize = UDim2.new(0, 0, 0, 0)
IslandFrameList.ScrollBarThickness = 8

CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = IslandFrameList, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = IslandFrameList, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
CreateUICorner({Parent = IslandFrameList, CornerRadius = UDim.new(0, 12)})

local function UpdateIslandList()
	local IslandInfor = {
		{Island = "World 1", IslandName = "Leveling City (World 1)", LayoutOrder = 1},
		{Island = "JejuIsland", IslandName = "Jeju Island (Beru Place)", LayoutOrder = 2},
		{Island = "World 2", IslandName = "Grass Village (World 2)", LayoutOrder = 3},
		{Island = "World 3", IslandName = "Brum Island (World 3)", LayoutOrder = 4},
		{Island = "World 4", IslandName = "Faceheal Town (World 4)", LayoutOrder = 5},
		{Island = "World 5", IslandName = "Lucky Kingdom (World 5)", LayoutOrder = 6},
		{Island = "World 6", IslandName = "Nipon City (World 6)", LayoutOrder = 7},
		{Island = "World 7", IslandName = "Mori Town (World 7)", LayoutOrder = 8},
		{Island = "World 8", IslandName = "Dragon City (World 8)", LayoutOrder = 9},
		{Island = "GuildHall", IslandName = "GuildHall", LayoutOrder = 10},
	}

	local function GetIslandInfoByName(name)
		for _, entry in ipairs(IslandInfor) do
			if entry.Island == name then
				return entry
			end
		end

		return {IslandName = name, LayoutOrder = 999}
	end

	pcall(function()
		IslandFrameList:ClearAllChildren()

		local listLayout = Instance.new("UIListLayout")
		listLayout.Parent = IslandFrameList
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 5)

		for _, Island in ipairs(Worlds:GetChildren()) do
			if Island:IsA("Model") and Island.Name ~= "Wilds" then
				local islandInfo = GetIslandInfoByName(Island.Name)

				local IslandTemplate = Instance.new("TextButton")
				IslandTemplate.Name = "IslandButton"
				IslandTemplate.Size = UDim2.new(1, -10, 0, 30)
				IslandTemplate.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
				IslandTemplate.BackgroundTransparency = 0.5
				IslandTemplate.Text = ""
				IslandTemplate.AutoButtonColor = false
				IslandTemplate.LayoutOrder = islandInfo.LayoutOrder
				IslandTemplate.Parent = IslandFrameList

				CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = IslandTemplate, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
				CreateUIStroke({Color = Color3.new(0, 0, 0), Parent = IslandTemplate, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual})
				CreateUICorner({Parent = IslandTemplate, CornerRadius = UDim.new(0, 12)})

				local IslandLabel = Instance.new("TextLabel")
				IslandLabel.Parent = IslandTemplate
				IslandLabel.Size = UDim2.new(1, 0, 1, 0)
				IslandLabel.BackgroundTransparency = 1
				IslandLabel.Text = islandInfo.IslandName
				IslandLabel.TextColor3 = Color3.new(1, 1, 1)
				IslandLabel.Font = Enum.Font.SourceSans
				IslandLabel.TextScaled = true
				IslandLabel.Name = "IslandNameLabel"

				IslandTemplate.MouseButton1Click:Connect(function()
					pcall(function()
						IslandTeleport(Island, TweenSpeeds["IslandTweenSpeed"])
						IslandTeleportButtonEnabledText.Text = "Show"
						IslandFrameList.Visible = false
					end)
				end)
			end
		end

		IslandFrameList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)
end


local function ToggleIslandsTeleport()
	if IslandFrameList.Visible == false then
		IslandTeleportButtonEnabledText.Text = "Hide"
		IslandFrameList.Visible = true
		UpdateIslandList()
	else
		IslandFrameList.Visible = false
		IslandTeleportButtonEnabledText.Text = "Show"
	end
end

IslandTeleportButton.MouseButton1Up:Connect(ToggleIslandsTeleport)



task.spawn(function()
	SendNotification("Welcome!", "Developed by juauduamassa!", 6)    
	SendNotification("Script Loading.", "Loading...", 3)
	task.wait(3)
	SendNotification("Good Game!", "Loading End.", 3)
	task.wait(2)
end)
