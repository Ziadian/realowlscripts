local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local hitRemote = RS.CombatSystem.Remotes.RequestHit
local skillRemote = RS.AbilitySystem.Remotes.RequestAbility
local hakiRemote = RS.RemoteEvents.HakiRemote
local equipRemote = RS.Remotes:WaitForChild("EquipWeapon")

-- ตัวแปรหลัก
local farming = false
local selectedMobs = {} 
local currentTarget = nil 
local haki = false
local selectedWeapon = ""

local skills = {Z=false, X=false, C=false, V=false, B=false}
local skillIndex = {Z=1, X=2, C=3, V=4, B=5}
local skillOrder = {"Z", "X", "C", "V", "B"} 

local BodyVelocity = Instance.new("BodyVelocity")
BodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
BodyVelocity.Velocity = Vector3.zero

---------------------------------------------------------
-- SAVE / LOAD SETTINGS
---------------------------------------------------------
local ConfigName = "SailorPiece_Classic_Save.json"

local function SaveConfig()
	local data = {
		Mobs = selectedMobs,
		Skills = skills,
		Haki = haki,
		Weapon = selectedWeapon
	}
	pcall(function() writefile(ConfigName, HttpService:JSONEncode(data)) end)
end

local function LoadConfig()
	pcall(function()
		if isfile and isfile(ConfigName) then
			local data = HttpService:JSONDecode(readfile(ConfigName))
			if data then
				selectedMobs = data.Mobs or {}
				skills = data.Skills or skills
				haki = data.Haki or false
				selectedWeapon = data.Weapon or ""
			end
		end
	end)
end
LoadConfig()

---------------------------------------------------------
-- HELPER FUNCTIONS (OPTIMIZED)
---------------------------------------------------------
local function getRoot(mob)
	return mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("RootPart") or mob:FindFirstChild("Torso")
end

local function isMobSelected(mobName)
	for selectedName, _ in pairs(selectedMobs) do
		if mobName:lower():find(selectedName:lower()) then return true end
	end
	return false
end

-- [NEW] หาเป้าหมายที่ "ใกล้ที่สุด" เพื่อลดเวลาบิน
local function getValidTarget()
	if currentTarget and currentTarget.Parent then
		local hum = currentTarget:FindFirstChildOfClass("Humanoid")
		local hrp = getRoot(currentTarget)
		if hum and hrp and hum.Health > 0 and isMobSelected(currentTarget.Name) then
			return currentTarget
		end
	end
	
	currentTarget = nil
	local char = player.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	local closestDist = math.huge
	
	for _,mob in pairs(workspace.NPCs:GetChildren()) do
		if isMobSelected(mob.Name) then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			local hrp = getRoot(mob)
			if hum and hrp and hum.Health > 0 then
				if myRoot then
					local dist = (myRoot.Position - hrp.Position).Magnitude
					if dist < closestDist then
						closestDist = dist
						currentTarget = mob
					end
				else
					currentTarget = mob
					return currentTarget
				end
			end
		end
	end
	return currentTarget
end

---------------------------------------------------------
-- GUI SECTION (CLASSIC STYLE)
---------------------------------------------------------
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "AutoFarmHub_Classic"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 300, 0, 440)
frame.Position = UDim2.new(0.5, -150, 0.5, -220)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(60, 60, 60)
stroke.Thickness = 1.5

-- [DRAGGING LOGIC]
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 40)
title.Text = " SAILOR PIECE | AUTO FARM"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
local titlePadding = Instance.new("UIPadding", title)
titlePadding.PaddingLeft = UDim.new(0, 15)

local separator = Instance.new("Frame", frame)
separator.Size = UDim2.new(1, 0, 0, 1)
separator.Position = UDim2.new(0, 0, 0, 40)
separator.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
separator.BorderSizePixel = 0

local dragging = false
local dragInput, dragStart, startPos

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
title.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)
UIS.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- [MOB SELECTION]
local search = Instance.new("TextBox", frame)
search.Size = UDim2.new(1, -30, 0, 30)
search.Position = UDim2.new(0, 15, 0, 50)
search.PlaceholderText = "🔍 Search Mob..."
search.Text = ""
search.Font = Enum.Font.Gotham
search.TextSize = 14
search.TextColor3 = Color3.fromRGB(255, 255, 255)
search.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 6)

local targetLabel = Instance.new("TextLabel", frame)
targetLabel.Size = UDim2.new(1, -30, 0, 20)
targetLabel.Position = UDim2.new(0, 15, 0, 85)
targetLabel.Text = "Targets: None"
targetLabel.Font = Enum.Font.GothamSemibold
targetLabel.TextSize = 13
targetLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
targetLabel.BackgroundTransparency = 1
targetLabel.TextXAlignment = Enum.TextXAlignment.Left

local dropdown = Instance.new("ScrollingFrame", frame)
dropdown.Size = UDim2.new(1, -30, 0, 95)
dropdown.Position = UDim2.new(0, 15, 0, 105)
dropdown.ScrollBarThickness = 4
dropdown.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
dropdown.BorderSizePixel = 0
Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 6)
local layout = Instance.new("UIListLayout", dropdown)
layout.Padding = UDim.new(0, 5)
Instance.new("UIPadding", dropdown).PaddingTop = UDim.new(0, 5)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	dropdown.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)

local function updateTargetLabel()
	local names = {}
	for name, _ in pairs(selectedMobs) do table.insert(names, name) end
	if #names == 0 then
		targetLabel.Text = "Targets: None"
		targetLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	else
		local text = "Targets: " .. table.concat(names, ", ")
		targetLabel.Text = #text > 40 and text:sub(1, 37) .. "..." or text
		targetLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
	SaveConfig()
end

local mobButtons = {}
local function refreshList()
	for _,b in pairs(mobButtons) do b:Destroy() end
	table.clear(mobButtons)
	local names = {}
	for _,mob in pairs(workspace.NPCs:GetChildren()) do
		local clean = mob.Name:gsub("%d+","")
		if not names[clean] then
			names[clean] = true
			if search.Text == "" or clean:lower():find(search.Text:lower()) then
				local btn = Instance.new("TextButton", dropdown)
				btn.Size = UDim2.new(1, -10, 0, 25)
				btn.Position = UDim2.new(0, 5, 0, 0)
				btn.Text = clean
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 13
				btn.TextColor3 = Color3.fromRGB(220, 220, 220)
				btn.BackgroundColor3 = selectedMobs[clean] and Color3.fromRGB(0, 130, 0) or Color3.fromRGB(45, 45, 45)
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
				btn.MouseButton1Click:Connect(function()
					selectedMobs[clean] = not selectedMobs[clean] and true or nil
					btn.BackgroundColor3 = selectedMobs[clean] and Color3.fromRGB(0, 130, 0) or Color3.fromRGB(45, 45, 45)
					updateTargetLabel()
				end)
				table.insert(mobButtons, btn)
			end
		end
	end
end
search:GetPropertyChangedSignal("Text"):Connect(refreshList)
refreshList()
updateTargetLabel()

-- [WEAPON SELECTION]
local wepLabel = Instance.new("TextLabel", frame)
wepLabel.Size = UDim2.new(1, -60, 0, 20)
wepLabel.Position = UDim2.new(0, 15, 0, 205)
wepLabel.Text = "Weapon: " .. (selectedWeapon == "" and "None" or selectedWeapon)
wepLabel.Font = Enum.Font.GothamSemibold
wepLabel.TextSize = 13
wepLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
wepLabel.BackgroundTransparency = 1
wepLabel.TextXAlignment = Enum.TextXAlignment.Left

local wepRefreshBtn = Instance.new("TextButton", frame)
wepRefreshBtn.Size = UDim2.new(0, 25, 0, 20)
wepRefreshBtn.Position = UDim2.new(1, -40, 0, 205)
wepRefreshBtn.Text = "🔄"
wepRefreshBtn.BackgroundTransparency = 1

local wepDropdown = Instance.new("ScrollingFrame", frame)
wepDropdown.Size = UDim2.new(1, -30, 0, 70)
wepDropdown.Position = UDim2.new(0, 15, 0, 230)
wepDropdown.ScrollBarThickness = 4
wepDropdown.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
wepDropdown.BorderSizePixel = 0
Instance.new("UICorner", wepDropdown).CornerRadius = UDim.new(0, 6)
local wepLayout = Instance.new("UIListLayout", wepDropdown)
wepLayout.Padding = UDim.new(0, 5)
Instance.new("UIPadding", wepDropdown).PaddingTop = UDim.new(0, 5)
wepLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	wepDropdown.CanvasSize = UDim2.new(0, 0, 0, wepLayout.AbsoluteContentSize.Y + 10)
end)

local wepButtons = {}
local function refreshWeapons()
	for _,b in pairs(wepButtons) do b:Destroy() end
	table.clear(wepButtons)
	
	local foundWeapons = {}
	local bp = player:FindFirstChild("Backpack")
	if bp then for _, v in pairs(bp:GetChildren()) do if v:IsA("Tool") then foundWeapons[v.Name] = true end end end
	if player.Character then for _, v in pairs(player.Character:GetChildren()) do if v:IsA("Tool") then foundWeapons[v.Name] = true end end end

	for wName, _ in pairs(foundWeapons) do
		local btn = Instance.new("TextButton", wepDropdown)
		btn.Size = UDim2.new(1, -10, 0, 25)
		btn.Position = UDim2.new(0, 5, 0, 0)
		btn.Text = wName
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 13
		btn.TextColor3 = Color3.fromRGB(220, 220, 220)
		btn.BackgroundColor3 = (selectedWeapon == wName) and Color3.fromRGB(180, 100, 0) or Color3.fromRGB(45, 45, 45)
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
		
		btn.MouseButton1Click:Connect(function()
			selectedWeapon = wName
			wepLabel.Text = "Weapon: " .. selectedWeapon
			SaveConfig()
			refreshWeapons()
		end)
		table.insert(wepButtons, btn)
	end
end
wepRefreshBtn.MouseButton1Click:Connect(refreshWeapons)
refreshWeapons()

-- [START BUTTON]
local start = Instance.new("TextButton", frame)
start.Size = UDim2.new(1, -30, 0, 35)
start.Position = UDim2.new(0, 15, 0, 310)
start.Text = "START FARM"
start.Font = Enum.Font.GothamBold
start.TextSize = 14
start.TextColor3 = Color3.fromRGB(255, 255, 255)
start.BackgroundColor3 = Color3.fromRGB(0, 130, 255)
Instance.new("UICorner", start).CornerRadius = UDim.new(0, 6)

start.MouseButton1Click:Connect(function()
	farming = not farming
	if farming then
		start.Text = "STOP FARM"
		start.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
		refreshWeapons()
	else
		start.Text = "START FARM"
		start.BackgroundColor3 = Color3.fromRGB(0, 130, 255)
		currentTarget = nil 
		BodyVelocity.Parent = nil 
	end
end)

-- [SKILLS SECTION]
local skillsContainer = Instance.new("Frame", frame)
skillsContainer.Size = UDim2.new(1, -30, 0, 35)
skillsContainer.Position = UDim2.new(0, 15, 0, 355)
skillsContainer.BackgroundTransparency = 1

local skillsLayout = Instance.new("UIListLayout", skillsContainer)
skillsLayout.FillDirection = Enum.FillDirection.Horizontal
skillsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillsLayout.Padding = UDim.new(0, 8)

local function createSkillButton(name, isHaki)
	local btn = Instance.new("TextButton", skillsContainer)
	btn.Size = UDim2.new(0, 35, 0, 35)
	btn.Text = name
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	
	local isActive = isHaki and haki or (not isHaki and skills[name])
	btn.BackgroundColor3 = isActive and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 50)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local btnStroke = Instance.new("UIStroke", btn)
	btnStroke.Color = isActive and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(80, 80, 80)
	
	btn.MouseButton1Click:Connect(function()
		if isHaki then
			haki = not haki
			btn.BackgroundColor3 = haki and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 50)
			btnStroke.Color = haki and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(80, 80, 80)
		else
			skills[name] = not skills[name]
			btn.BackgroundColor3 = skills[name] and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 50)
			btnStroke.Color = skills[name] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(80, 80, 80)
		end
		SaveConfig()
	end)
end

for _, key in ipairs(skillOrder) do createSkillButton(key, false) end
createSkillButton("G", true)

-- [TOGGLE BUTTON]
local toggleBtn = Instance.new("TextButton", gui)
toggleBtn.Size = UDim2.new(0, 45, 0, 45)
toggleBtn.Position = UDim2.new(0, 15, 0, 15) 
toggleBtn.Text = "🌊" 
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24
toggleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
toggleBtn.BorderSizePixel = 0
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
local toggleStroke = Instance.new("UIStroke", toggleBtn)
toggleStroke.Color = Color3.fromRGB(0, 130, 255)
toggleStroke.Thickness = 1.5

toggleBtn.Activated:Connect(function()
	if frame then frame.Visible = not frame.Visible end
end)

---------------------------------------------------------
-- LOGIC LOOPS (SEPARATED & OPTIMIZED)
---------------------------------------------------------
-- [1. MOVEMENT & LOCK-ON LOOP] ทำงานไหลลื่นตามเฟรมเรตหน้าจอ
RunService.Heartbeat:Connect(function()
	if farming then
		local char = player.Character
		if char then
			-- ปิดการชน (Noclip)
			for _, v in pairs(char:GetChildren()) do
				if v:IsA("BasePart") then v.CanCollide = false end
			end
			
			local root = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			local target = getValidTarget()
			
			if target and root and hum and hum.Health > 0 then
				local hrp = getRoot(target)
				local targetHum = target:FindFirstChildOfClass("Humanoid")
				
				if hrp and targetHum then
					-- ล็อคเป้าหมาย
					targetHum.WalkSpeed = 0
					targetHum.JumpPower = 0
					hrp.Anchored = true
					
					-- ลอยตัว + วาร์ปไปข้างหลัง 5 Unit
					BodyVelocity.Parent = root
					BodyVelocity.Velocity = Vector3.zero
					local behindPos = hrp.CFrame * CFrame.new(0, 0, 5)
					root.CFrame = CFrame.new(behindPos.Position, hrp.Position)
				end
			else
				BodyVelocity.Parent = nil
			end
		end
	end
end)

-- [2. FAST ATTACK LOOP] ส่งคำสั่งตีในความเร็วที่เซิร์ฟเวอร์รับได้ (กันดีเลย์/แบน)
task.spawn(function()
	while task.wait(0.05) do -- ดีเลย์ 0.05 เป็นจุดที่สมดุลสุด ไม่ทำให้ Server เอ๋อ
		if farming and currentTarget then
			local char = player.Character
			if char then
				local weapon = char:FindFirstChildOfClass("Tool")
				if weapon then pcall(function() weapon:Activate() end) end
				pcall(function() hitRemote:FireServer() end)
			end
		end
	end
end)

-- [3. AUTO EQUIP LOOP]
task.spawn(function()
	while task.wait(0.5) do
		if farming and selectedWeapon ~= "" then
			local char = player.Character
			if char then
				local backpack = player:FindFirstChild("Backpack")
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and backpack then
					local weapon = backpack:FindFirstChild(selectedWeapon) or char:FindFirstChild(selectedWeapon)
					if weapon and weapon.Parent ~= char then
						hum:EquipTool(weapon)
					elseif not weapon then
						pcall(function() equipRemote:FireServer("Equip", selectedWeapon) end)
					end
				end
			end
		end
	end
end)

-- [4. AUTO HAKI & SKILLS]
task.spawn(function()
	while task.wait(1.5) do
		if farming and currentTarget then
			local char = player.Character
			if char and char:FindFirstChildOfClass("Humanoid") and char.Humanoid.Health > 0 then
				if haki then pcall(function() hakiRemote:FireServer("Toggle") end) end
				for k,v in pairs(skills) do
					if v then pcall(function() skillRemote:FireServer(skillIndex[k]) end) end
				end
			end
		end
	end
end)
