local ADDON, Addon = ...

Addon.Vars = {
  MinimapPos = 45,
  CfgVersion = 2,
  Instance = 0
}
Addon.Groups = {}

GroupHistory_Vars = Addon.Vars
GroupHistory_Groups = Addon.Groups

Addon.Name = GetAddOnMetadata(ADDON, 'Title')
Addon.Version = GetAddOnMetadata(ADDON, 'X-Package-Version')
Addon.Frame = _G[ADDON..'Container']

Addon.Frame:RegisterEvent('ADDON_LOADED')

local MAX_ROWS = 6
local ROW_HEIGHT = 60
local ROW_WIDTH = 300
local STATUS_TIMEOUT = 30

local STATUS_TEXTURE = {
  'COMMON\\Indicator-Gray',
  'COMMON\\Indicator-Green'
}

-- functions
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
  --print('Delete entry #'..pos)
end

local function GroupOrInstanceEvent(event)

end

local function GroupOrInstanceChanged(event)
  SetMapToCurrentZone()
  local debug_name, instanceType, debug_diff = GetInstanceInfo()
  local instanceID = EJ_GetCurrentInstance()
  --print(format('%s | %s | %s | %d | %d', event, debug_name, instanceType, debug_diff, instanceID))

  local doUpdate = false

  if event == 'ZONE_CHANGED_NEW_AREA' then
    if not (IsInInstance() or IsInGroup()) then
      if (Addon.Frame:IsEventRegistered('GROUP_ROSTER_UPDATE')) then
        Addon.Frame:UnregisterEvent('GROUP_ROSTER_UPDATE')
      end
      GroupHistory_Vars.LastInstance = 0
      return
    else
      Addon.Frame:RegisterEvent('GROUP_ROSTER_UPDATE')
    end
  elseif event == 'GROUP_ROSTER_UPDATE' then
    GroupHistory_Vars.LastInstance = 0
    doUpdate = true
  else
   return
  end
  -- fix instanceid = 0 at mythic+ start
  if (instanceID ~= 0) and ((instanceID ~= GroupHistory_Vars.LastInstance) or doUpdate) then
    GroupHistory_Vars.LastInstance = instanceID
    if instanceType == 'party' or instanceType == 'raid' then
      local entry = {}
      entry.players = {}

      if doUpdate and (#GroupHistory_Groups > 0) and (GroupHistory_Groups[#GroupHistory_Groups].id == instanceID) then
        entry = table.remove(GroupHistory_Groups)
      else
        entry.time = time()
        entry.id = instanceID
      end

      local players = GH_Helper.GetPlayerList()
      if GH_Helper.tcount(players) >= GH_Helper.tcount(entry.players) then
        entry.players = players
      end
      table.insert(GroupHistory_Groups, entry)
    end
  end
end

local function DeleteGroup(pos)
  if GH_Helper.tcount(GroupHistory_Groups) >= num then
    table.remove(GroupHistory_Groups, pos)
    _G[Addon.Frame:GetName()..'GroupFrame']:Update()
  end
end

function Addon:Setup()
  self.Frame:UnregisterEvent('ADDON_LOADED')
  self.Frame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
  DEFAULT_CHAT_FRAME:AddMessage(
    format('|c'..GH_COLORS['ORANGE']..'%s|r |c'..GH_COLORS['BLUE']..'v%s|r |c'..GH_COLORS['GREEN']..'loaded.|r', Addon.Name, Addon.Version)
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
            region:SetText(GH_Helper.LocalizedDate(Addon.Groups[value].time))
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
-- end functions

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
    if not GroupHistory_Vars.CfgVersion then
      GroupHistory_Vars.CfgVersion = Addon.Vars.CfgVersion
      GroupHistory_Groups = {}
      Addon:ConfirmDialog('Config format has changed!|n|nDeleting all saved groups.')
    end
    Addon.Vars = GroupHistory_Vars
    Addon.Groups = GroupHistory_Groups
    Addon:Setup()
  elseif (event == 'ZONE_CHANGED_NEW_AREA') or (event == 'GROUP_ROSTER_UPDATE') then
    GroupOrInstanceChanged(event)
  end
end)

-- http://wowprogramming.com/docs/api/NotifyInspect