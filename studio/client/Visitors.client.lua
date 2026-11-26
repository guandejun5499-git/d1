-- Visitors · P1 第 19 项 围观访客（StarterPlayer.StarterPlayerScripts）
-- 启动 VisitorShow 的每帧更新：各家 3 名访客待机摆臂；发射 / 接住 / 坠毁演出里调 VS.cheer / VS.knock 触发欢呼和掀翻。
local VS = require(game:GetService("ReplicatedStorage"):WaitForChild("OrbitShared"):WaitForChild("VisitorShow"))
VS.start()
