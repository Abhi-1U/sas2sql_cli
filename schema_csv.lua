local lpeg = require('lpeg')
local P, S, C, Cp, Cs, Ct = lpeg.P, lpeg.S, lpeg.C, lpeg.Cp, lpeg.Cs, lpeg.Ct

local quoted = P('"') * Cs(((P('""') / '"') + (1 - P('"')))^0) * P('"')
local field = quoted + C((1 - S(',"\r\n'))^0)
local newline = P('\r\n') + S('\r\n')
local record = Ct(field * (P(',') * field)^0) * (newline + -P(1)) * Cp()

local required = {'libname', 'memname', 'name', 'type', 'length', 'varnum'}
local storage_types = {
  ['1']='numeric', ['2']='character',
  numeric='numeric', character='character',
  date='numeric', datetime='numeric', time='numeric',
}

local function trim(value)
  return value:match('^%s*(.-)%s*$')
end

local function optional(value)
  value = trim(value or '')
  if value ~= '' and value ~= '.' then return value end
end

local function positive_integer(value)
  if value:match('^%d+$') then
    local integer = math.tointeger(tonumber(value))
    if integer and integer > 0 then return integer end
  end
end

local function parse(source, path)
  local line, offset = 1, 1
  local header, width
  local groups = {}

  local function fail(message)
    error(('%s:%d: %s'):format(path, line, message), 0)
  end

  while offset <= #source do
    local values, next_offset = record:match(source, offset)
    if not values then fail('Malformed CSV record') end
    if #values > 1 or trim(values[1]) ~= '' then
      if not header then
        header, width = {}, #values
        for i, value in ipairs(values) do
          local name = trim(value):lower()
          if name == '' then fail('Empty header name') end
          if header[name] then fail('Duplicate header ' .. name) end
          header[name] = i
        end
        for _, name in ipairs(required) do
          if not header[name] then fail('Missing required header ' .. name) end
        end
      else
        if #values ~= width then fail(('Expected %d CSV fields, got %d'):format(width, #values)) end
        local libname, memname, name = values[header.libname], values[header.memname], values[header.name]
        if trim(libname) == '' or trim(memname) == '' or libname:find('[%.%z]') or memname:find('[%.%z]') then
          fail('Expected LIBNAME and MEMNAME without embedded dots or NUL bytes')
        end
        if trim(name) == '' or name:find('%z') then fail('Invalid column NAME') end
        local declared_type = trim(values[header.type]):lower()
        local storage = storage_types[declared_type]
        if not storage then fail(('Unknown TYPE %q for %s'):format(declared_type, name)) end
        local varnum = positive_integer(trim(values[header.varnum]))
        if not varnum then fail('VARNUM must be a positive integer for ' .. name) end
        local raw_length = optional(values[header.length])
        local length = raw_length and positive_integer(raw_length)
        if not length and (raw_length or storage == 'character') then
          fail('LENGTH must be a positive integer for ' .. name)
        end

        local dataset = (libname .. '.' .. memname):lower()
        local group = groups[dataset]
        if not group then
          group = {columns={}, names={}, positions={}}
          groups[dataset] = group
        end
        local key = name:lower()
        if group.names[key] then fail('Duplicate column ' .. name .. ' for ' .. dataset) end
        if group.positions[varnum] then fail('Duplicate VARNUM ' .. varnum .. ' for ' .. dataset) end
        group.names[key], group.positions[varnum] = true, true
        group.columns[#group.columns + 1] = {
          name=name, type=storage, length=length, varnum=varnum,
          format=optional(values[header.format]), informat=optional(values[header.informat]),
        }
      end
    end

    local consumed = source:sub(offset, next_offset - 1):gsub('\r\n', '\n')
    local _, breaks = consumed:gsub('[\r\n]', '')
    line, offset = line + breaks, next_offset
  end
  if not header then fail('Expected a CSV header') end

  local schemas = {}
  for dataset, group in pairs(groups) do
    table.sort(group.columns, function(a, b) return a.varnum < b.varnum end)
    schemas[dataset] = group.columns
  end
  return schemas
end

return {parse=parse}
