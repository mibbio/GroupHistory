local ADDON, Addon = ...

local CHOICES_AGE = {
  { num = 604800,  label = Addon.L['1_WEEK'] },
  { num = 1209600, label = Addon.L['2_WEEK'] },
  { num = 2592000, label = Addon.L['1_MONTH'] },
  { num = 5184000, label = Addon.L['2_MONTH'] },
  { num = 0,       label = Addon.L['FOREVER'] },
}

-----------------
-- DropdownAge --
-----------------
local function AgeDropdownInitialize(self)
  local info = UIDropDownMenu_CreateInfo()

  info.disabled = nil
  info.isTitle  = nil
  info.func     =
    function(self) GroupHistoryAgeDropdown:SetValue(self.value) end

  for _, v in ipairs(CHOICES_AGE) do
    info.text = v.label
    info.value = v.num
    info.checked = (v.num == Addon.Vars.MaxAge)
    UIDropDownMenu_AddButton(info)
  end
end

local function AgeDropdownShow(self)
  self.value = 7
  if (Addon.Vars.MaxAge) then
    for _,v in ipairs(CHOICES_AGE) do
      if (v.num == Addon.Vars.MaxAge) then self.value = v.num break end
    end
  end
  self.tooltip = Addon.L['DELETE_OLDER_THAN']

  UIDropDownMenu_SetWidth(self, 100)
  UIDropDownMenu_Initialize(self, AgeDropdownInitialize)
  UIDropDownMenu_SetSelectedValue(self, self.value)

  self.SetValue =
    function(self, value)
      self.value = value
      Addon.Vars.MaxAge = value
      UIDropDownMenu_SetSelectedValue(self, value)
    end
  self.GetValue =
    function(self) return UIDropDownMenu_GetSelectedValue(self) end
end

------------------------
-- DropdownCharfilter --
------------------------
local function FilterCharDropdownInitialize(self)
  local info = UIDropDownMenu_CreateInfo()

  info.disabled = nil
  info.isTitle  = nil
  info.func     =
    function(self)
      GroupHistoryFilterCharDropdown:SetValue(self.value)
      _G[ADDON..'ContainerGroupFrame']:Update()
    end

  for _,charname in pairs(Addon.Vars.Chars) do
    info.text = charname
    info.value = charname
    info.checked = ((Addon.Vars.SelectedChar) and (Addon.Vars.SelectedChar == charname))
    UIDropDownMenu_AddButton(info)
  end

  info.text = Addon.L['ALL']
  info.value = 'ALL'
  info.checked = ((not Addon.Vars.SelectedChar) or (Addon.Vars.SelectedChar == 'ALL') or (#Addon.Vars.Chars == 0))
  UIDropDownMenu_AddButton(info)
end

local function FilterCharDropdownShow(self)
  if (Addon.Vars.SelectedChar ~= 'ALL') then self.value = Addon.Vars.SelectedChar else self.value = 'ALL' end
  self.tooltip = Addon.L['FILTER_BY_CHAR']
  UIDropDownMenu_SetWidth(self, 150)
  UIDropDownMenu_Initialize(self, FilterCharDropdownInitialize)
  UIDropDownMenu_SetSelectedValue(self, self.value)

  self.SetValue =
    function(self, value)
      self.value = value
      Addon.Vars.SelectedChar = value
      UIDropDownMenu_SetSelectedValue(self, value)
    end
  self.GetValue =
    function(self) return UIDropDownMenu_GetSelectedValue(self) end
end

------------------------------
-- Setup settings dropdowns --
------------------------------

local ageDropdown = CreateFrame('Frame', 'GroupHistoryAgeDropdown', Addon.Frame.settings, 'UIDropDownMenuTemplate')
ageDropdown:SetPoint('TOPLEFT', 0, -64)
ageDropdown.type = CONTROLTYPE_DROPDOWN

ageDropdown:SetScript('OnEnter', function(dropdown)
  if (not dropdown.isDisabled) then
    GameTooltip:SetOwner(dropdown, 'ANCHOR_TOPRIGHT')
    GameTooltip:SetText(dropdown.tooltip, nil, nil, nil, nil, true)
  end
end)

ageDropdown:SetScript('OnLeave', function() GameTooltip:Hide() end)
ageDropdown:SetScript('OnShow', AgeDropdownShow)

ageDropdown.label = ageDropdown:CreateFontString(nil, nil, 'GameFontHighlightLeft')
ageDropdown.label:SetText(Addon.L['KEEP_LOG_ENTRIES'])
ageDropdown.label:SetPoint('BOTTOMLEFT', ageDropdown, 'TOPLEFT', 20, 4)

--------------------------------------
-- Setup character filter dropdowns --
--------------------------------------
local filterCharDropdown = CreateFrame('Frame', 'GroupHistoryFilterCharDropdown', Addon.Frame.content, 'UIDropDownMenuTemplate')
filterCharDropdown:SetPoint('TOPLEFT', 0, -16)
filterCharDropdown.type = CONTROLTYPE_DROPDOWN

filterCharDropdown:SetScript('OnEnter', function(dropdown)
  if (not dropdown.isDisabled) then
    GameTooltip:SetOwner(dropdown, 'ANCHOR_TOPRIGHT')
    GameTooltip:SetText(dropdown.tooltip, nil, nil, nil, nil, true)
  end
end)

filterCharDropdown:SetScript('OnLeave', function() GameTooltip:Hide() end)
filterCharDropdown:SetScript('OnShow', FilterCharDropdownShow)