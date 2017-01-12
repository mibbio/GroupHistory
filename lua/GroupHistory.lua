local ADDON, Addon = ...

Addon.Vars = {
  MinimapPos = 45,
  CfgVersion = 2,
  MaxAge = 0,
  Chars = {},
  SelectedChar = 'ALL'
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

Addon.selectedGroup = 0

function Addon:ToggleVisibility()
  if Addon.Frame:IsVisible() then
    Addon.Frame:Hide()
  else
    Addon.Frame:Show()
  end
end

function Addon.ShowGroup(source)
  local memberList = _G[Addon.Frame:GetName()..'MemberFrame']
  memberList:SetID(source.groupIndex)
  if memberList:IsVisible() then
    memberList:Update()
  else
    memberList:Show()
  end
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
      local playerRealm, playerName = GetRealmName(), UnitName('player')
      local fullname = playerName..'-'..playerRealm
      entry.time = time()
      entry.id = instanceID
      entry.character = fullname
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

function GroupHistoryGroupEntryDelete_OnClick(caller, button)
  local pos = caller:GetParent().groupIndex
end

-------------------
-- main function --
-------------------
function Addon:Setup()
  self.Frame.settings:Hide()
  self.Frame.settings.title:SetText('Settings')
  self.Frame.content.settingsButton:SetText('<< Settings')
  self.Frame.content.settingsButton:SetWidth(150)
  self.Frame.content.settingsButton:SetScript('OnClick', function(btn)
    if self.Frame.settings:IsVisible() then
      self.Frame.settings:Hide()
      btn:SetText('<< Settings')
    else
      self.Frame.settings:Show()
      btn:SetText('>> Settings')
    end
  end)

  -----------------------
  -- Create Group List --
  -----------------------
  local groupFrame = CreateFrame('Frame', '$parentGroupFrame', self.Frame.content)
  groupFrame:SetSize(ROW_WIDTH, ROW_HEIGHT * MAX_ROWS + 18)
  groupFrame:SetPoint('TOPLEFT', 16, -48)
  groupFrame:SetBackdrop({
	  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
	  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
	  insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })

  function groupFrame:Update()
    local filteredGroups = {}
    for k,g in pairs(Addon.Groups) do
      if (g.character == Addon.Vars.SelectedChar) or (not Addon.Vars.SelectedChar) or (Addon.Vars.SelectedChar == 'ALL') then
        table.insert(filteredGroups, {k, g})
      end
    end
    local maxValue = #filteredGroups
    FauxScrollFrame_Update(self.scrollBar, maxValue, MAX_ROWS, ROW_HEIGHT + 2)
    local withBar = _G[self:GetName()..'ScrollBar']:IsVisible()
    local offset = FauxScrollFrame_GetOffset(self.scrollBar)
    for i = 1, MAX_ROWS do
      local value = i + offset
      if value <= maxValue then
        local row = self.rows[i]
        local instanceName, _, _, buttonTexture = EJ_GetInstanceInfo(filteredGroups[value][2].id)
        local regions = { row:GetRegions() }
        for _, region in pairs(regions) do
          if region:GetName() == row:GetName()..'Icon' then
            region:SetTexture(buttonTexture)
          elseif region:GetName() == row:GetName()..'Date' then
            region:SetText(GroupHistory_Helper.LocalizedDate(filteredGroups[value][2].time))
          elseif region:GetName() == row:GetName()..'Instance' then
            region:SetText(instanceName)
          end
        end
        row.groupIndex = filteredGroups[value][1]
        row.tooltip = (filteredGroups[value][2].character ~= nil) and filteredGroups[value][2].character or 'No character assigned'
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
    row:SetSize(ROW_WIDTH - 28, ROW_HEIGHT)
    if i == 1 then
      row:SetPoint('TOPLEFT', groupFrame, 4, -4)
    else
      row:SetPoint('TOPLEFT', groupFrame.rows[i-1], 'BOTTOMLEFT', 0, -2)
    end
    row:SetScript('OnClick', Addon.ShowGroup)
    row:SetScript('OnEnter', function()
      GameTooltip:SetOwner(row, 'ANCHOR_CURSOR')
      GameTooltip:SetText(row.tooltip, nil, nil, nil, nil, true)
    end)
    row:SetScript('OnLeave', function() GameTooltip:Hide() end)
    rawset(t, i, row)
    return row
  end})
  groupFrame.rows = groupRows

  ------------------------
  -- Create Member List --
  ------------------------
  local memberFrame = CreateFrame('Frame', '$parentMemberFrame', Addon.Frame.content)
  memberFrame:SetSize(ROW_WIDTH, ROW_HEIGHT * MAX_ROWS + 18)
  memberFrame:SetPoint('TOPRIGHT', -16, -48)
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
        if (players[value][2]) and (string.len(players[value][2]) > 0) then
          row.fullName = players[value][1]..'-'..players[value][2]
        else
          row.fullName = players[value][1]
        end

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

Addon.Frame:SetScript('OnEvent', function(self, event, ...)
  if event == 'ADDON_LOADED' then
    Addon.Frame:UnregisterEvent('ADDON_LOADED')
    DEFAULT_CHAT_FRAME:AddMessage(format('|c%s%s|r |c%sv%s|r |c%sloaded.|r',
      GroupHistory_Helper.Colors['ORANGE'], Addon.Name,
      GroupHistory_Helper.Colors['BLUE'], Addon.Version,
      GroupHistory_Helper.Colors['GREEN']
    ))

    Addon.Vars = GroupHistory_Vars
    Addon.Groups = GroupHistory_Groups
    Addon.Session = GroupHistory_Session

    if not Addon.Vars.SelectedChar then Addon.Vars.SelectedChar = 'ALL' end

    local newChar = true
    local playerRealm, playerName = GetRealmName(), UnitName('player')
    local fullname = playerName..'-'..playerRealm
    if not Addon.Vars.Chars then Addon.Vars.Chars = {} end
    if #Addon.Vars.Chars > 0 then
      for _,v in ipairs(Addon.Vars.Chars) do
        if (v == fullname) then
          newChar = false
          break
        end
      end
    end
    if newChar then table.insert(Addon.Vars.Chars, fullname) end

    if (Addon.Vars.MaxAge) and (Addon.Vars.MaxAge > 0) then
      -- delete outdated logs
      local now = time()
      local dc = 0
      for i=#Addon.Groups, 1, -1 do
        local age = (now - Addon.Groups[i].time) / 86400
        if (now - Addon.Groups[i].time) >= Addon.Vars.MaxAge then
          table.remove(Addon.Groups, i)
          dc = dc + 1
        end
      end
      if dc > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(format('|c%s%s|r |c%s%d old entries removed.|r',
          GroupHistory_Helper.Colors['ORANGE'], Addon.Name,
          GroupHistory_Helper.Colors['GREEN'], dc
        ))
      end
    end

    if not GroupHistory_Vars.CfgVersion then
      GroupHistory_Vars.CfgVersion = Addon.Vars.CfgVersion
      GroupHistory_Groups = {}
    end

    local needMigration
    for k, g in pairs(Addon.Groups) do
      if (not g.character) then
        if not needMigration then needMigration = {} end
        table.insert(needMigration, k)
      end
    end
    if (needMigration) and (#needMigration > 0) then
      local btnMigrate = CreateFrame('BUTTON', nil, Addon.Frame.content, 'OptionsButtonTemplate')
      btnMigrate:SetPoint('TOPRIGHT', Addon.Frame.content, -16, -16)
      btnMigrate:SetWidth(200)
      btnMigrate:SetText('Migrate old logs')
      btnMigrate:SetScript('OnClick', function()
        Addon:MigrationDialog(needMigration, btnMigrate)
      end)
      Addon:MigrationDialog(needMigration, btnMigrate)
    end

    Addon:Setup()
  elseif (event == 'ZONE_CHANGED_NEW_AREA') or (event == 'GROUP_ROSTER_UPDATE') then
    Addon:ProcessChanges(event)
  end
end)

Addon.Frame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
Addon.Frame:RegisterEvent('GROUP_ROSTER_UPDATE')