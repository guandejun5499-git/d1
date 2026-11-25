--[[
	Orbit Roll · 任务一 · 01 太空氛围（Lighting / Sky / Atmosphere / 后处理）
	在 Studio 命令栏或 MCP execute_luau 中运行；可重复运行（会先清掉旧的同类对象）。

	光照质量：新版 Studio 已用 LightingStyle（Realistic / Soft）+ PrioritizeLightingQuality 取代 Technology。
	本项目用 LightingStyle = Soft 并勾选 PrioritizeLightingQuality（在 Lighting 属性面板设置）。
	天空盒：优先使用 ServerStorage.WorldAssets 里的 Sky（Creator Store「Purple Nebula Space Skybox」by Zalthen，纯 Sky 实例，无脚本）。
]]

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local function hex(s) return Color3.fromHex(s) end

-- 清掉旧的天空 / 大气 / 后处理
for _, c in ipairs(Lighting:GetChildren()) do
	if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") then
		c:Destroy()
	end
end

-- 夜空基调。注意：Roblox 在夜间（ClockTime 0 附近）会隐藏自定义天空盒，只剩纯黑，
-- 所以这里用白天时段 + 隐藏太阳 + 紫色色偏来做「深紫星空」，阳光当作柔和的主光。
Lighting.ClockTime = 14.5
Lighting.GeographicLatitude = 23
Lighting.Brightness = 1.6
Lighting.Ambient = hex("4A4472")
Lighting.OutdoorAmbient = hex("8E88B4")  -- 偏灰的淡紫；更饱和会把地面染成一片紫
Lighting.ColorShift_Top = hex("E4DCFF")
Lighting.ColorShift_Bottom = hex("2A1E55")
Lighting.EnvironmentDiffuseScale = 0.55
Lighting.EnvironmentSpecularScale = 0.45
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.35
Lighting.ExposureCompensation = 0.25
Lighting.FogEnd = 100000

-- 天空盒
local assets = ServerStorage:FindFirstChild("WorldAssets")
local skySrc = assets and assets:FindFirstChild("SpaceSky")
local sky = skySrc and skySrc:Clone() or Instance.new("Sky")
sky.Name = "SpaceSky"
sky.CelestialBodiesShown = false -- 月球、木星用场景里的实体
sky.StarCount = 3000
sky.Parent = Lighting

-- 不加 Atmosphere：白天时段的大气会把星云天空盒冲成一片灰雾。

-- 后处理（美术方向 A2 指定参数）
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.7
bloom.Size = 28
bloom.Threshold = 1.6
bloom.Parent = Lighting

local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.12
cc.Contrast = 0.08
cc.Brightness = 0.02
cc.TintColor = hex("F4F0FF")
cc.Parent = Lighting

return "atmosphere ok"
