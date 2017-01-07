local ADDON, Addon = ...

local MinimapButton = _G[ADDON..'MinimapButton']

function MinimapButton:Reposition()
  self:SetPoint('TOPLEFT', 'Minimap', 'TOPLEFT',52-(80*cos(Addon.Vars.MinimapPos)), (80*sin(Addon.Vars.MinimapPos))-52)
end

function MinimapButton:DragUpdate()
  local xpos, ypos = GetCursorPosition()
  local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
  xpos = xmin-xpos /UIParent:GetScale() + 70
  ypos = ypos / UIParent:GetScale() - ymin - 70
  Addon.Vars.MinimapPos = math.deg(math.atan2(ypos,xpos))
  self:Reposition()
end

function MinimapButton:OnClick()
  Addon:ToggleVisibility()
end

MinimapButton:RegisterEvent('ADDON_LOADED')

MinimapButton.DraggingFrame:SetScript('OnUpdate', function(self)
  MinimapButton:DragUpdate()
end)

MinimapButton:SetScript('OnClick', function(self)
  self:OnClick()
end)

MinimapButton:SetScript('OnEnter', function(self)
  GameTooltip:ClearLines()
  GameTooltip:SetOwner(self, 'ANCHOR_CURSOR')
  GameTooltip:AddLine(Addon.Name, 1, 1, 1)
  GameTooltip:AddLine('Click to show history.\nHold left mousebutton to drag icon.')
  GameTooltip:Show()
end)

MinimapButton:SetScript('OnLeave', function(self)
  GameTooltip:Hide()
end)

MinimapButton:SetScript('OnEvent', function(self, event, ...)
  if self:IsEventRegistered(event) then self:UnregisterEvent(event) end
  self:Reposition()
end)