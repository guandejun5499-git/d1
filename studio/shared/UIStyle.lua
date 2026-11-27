local Gui=game:GetService("GuiService")
local Style={
	font=Enum.Font.GothamBold, ink=Color3.fromRGB(255,249,229), panel=Color3.fromRGB(24,33,52),
	accent=Color3.fromRGB(192,80,16), edge=Color3.fromRGB(92,119,146), radius=8,
}
function Style.apply(o)
	o.Font=Style.font
	o.TextColor3=Style.ink
	o.BackgroundColor3=Style.panel
	o.BorderSizePixel=0
	local corner=o:FindFirstChildOfClass("UICorner") or Instance.new("UICorner",o)
	corner.CornerRadius=UDim.new(0,Style.radius)
	local stroke=o:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke",o)
	stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	stroke.Color=Style.edge stroke.Thickness=1.5 stroke.Transparency=.35
end
function Style.reduced()
	return Gui.ReducedMotionEnabled
end
return Style
