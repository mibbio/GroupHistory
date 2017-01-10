local ADDON, Addon = ...

local CHOICES_AGE = {
  { num = 604800,  label = '1 week' },
  { num = 1209600, label = '2 weeks' },
  { num = 2592000, label = '1 month' },
  { num = 5184000, label = '2 months' },
  { num = 0,       label = 'forever' },
}

Addon.Vars = {
  MinimapPos = 45,
  CfgVersion = 2,
  MaxAge = CHOICES_AGE[5].num,
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

function GroupHistoryGroupEntryDelete_OnClick(caller, button)
  local pos = caller:GetParent().groupIndex
end

-----------------
-- DropdownAge --
-----------------
function GroupHistoryAgeDropdown_Initialize(self)
  local info = UIDropDownMenu_CreateInfo()

  info.disabled = nil
  info.isTitle  = nil
  info.func     = GroupHistoryAgeDropdownOptionClicked

  for _, v in ipairs(CHOICES_AGE) do
    info.text = v.label
    info.value = v.num
    info.checked = (v.num == Addon.Vars.MaxAge)
    UIDropDownMenu_AddButton(info)
  end
end

function GroupHistoryAgeDropdown_OnEvent(self, event, ...)
  if (event == 'PLAYER_ENTERING_WORLD') then
    self.value = 7
    if (Addon.Vars.MaxAge) then
      for _,v in ipairs(CHOICES_AGE) do
        if (v.num == Addon.Vars.MaxAge) then self.value = v.num break end
      end
    end
    self.tooltip = 'Delete entries older than'

    UIDropDownMenu_SetWidth(self, 100)
    UIDropDownMenu_Initialize(self, GroupHistoryAgeDropdown_Initialize)
    UIDropDownMenu_SetSelectedValue(self, self.value)

    self.SetValue =
      function(self, value)
        self.value = value
        Addon.Vars.MaxAge = value
        UIDropDownMenu_SetSelectedValue(self, value)
      end
    self.GetValue =
      function(self)
        return UIDropDownMenu_GetSelectedValue(self)
      end
  end
  self:UnregisterEvent(event)
end

function GroupHistoryAgeDropDownOptionClicked(self)
  GroupHistoryAgeDropDown:SetValue(self.value)
end

------------------------
-- DropdownCharfilter --
------------------------
function GroupHistoryFilterDropdown_Initialize(self)
  local info = UIDropDownMenu_CreateInfo()

  info.disabled = nil
  info.isTitle  = nil
  info.func     = GroupHistoryFilterDropdownOptionClicked

  for _,charname in pairs(Addon.Vars.Chars) do
    info.text = charname
    info.value = charname
    info.checked = ((Addon.Vars.SelectedChar) and (Addon.Vars.SelectedChar == charname))
    UIDropDownMenu_AddButton(info)
  end

  info.text = 'All'
  info.value = 'ALL'
  info.checked = ((not Addon.Vars.SelectedChar) or (Addon.Vars.SelectedChar == 'ALL') or (#Addon.Vars.Chars == 0))
  UIDropDownMenu_AddButton(info)
end

function GroupHistoryFilterDropdown_OnEvent(self, event, ...)
  if (event == 'PLAYER_ENTERING_WORLD') then
    if (Addon.Vars.SelectedChar ~= 'ALL') then self.value = Addon.Vars.SelectedChar else self.value = 'ALL' end
    self.tooltip = 'Filter entries by character'
    UIDropDownMenu_SetWidth(self, 150)
    UIDropDownMenu_Initialize(self, GroupHistoryFilterDropdown_Initialize)
    UIDropDownMenu_SetSelectedValue(self, self.value)

    self.SetValue =
      function(self, value)
        self.value = value
        Addon.Vars.SelectedChar = value
        UIDropDownMenu_SetSelectedValue(self, value)
      end
    self.GetValue =
      function(self)
        return UIDropDownMenu_GetSelectedValue(self)
      end
  end
  self:UnregisterEvent(event)
end

function GroupHistoryFilterDropdownOptionClicked(self)
  GroupHistoryFilterDropdown:SetValue(self.value)
end

-------------------
-- main function --
-------------------
function Addon:Setup()
  self.Frame.content.settingsButton:SetText('<< Settings')
  self.Frame.content.settingsButton:SetScript('OnClick', function(btn)
    if self.Frame.settings:IsVisible() then
      self.Frame.settings:Hide()
      btn:SetText('<< Settings')
    else
      self.Frame.settings:Show()
      btn:SetText('>> Settings')
    end
  end)

  ---------------------------
  -- Setup Settings Frame --
  ---------------------------
  local settingsFrame = self.Frame.settings
  settingsFrame:Hide()
  settingsFrame.title:SetText('Settings')
  local ageDropdown = CreateFrame('Frame', 'GroupHistoryAgeDropdown', settingsFrame, 'UIDropDownMenuTemplate')
  ageDropdown:RegisterEvent('PLAYER_ENTERING_WORLD')
  ageDropdown:SetPoint('TOPLEFT', 0, -64)
  ageDropdown.type = CONTROLTYPE_DROPDOWN

  ageDropdown:SetScript('OnEnter', function(dropdown)
    if (not dropdown.isDisabled) then
      GameTooltip:SetOwner(dropdown, 'ANCHOR_TOPRIGHT')
      GameTooltip:SetText(dropdown.tooltip, nil, nil, nil, nil, true)
    end
  end)
  ageDropdown:SetScript('OnLeave', function()
    GameTooltip:Hide()
  end)
  ageDropdown:SetScript('OnEvent', GroupHistoryAgeDropdown_OnEvent)
  ageDropdown.label = ageDropdown:CreateFontString(nil, nil, 'GameFontHighlightLeft')
  ageDropdown.label:SetText('Keep log entries')
  ageDropdown.label:SetPoint('BOTTOMLEFT', ageDropdown, 'TOPLEFT', 20, 4)

  --------------------------
  -- Char filter dropdown --
  --------------------------
  local filterDropdown = CreateFrame('Frame', 'GroupHistoryFilterDropdown', self.Frame.content, 'UIDropDownMenuTemplate')
  filterDropdown:RegisterEvent('PLAYER_ENTERING_WORLD')
  filterDropdown:SetPoint('TOPLEFT', 0, -16)

  filterDropdown:SetScript('OnEnter', function(dropdown)
    if (not dropdown.isDisabled) then
      GameTooltip:SetOwner(dropdown, 'ANCHOR_TOPRIGHT')
      GameTooltip:SetText(dropdown.tooltip, nil, nil, nil, nil, true)
    end
  end)
  filterDropdown:SetScript('OnLeave', function()
    GameTooltip:Hide()
  end)
  filterDropdown:SetScript('OnEvent', GroupHistoryFilterDropdown_OnEvent)

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

    Addon:Setup()
  elseif (event == 'ZONE_CHANGED_NEW_AREA') or (event == 'GROUP_ROSTER_UPDATE') then
    Addon:ProcessChanges(event)
  end
end)

Addon.Frame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
Addon.Frame:RegisterEvent('GROUP_ROSTER_UPDATE')

-- http://wowprogramming.com/docs/api/NotifyInspect