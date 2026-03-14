local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

local hitRemote = RS.CombatSystem.Remotes.RequestHit
local skillRemote = RS.AbilitySystem.Remotes.RequestAbility
local hakiRemote = RS.RemoteEvents.HakiRemote
local equipRemote = RS.Remotes:WaitForChild("EquipWeapon")

local farming = false
local selectedMobs = {} -- [NEW] เปลี่ยนเป็น Table เพื่อเก็บหลายเป้าหมาย
local currentTarget = nil -- [NEW] ตัวแปรล็อคเป้าหมายปัจจุบันเพื่อความเสถียร
local haki = false

local skills = {Z=false, X=false, C=false, V=false, B=false}
local skillIndex = {Z=1, X=2, C=3, V=4, B=5}
local skillOrder = {"Z", "X", "C", "V", "B"} 

-- หา root part
local function getRoot(mob)
	return mob:FindFirstChild("HumanoidRootPart")
	or mob:FindFirstChild("RootPart")
	or mob:FindFirstChild("Torso")
	or mob:FindFirstChild("UpperTorso")
end

-- [NEW] ฟังก์ชันเช็คว่ามอนสเตอร์ตัวนี้อยู่ในลิสต์ที่เราเลือกไว้ไหม
local function isMobSelected(mobName)
	for selectedName, _ in pairs(selectedMobs) do
		if mobName:lower():find(selectedName:lower()) then
			return true
		end
	end
	return false
end

-- [NEW] ระบบหาเป้าหมายแบบเสถียร (ล็อคเป้าจนกว่าจะตาย)
local function getValidTarget()
	-- 1. เช็คเป้าหมายเดิมก่อนว่ายังมีชีวิตและอยู่ในระยะไหม
	if currentTarget and currentTarget.Parent then
		local hum = currentTarget:FindFirstChildOfClass("Humanoid")
		local hrp = getRoot(currentTarget)
		if hum and hrp and hum.Health > 0 and isMobSelected(currentTarget.Name) then
			return currentTarget -- ตีตัวเดิมต่อไปเพื่อความเสถียร
		end
	end

	-- 2. ถ้าเป้าหมายเดิมตาย หรือยังไม่มีเป้าหมาย ให้หาตัวใหม่ที่อยู่ในลิสต์
	currentTarget = nil
	for _,mob in pairs(workspace.NPCs:GetChildren()) do
		if isMobSelected(mob.Name) then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			local hrp = getRoot(mob)
			if hum and hrp and hum.Health > 0 then
				currentTarget = mob
				return currentTarget
			end
		end
	end
	return nil
end

---------------------------------------------------------
-- GUI SECTION (MODERNIZED)
---------------------------------------------------------
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "AutoFarmHub"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 300, 0, 380)
frame.Position = UDim2.new(0.5, -150, 0.5, -190)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(60, 60, 60)
stroke.Thickness = 1.5

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

local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = i.Position
		startPos = frame.Position
	end
end)
title.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = i.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

local search = Instance.new("TextBox", frame)
search.Size = UDim2.new(1, -30, 0, 30)
search.Position = UDim2.new(0, 15, 0, 55)
search.PlaceholderText = "🔍 Search Mob..."
search.Text = ""
search.Font = Enum.Font.Gotham
search.TextSize = 14
search.TextColor3 = Color3.fromRGB(255, 255, 255)
search.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 6)
local searchStroke = Instance.new("UIStroke", search)
searchStroke.Color = Color3.fromRGB(70, 70, 70)
searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local targetLabel = Instance.new("TextLabel", frame)
targetLabel.Size = UDim2.new(1, -30, 0, 20)
targetLabel.Position = UDim2.new(0, 15, 0, 95)
targetLabel.Text = "Targets: None"
targetLabel.Font = Enum.Font.GothamSemibold
targetLabel.TextSize = 13
targetLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
targetLabel.BackgroundTransparency = 1
targetLabel.TextXAlignment = Enum.TextXAlignment.Left

local dropdown = Instance.new("ScrollingFrame", frame)
dropdown.Size = UDim2.new(1, -30, 0, 120)
dropdown.Position = UDim2.new(0, 15, 0, 120)
dropdown.ScrollBarThickness = 4
dropdown.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
dropdown.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
dropdown.BorderSizePixel = 0
Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 6)

local listPadding = Instance.new("UIPadding", dropdown)
listPadding.PaddingTop = UDim.new(0, 5)
listPadding.PaddingBottom = UDim.new(0, 5)
listPadding.PaddingLeft = UDim.new(0, 5)
listPadding.PaddingRight = UDim.new(0, 5)

local layout = Instance.new("UIListLayout", dropdown)
layout.Padding = UDim.new(0, 5)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	dropdown.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)

local mobButtons = {}

-- [NEW] อัพเดทข้อความแสดงผลมอนสเตอร์ที่เลือก
local function updateTargetLabel()
	local selectedNames = {}
	for name, _ in pairs(selectedMobs) do
		table.insert(selectedNames, name)
	end
	
	if #selectedNames == 0 then
		targetLabel.Text = "Targets: None"
		targetLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	else
		local text = "Targets: " .. table.concat(selectedNames, ", ")
		if #text > 40 then
			text = text:sub(1, 37) .. "..." -- ตัดคำถ้าชื่อยาวเกินไป
		end
		targetLabel.Text = text
		targetLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
end

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
				btn.Size = UDim2.new(1, 0, 0, 25)
				btn.Text = clean
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 13
				btn.TextColor3 = Color3.fromRGB(220, 220, 220)
				-- เช็คว่าเคยเลือกไว้ไหมเพื่อแสดงสีให้ถูกต้องตอนพิมพ์ค้นหา
				btn.BackgroundColor3 = selectedMobs[clean] and Color3.fromRGB(0, 130, 0) or Color3.fromRGB(45, 45, 45)
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

				-- [NEW] ระบบปุ่มเปิด/ปิดเป้าหมาย
				btn.MouseButton1Click:Connect(function()
					if selectedMobs[clean] then
						selectedMobs[clean] = nil -- เอาออกถ้ากดซ้ำ
						btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
					else
						selectedMobs[clean] = true -- เพิ่มเข้าไปในลิสต์
						btn.BackgroundColor3 = Color3.fromRGB(0, 130, 0)
					end
					updateTargetLabel()
				end)
				table.insert(mobButtons, btn)
			end
		end
	end
end

search:GetPropertyChangedSignal("Text"):Connect(refreshList)
refreshList()

local start = Instance.new("TextButton", frame)
start.Size = UDim2.new(1, -30, 0, 35)
start.Position = UDim2.new(0, 15, 0, 255)
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
	else
		start.Text = "START FARM"
		start.BackgroundColor3 = Color3.fromRGB(0, 130, 255)
		currentTarget = nil -- รีเซ็ตเป้าหมายเมื่อหยุดฟาร์ม
	end
end)

local skillsContainer = Instance.new("Frame", frame)
skillsContainer.Size = UDim2.new(1, -30, 0, 35)
skillsContainer.Position = UDim2.new(0, 15, 0, 305)
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
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	
	local btnStroke = Instance.new("UIStroke", btn)
	btnStroke.Color = Color3.fromRGB(80, 80, 80)
	
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
	end)
end

for _, key in ipairs(skillOrder) do
	createSkillButton(key, false)
end
createSkillButton("G", true)

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
	if frame then
		frame.Visible = not frame.Visible
	end
end)

task.spawn(function()
	while task.wait(0.5) do
		if farming then
			local char = player.Character
			local backpack = player:FindFirstChild("Backpack")

			if char and backpack then
				local hum = char:FindFirstChildOfClass("Humanoid")

				local weapon =
					backpack:FindFirstChild("Ichigo") or
					char:FindFirstChild("Ichigo")

				if weapon then
					if weapon.Parent ~= char then
						hum:EquipTool(weapon)
					end
				else
					equipRemote:FireServer("Equip","Ichigo")
				end
			end
		end
	end
end)

task.spawn(function()
	while task.wait(2) do
		if farming and haki then
			hakiRemote:FireServer("Toggle")
		end
	end
end)

task.spawn(function()
	while task.wait(3) do
		if farming then
			for k,v in pairs(skills) do
				if v then
					skillRemote:FireServer(skillIndex[k])
				end
			end
		end
	end
end)

-- [NEW] อัพเดท Farm Loop สำหรับรองรับหลายมอนสเตอร์
task.spawn(function()
	while task.wait(0.05) do
		-- ตรวจสอบว่ามีมอนสเตอร์ถูกเลือกอย่างน้อย 1 ตัว
		local hasSelected = false
		for _, _ in pairs(selectedMobs) do hasSelected = true break end

		if farming and hasSelected then
			local target = getValidTarget()
			if target then
				local hrp = getRoot(target)
				if hrp then
					-- หันหน้าเข้าหาเป้าหมายตลอดด้วย CFrame
					root.CFrame = hrp.CFrame * CFrame.new(0, 6, 0)
					hitRemote:FireServer()
				end
			end
		end
	end
end)