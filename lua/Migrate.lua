local ADDON, Addon = ...

local function GroupHistoryCharMigrateInitialize(self)
  local info = UIDropDownMenu_CreateInfo()

  info.disabled = nil
  info.isTitle  = nil
  info.func     =
    function(self) GroupHistoryCharMigrate:SetValue(self.value) end

  for _, charname in pairs(Addon.Vars.Chars) do
    info.text = charname
    info.value = charname
    info.checked = (charname == Addon.Vars.Chars[1])
    UIDropDownMenu_AddButton(info)
  end
end

local function GroupHistoryCharMigrateShow(self)
  self.value = Addon.Vars.Chars[1]
  self.tooltip = Addon.L['MIGRATE_SELECT_CHAR']
  UIDropDownMenu_SetWidth(self, 150)
  UIDropDownMenu_Initialize(self, GroupHistoryCharMigrateInitialize)
  UIDropDownMenu_SetSelectedValue(self, self.value)

  self.SetValue =
    function(self, value)
      self.value = value
      UIDropDownMenu_SetSelectedValue(self, value)
    end
  self.GetValue =
    function(self) return UIDropDownMenu_GetSelectedValue(self) end
end

function Addon:MigrationDialog(indexList, caller)
  local i = 0
  local frame = _G['GroupHistoryMigration']
  if not frame then
    frame = CreateFrame('Frame', 'GroupHistoryMigration', UIParent, 'GroupHistorySimpleFrame')
  elseif frame:IsVisible() then
    return
  else
    frame:Show()
    return
  end
  frame:EnableMouse(true)
  frame:SetSize(300, 200)
  frame:SetPoint('CENTER')
  frame:SetFrameStrata('DIALOG')
  local header = frame:CreateFontString(nil, nil, 'GameFontNormalMed2')
  header:SetPoint('TOP', 0, -16)
  header:SetText(Addon.Name..' - '..Addon.L['UPDATE_INFO'])
  local timeString = frame:CreateFontString(nil, nil, 'GameFontHighlightMed2')
  timeString:SetPoint('TOP', 0, -48)
  local instanceString = frame:CreateFontString(nil, nil, 'GameFontHighlight')
  instanceString:SetPoint('TOP', timeString, 'BOTTOM', 0, -4)
  local infoString = frame:CreateFontString(nil, nil, 'GameFontHighlight')
  infoString:SetWordWrap(true)
  infoString:SetPoint('TOP', 0, -40)
  infoString:SetWidth(frame:GetWidth() - 20)
  infoString:SetFormattedText(Addon.L['MIGRATE_TEXT_P1']..Addon.L['MIGRATE_TEXT_P2']..
    '|c'..GroupHistory_Helper.Colors['GREEN']..Addon.L['MIGRATE_TEXT_P3']..'|r')

  local btnCancel = CreateFrame('BUTTON', nil, frame, 'OptionsButtonTemplate')
  btnCancel:SetText(Addon.L['CANCEL'])
  btnCancel:SetPoint('BOTTOMLEFT', 8, 8)
  btnCancel:SetScript('OnClick', function() frame:Hide() end)

  local charSelect = CreateFrame('Frame', 'GroupHistoryCharMigrate', frame, 'UIDropDownMenuTemplate')
  charSelect:Hide()
  charSelect:SetPoint('BOTTOM', 0, 64)
  charSelect.type = CONTROLTYPE_DROPDOWN
  charSelect:SetScript('OnEnter', function(dropdown)
    if (not dropdown.isDisabled) then
      GameTooltip:SetOwner(dropdown, 'ANCHOR_TOPRIGHT')
      GameTooltip:SetText(dropdown.tooltip, nil, nil, nil, nil, true)
    end
  end)
  charSelect:SetScript('OnLeave', function() GameTooltip:Hide() end)
  charSelect:SetScript('OnShow', GroupHistoryCharMigrateShow)


  local btnNext = CreateFrame('BUTTON', 'nil', frame, 'OptionsButtonTemplate')
  btnNext:SetText(Addon.L['START'])
  btnNext:SetPoint('BOTTOMRIGHT', -8, 8)
  btnNext:SetScript('OnClick', function()
    if (i <= 0) then
      btnNext:SetText(Addon.L['NEXT']..' >>')
      infoString:Hide()
      charSelect:Show()
    else
      Addon.Groups[indexList[i]].character = charSelect:GetValue()
    end

    i = i + 1
    if (i > #indexList) then
      frame:Hide()
      caller:Hide()
      return
    elseif (i == #indexList) then
      btnNext:SetText(Addon.L['DONE'])
    end

    local entry = Addon.Groups[indexList[i]]
    header:SetText(Addon.L['SELECT_CHAR_FOR_ENTRY']:format( i, #indexList))
    timeString:SetText(GroupHistory_Helper.LocalizedDate(entry.time))
    instanceString:SetText(EJ_GetInstanceInfo(entry.id))
  end)
end