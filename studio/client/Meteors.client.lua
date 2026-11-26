-- Meteors · P1 第 21 项 全局氛围：流星（StarterPlayer.StarterPlayerScripts）
-- 客户端每 2–6.5 s 在远空随机生成一颗流星：发光头 + 拖尾（约 140 格长），1.2 s 划过后消失。
-- 数值沿用 Web Demo（出生在半径 900、高 450–1150 的天球上，速度 760 格/秒，斜向下飞），乘场景放大 1.3。
-- 只在本地生成，不进物理、不碰撞；相机看不到的方向也照常生成（便宜）。

local RunService = game:GetService("RunService")

local S = 1.3
local folder = Instance.new("Folder")
folder.Name = "_Meteors"
folder.Archivable = false
folder.Parent = workspace

local NSK = NumberSequenceKeypoint.new
local COLORS = { Color3.fromRGB(230, 244, 255), Color3.fromRGB(255, 236, 200), Color3.fromRGB(214, 200, 255) }

local function spawnMeteor()
	local a = math.random() * math.pi * 2
	local p = Vector3.new(math.cos(a) * 900, 450 + math.random() * 700, math.sin(a) * 900 - 250) * S
	local d = Vector3.new(math.random() - 0.5, -0.3 - math.random() * 0.35, math.random() - 0.5).Unit
	local col = COLORS[math.random(#COLORS)]
	local head = Instance.new("Part")
	head.Name = "Meteor"
	head.Shape = Enum.PartType.Ball
	head.Anchored, head.CanCollide, head.CanQuery, head.CanTouch, head.CastShadow = true, false, false, false, false
	head.Material = Enum.Material.Neon
	head.Color = col
	head.Size = Vector3.new(8, 8, 8) -- 远在 1200–1500 格外，要够大才看得见
	head.CFrame = CFrame.lookAt(p, p + d)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 3.5, 0), Vector3.new(0, -3.5, 0)
	a0.Parent, a1.Parent = head, head
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.18 -- 760 × 1.3 格/秒 × 0.18 s ≈ 180 格的拖尾
	tr.FaceCamera = true
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.Color = ColorSequence.new(Color3.new(1, 1, 1), col)
	tr.WidthScale = NumberSequence.new({ NSK(0, 1), NSK(1, 0) })
	tr.Transparency = NumberSequence.new({ NSK(0, 0), NSK(1, 1) })
	tr.Parent = head
	head.Parent = folder
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 1.2 then
			conn:Disconnect()
			head:Destroy()
			return
		end
		-- 亮度先亮后暗（Web：sin(πt / 1.2)）
		local k = math.sin(t / 1.2 * math.pi)
		head.Transparency = 1 - k
		tr.Transparency = NumberSequence.new({ NSK(0, 1 - k), NSK(1, 1) })
		head.CFrame = CFrame.lookAt(p + d * (t * 760 * S), p + d * (t * 760 * S + 1))
	end)
end

task.wait(1.5)
while true do
	spawnMeteor()
	task.wait(2 + math.random() * 4.5)
end
