GroupHistory_Helper = {}
GroupHistory_Helper.Colors = {
  ['ORANGE']  = 'ffffc300',
  ['BLUE']    = 'ff3396ff',
  ['GREEN']   = 'ff3cff00'
}

local function GetUnitInfo(unit)
  if UnitExists(unit) then
    local name, realm = UnitName(unit)
    local race = UnitRace(unit)
    local level = UnitLevel(unit)
    local class, classFile = UnitClass(unit)
    local color = RAID_CLASS_COLORS[classFile]
    return { name, realm, level, race, format('|cff%.2x%.2x%.2x%s|r', color.r*255, color.g*255, color.b*255, class) }
  else return nil end
end

function GroupHistory_Helper.tcount(tab)
  local n = 0
  for _ in pairs(tab) do
    n = n + 1
  end
  return n
end

function GroupHistory_Helper.IsEqualGroup(g1, g2)
  if #g1 ~= #g2 then return false end
  table.sort(g1)
  table.sort(g2)
  local equalValues = 0
  for k,v in pairs(g1) do
    if (v ~= g2[k]) then return false end
  end
  return true
end

function GroupHistory_Helper.GetGroupGUIDs()
  local guids = {}
  if IsInRaid() then
    for i=1,40 do
      local unit = 'raid'..i
      if UnitExists(unit) then table.insert(guids, UnitGUID(unit)) end
    end
  elseif IsInGroup() then
    for i = 1,4 do
      local unit = 'party'..i
      if UnitExists(unit) then table.insert(guids, UnitGUID(unit)) end
    end
  end
  return guids
end

function GroupHistory_Helper.GetPlayerList()
  local players = {}
  if IsInRaid() then
    for i=1,40 do
      if UnitExists('raid'..i) then table.insert(players, GetUnitInfo('raid'..i)) end
    end
  elseif IsInGroup() then
    for i=1,4 do
      if UnitExists('party'..i) then table.insert(players, GetUnitInfo('party'..i)) end
    end
  end
  return players
end

function GroupHistory_Helper.LocalizedDate(timevalue)
  local locale = GetLocale()
  if locale == 'deDE' then
    return date('%d.%m.%Y - %X', timevalue)
  elseif locale == 'enUS' then
    return date('%m/%d/%Y - %X', timevalue)
  elseif locale == 'enGB' then
    return date('%d/%m/%Y - %X', timevalue)
  elseif locale == 'frFR' then
    return date('%d-%m-%Y - %X', timevalue)
  else
    return date('%x - %X', timevalue)
  end
end