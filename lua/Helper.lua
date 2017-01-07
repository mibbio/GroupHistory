GH_COLORS = {}
GH_COLORS['ORANGE'] = 'ffffc300'
GH_COLORS['BLUE'] = 'ff3396ff'
GH_COLORS['GREEN'] = 'ff3cff00'

GH_Helper = {}

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

function GH_Helper.tcount(tab)
  local n = 0
  for _ in pairs(tab) do
    n = n + 1
  end
  return n
end

function GH_Helper.GetPlayerList()
  local players = {}
  if IsInRaid() then
    for i=1,40 do
      if GetUnitInfo('raid'..i) then table.insert(players, GetUnitInfo('raid'..i)) end
    end
  elseif IsInGroup then
    for i=1,4 do
      if GetUnitInfo('party'..i) then table.insert(players, GetUnitInfo('party'..i)) end
    end
  end
  return players
end

function GH_Helper.GetGroupDetails(groupIndex)
  local details = {}
  local group = GroupHistory_Groups[groupIndex].group
  if group then
    for _, value in pairs(group) do
      local _class, _, _race, _, _sex, _name, _realm = GetPlayerInfoByGUID(value)
      table.insert(details, GetPlayerInfoByGUID(value))
    end
  end
  return details
end

function GH_Helper.LocalizedDate(timevalue)
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