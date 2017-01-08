local ADDON, Addon = ...

Addon.Vars = {
  MinimapPos = 45,
  CfgVersion = 2
}
Addon.Session = {
  ID = 0,
  Group = {}
}
Addon.Groups = {}

GroupHistory_Vars = Addon.Vars
GroupHistory_Session = Addon.Session
GroupHistory_Groups = Addon.Groups

Addon.Name = GetAddOnMetadata(ADDON, 'Title')
Addon.Version = GetAddOnMetadata(ADDON, 'X-Package-Version')
Addon.Frame = _G[ADDON..'Container']

Addon.Frame:RegisterEvent('ADDON_LOADED')

local MAX_ROWS = 6
local ROW_HEIGHT = 60
local ROW_WIDTH = 300
local STATUS_TIMEOUT = 30

function Addon:ToggleVisibility()
  if Addon.Frame:IsVisible() then
    Addon.Frame:Hide()
  else
    Addon.Frame:Show()
  end
end

function Addon.ShowGroup(source)
  local memberList = _G[Addon.Frame:GetName()..'MemberFrame']
  memberList:SetID(source:GetID())
  if memberList:IsVisible() then
    memberList:Update()
  else
    memberList:Show()
  end
end

function GroupHistoryGroupEntryDelete_OnClick(caller, button)
  local pos = caller:GetParent().groupIndex
end

function Addon:ProcessChanges(event)
  local guids = GroupHistory_Helper.GetGroupGUIDs()
  if (#guids == 0) then
    self.Session.ID = 0
    self.Session.Group = {}
    return
  end

  SetMapToCurrentZone()
  local save = false
  local replace = false
  local instanceID = EJ_GetCurrentInstance()
  local changedGroup = not GroupHistory_Helper.IsEqualGroup(guids, Addon.Session.Group)

  if (event == 'GROUP_ROSTER_UPDATE') and (changedGroup) then
    replace = (#self.Session.Group > 0)
    if IsInInstance() then
      save = (#guids >= #self.Session.Group)
      self.Session.ID = instanceID
    end
    self.Session.Group = guids
  end

  if (event == 'ZONE_CHANGED_NEW_AREA') and IsInInstance() then
    if (instanceID > 0) and (self.Session.ID ~= instanceID) then
      self.Session.ID = instanceID
      self.Session.Group = guids
      save = true
    end
  end

  if save then
    local entry = {}
    if replace and (#self.Groups > 0) then
      entry = table.remove(self.Groups)
    else
      entry.time = time()
      entry.id = instanceID
    end
    entry.players = GroupHistory_Helper.GetPlayerList()
    table.insert(self.Groups, entry)
  end
end

local function DeleteGroup(pos)
  if GroupHistory_Helper.tcount(GroupHistory_Groups) >= num then
    table.remove(GroupHistory_Groups, pos)
    _G[Addon.Frame:GetName()..'GroupFrame']:Update()
  end
end

function Addon:Setup()
  DEFAULT_CHAT_FRAME:AddMessage(
    format('|c%s%s|r |c%sv%s|r |c%sloaded.|r',
      GroupHistory_Helper.Colors['ORANGE'], Addon.Name,
      GroupHistory_Helper.Colors['BLUE'], Addon.Version,
      GroupHistory_Helper.Colors['GREEN']
    )
  )

  -----------------------
  -- Create Group List --
  -----------------------
  local groupFrame = CreateFrame('Frame', '$parentGroupFrame', self.Frame.content)
  groupFrame:SetSize(ROW_WIDTH, ROW_HEIGHT * MAX_ROWS + 18)
  groupFrame:SetPoint('TOPLEFT', 16, -16)
  groupFrame:SetBackdrop({
	  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
	  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
	  insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })

  function groupFrame:Update()
    local maxValue = #Addon.Groups
    FauxScrollFrame_Update(self.scrollBar, maxValue, MAX_ROWS, ROW_HEIGHT + 2)
    local withBar = _G[self:GetName()..'ScrollBar']:IsVisible()
    local offset = FauxScrollFrame_GetOffset(self.scrollBar)
    for i = 1, MAX_ROWS do
      local value = i + offset
      if value <= maxValue then
        local row = self.rows[i]
        local instanceName, _, _, buttonTexture = EJ_GetInstanceInfo(Addon.Groups[value].id)
        local regions = { row:GetRegions() }
        for _, region in pairs(regions) do
          if region:GetName() == row:GetName()..'Icon' then
            region:SetTexture(buttonTexture)
          elseif region:GetName() == row:GetName()..'Date' then
            region:SetText(GroupHistory_Helper.LocalizedDate(Addon.Groups[value].time))
          elseif region:GetName() == row:GetName()..'Instance' then
            region:SetText(instanceName)
          end
        end
        row.groupIndex = value
        if withBar then
          row:SetWidth(ROW_WIDTH - 28)
        else
          row:SetWidth(ROW_WIDTH - 8)
        end
        row:Show()
      else
        self.rows[i]:Hide()
      end
    end
  end

  -- Create Group Scrollbar
  local groupBar = CreateFrame('ScrollFrame', '$parentScrollBar', groupFrame, 'FauxScrollFrameTemplate')
  groupBar:SetPoint('TOPLEFT', 0, -8)
  groupBar:SetPoint('BOTTOMRIGHT', -28, 8)
  groupBar:SetScript('OnVerticalScroll', function(self, offset)
    self.offset = math.floor(offset / ROW_HEIGHT + 0.5)
    groupFrame:Update()
  end)
  groupBar:SetScript('OnShow', function()
    groupFrame:Update()
  end)
  groupFrame.scrollBar = groupBar

  local groupRows = setmetatable({}, { __index = function(t, i)
    local row = CreateFrame('Button', '$parentRow'..i, groupFrame, 'GroupHistoryGroupEntryTemplate')
    row:SetID(i)
    row:SetSize(ROW_WIDTH - 28, ROW_HEIGHT)
    if i == 1 then
      row:SetPoint('TOPLEFT', groupFrame, 4, -4)
    else
      row:SetPoint('TOPLEFT', groupFrame.rows[i-1], 'BOTTOMLEFT', 0, -2)
    end
    row:SetScript('OnClick', Addon.ShowGroup)
    rawset(t, i, row)
    return row
  end})
  groupFrame.rows = groupRows

  ------------------------
  -- Create Member List --
  ------------------------
  local memberFrame = CreateFrame('Frame', '$parentMemberFrame', Addon.Frame.content)
  memberFrame:SetSize(ROW_WIDTH, ROW_HEIGHT * MAX_ROWS + 18)
  memberFrame:SetPoint('TOPRIGHT', -16, -16)
  memberFrame:SetBackdrop({
	  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
	  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
	  insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })

  function memberFrame:Update()
    if self:GetID() == 0 then return end
    local players = Addon.Groups[self:GetID()].players
    local maxValue = #players
    FauxScrollFrame_Update(self.scrollBar, maxValue, MAX_ROWS, ROW_HEIGHT + 2)
    local withBar = _G[self:GetName()..'ScrollBar']:IsVisible()
    local offset = FauxScrollFrame_GetOffset(self.scrollBar)
    for i = 1, MAX_ROWS do
      local value = i + offset
      if value <= maxValue then
        local row = self.rows[i]

        row.player = players[value][1]
        row.realm = players[value][2]
        row.fullName = players[value][1]..(players[value][2] ~= '' and '-'..players[value][2] or '')

        row.playerLabel:SetText(row.fullName)
        row.classLabel:SetFormattedText(format('|cffffffff%d %s|r %s', players[value][3], players[value][4], players[value][5]))

        if withBar then
          row:SetWidth(ROW_WIDTH - 28)
        else
          row:SetWidth(ROW_WIDTH - 8)
        end
        row:Show()
      else
        self.rows[i]:Hide()
      end
    end
  end

  local memberBar = CreateFrame('ScrollFrame', '$parentScrollBar', memberFrame, 'FauxScrollFrameTemplate')
  memberBar:SetPoint('TOPLEFT', 0, -8)
  memberBar:SetPoint('BOTTOMRIGHT', -28, 8)
  memberBar:SetScript('OnVerticalScroll', function(self, offset)
    self.offset = math.floor(offset / ROW_HEIGHT + 0.5)
    memberFrame:Update()
  end)
  memberBar:SetScript('OnShow', function() memberFrame:Update() end)
  memberFrame.scrollBar = memberBar

  local memberRows = setmetatable({}, { __index = function(t, i)
    local row = CreateFrame('Button', '$parentRow'..i, memberFrame, 'GroupHistoryMemberEntryTemplate')
    row:SetSize(ROW_WIDTH - 28, ROW_HEIGHT)
    if i == 1 then
      row:SetPoint('TOPLEFT', memberFrame, 4, -4)
    else
      row:SetPoint('TOPLEFT', memberFrame.rows[i-1], 'BOTTOMLEFT', 0, -2)
    end
    rawset(t, i, row)
    return row
  end})
  memberFrame.rows = memberRows
end

function Addon:ConfirmDialog(msg, callback)
  local confirmFrame = _G[ADDON..'ConfirmDialog']
  if not confirmFrame then
    confirmFrame = CreateFrame('FRAME', ADDON..'ConfirmDialog', UIParent, ADDON..'ConfirmTemplate')
  end
  confirmFrame.Title:SetText(Addon.Name..' Update Info')
  confirmFrame.TextSection:SetText(msg)
  confirmFrame.Confirm:SetText('Confirm')

  confirmFrame.Confirm:SetScript('OnClick', function()
    confirmFrame:Hide()
    if callback then callback(true) end
  end)
  confirmFrame:Show()
end

Addon.Frame:SetScript('OnEvent', function(self, event, ...)
  if event == 'ADDON_LOADED' then
    Addon.Frame:UnregisterEvent('ADDON_LOADED')
    if not GroupHistory_Vars.CfgVersion then
      GroupHistory_Vars.CfgVersion = Addon.Vars.CfgVersion
      GroupHistory_Groups = {}
      Addon:ConfirmDialog('Config format has changed!|n|nDeleting all saved groups.')
    end
    Addon.Vars = GroupHistory_Vars
    Addon.Groups = GroupHistory_Groups
    Addon.Session = GroupHistory_Session
    Addon:Setup()
  elseif (event == 'ZONE_CHANGED_NEW_AREA') or (event == 'GROUP_ROSTER_UPDATE') then
    Addon:ProcessChanges(event)
  end
end)

Addon.Frame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
Addon.Frame:RegisterEvent('GROUP_ROSTER_UPDATE')

-- http://wowprogramming.com/docs/api/NotifyInspect