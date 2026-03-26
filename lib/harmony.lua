-- harmony.lua
-- advanced harmonic intelligence for slap
-- circle of fifths, coltrane changes, modal interchange,
-- negative harmony, messiaen modes, bartok axis system

local musicutil = require "musicutil"
local util = require "util"

local harmony = {}

-- ======== SCALE SYSTEMS ========
-- beyond the basics: modes of limited transposition (messiaen),
-- coltrane's symmetric divisions, bartok's axis system

harmony.SCALE_SYSTEMS = {
  -- standard
  {name = "minor pent",  notes = {0, 3, 5, 7, 10}},
  {name = "major pent",  notes = {0, 2, 4, 7, 9}},
  {name = "dorian",      notes = {0, 2, 3, 5, 7, 9, 10}},
  {name = "natural min",  notes = {0, 2, 3, 5, 7, 8, 10}},
  {name = "major",       notes = {0, 2, 4, 5, 7, 9, 11}},
  {name = "phrygian",    notes = {0, 1, 3, 5, 7, 8, 10}},
  {name = "mixolydian",  notes = {0, 2, 4, 5, 7, 9, 10}},
  {name = "lydian",      notes = {0, 2, 4, 6, 7, 9, 11}},
  {name = "locrian",     notes = {0, 1, 3, 5, 6, 8, 10}},
  -- jazz
  {name = "melodic min",  notes = {0, 2, 3, 5, 7, 9, 11}},
  {name = "harmonic min", notes = {0, 2, 3, 5, 7, 8, 11}},
  {name = "whole tone",  notes = {0, 2, 4, 6, 8, 10}},
  {name = "diminished",  notes = {0, 2, 3, 5, 6, 8, 9, 11}},
  {name = "altered",     notes = {0, 1, 3, 4, 6, 8, 10}},
  -- messiaen modes of limited transposition
  {name = "messiaen 2",  notes = {0, 1, 3, 4, 6, 7, 9, 10}},  -- octatonic
  {name = "messiaen 3",  notes = {0, 2, 3, 4, 6, 7, 8, 10, 11}},
  {name = "messiaen 5",  notes = {0, 1, 5, 6, 7, 11}},
  -- world
  {name = "hirajoshi",   notes = {0, 4, 6, 7, 11}},
  {name = "in sen",      notes = {0, 1, 5, 7, 10}},
  {name = "hungarian",   notes = {0, 2, 3, 6, 7, 8, 11}},
  {name = "persian",     notes = {0, 1, 4, 5, 6, 8, 11}},
  {name = "arabic",      notes = {0, 2, 4, 5, 6, 8, 10}},
  -- chromatic
  {name = "chromatic",   notes = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}},
}

harmony.SCALE_NAMES = {}
for i, s in ipairs(harmony.SCALE_SYSTEMS) do
  harmony.SCALE_NAMES[i] = s.name
end

-- generate a full scale from root + system index
function harmony.build_scale(root, system_idx)
  local sys = harmony.SCALE_SYSTEMS[system_idx]
  if not sys then sys = harmony.SCALE_SYSTEMS[1] end
  local notes = {}
  for oct = -1, 6 do
    for _, interval in ipairs(sys.notes) do
      local n = root + oct * 12 + interval
      if n >= 24 and n <= 96 then
        table.insert(notes, n)
      end
    end
  end
  return notes
end

-- ======== CIRCLE OF FIFTHS ========

local CIRCLE_OF_FIFTHS = {0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5}
-- position 0=C, 1=G, 2=D, 3=A, etc.

local function fifth_position(note)
  local pc = note % 12
  for i, v in ipairs(CIRCLE_OF_FIFTHS) do
    if v == pc then return i end
  end
  return 1
end

-- ======== HARMONIC MOVES ========
-- these return {new_root, new_scale_idx} or nil to keep current

harmony.MOVES = {
  -- circle of fifths
  fifth_up = function(root, scale_idx)
    return {root = (root + 7 - 24) % 48 + 24, scale_idx = scale_idx}
  end,
  fifth_down = function(root, scale_idx)
    return {root = (root - 7 - 24) % 48 + 24, scale_idx = scale_idx}
  end,
  fourth_up = function(root, scale_idx)
    return {root = (root + 5 - 24) % 48 + 24, scale_idx = scale_idx}
  end,

  -- relative minor/major
  relative_minor = function(root, scale_idx)
    return {root = (root - 3 - 24) % 48 + 24, scale_idx = 4} -- natural minor
  end,
  relative_major = function(root, scale_idx)
    return {root = (root + 3 - 24) % 48 + 24, scale_idx = 5} -- major
  end,

  -- parallel mode (same root, different scale)
  parallel_minor = function(root, scale_idx)
    return {root = root, scale_idx = 4}
  end,
  parallel_dorian = function(root, scale_idx)
    return {root = root, scale_idx = 3}
  end,
  parallel_lydian = function(root, scale_idx)
    return {root = root, scale_idx = 8}
  end,
  parallel_phrygian = function(root, scale_idx)
    return {root = root, scale_idx = 6}
  end,

  -- coltrane changes (major third cycle: C → E → Ab → C)
  coltrane_up = function(root, scale_idx)
    return {root = (root + 4 - 24) % 48 + 24, scale_idx = scale_idx}
  end,
  coltrane_down = function(root, scale_idx)
    return {root = (root - 4 - 24) % 48 + 24, scale_idx = scale_idx}
  end,

  -- tritone substitution
  tritone = function(root, scale_idx)
    return {root = (root + 6 - 24) % 48 + 24, scale_idx = scale_idx}
  end,

  -- chromatic shift
  half_up = function(root, scale_idx)
    return {root = util.clamp(root + 1, 24, 72), scale_idx = scale_idx}
  end,
  half_down = function(root, scale_idx)
    return {root = util.clamp(root - 1, 24, 72), scale_idx = scale_idx}
  end,

  -- whole step
  whole_up = function(root, scale_idx)
    return {root = util.clamp(root + 2, 24, 72), scale_idx = scale_idx}
  end,

  -- modal interchange: jump to a "color" scale
  to_messiaen = function(root, scale_idx)
    return {root = root, scale_idx = 15} -- messiaen 2
  end,
  to_whole_tone = function(root, scale_idx)
    return {root = root, scale_idx = 12}
  end,
  to_diminished = function(root, scale_idx)
    return {root = root, scale_idx = 13}
  end,
  to_hirajoshi = function(root, scale_idx)
    return {root = root, scale_idx = 18}
  end,
  to_hungarian = function(root, scale_idx)
    return {root = root, scale_idx = 20}
  end,
  to_persian = function(root, scale_idx)
    return {root = root, scale_idx = 21}
  end,

  -- random modal
  random_mode = function(root, scale_idx)
    return {root = root, scale_idx = math.random(1, #harmony.SCALE_SYSTEMS)}
  end,
  random_root = function(root, scale_idx)
    local shift = ({-7, -5, -3, -2, -1, 1, 2, 3, 5, 7})[math.random(10)]
    return {root = util.clamp(root + shift, 24, 72), scale_idx = scale_idx}
  end,
}

-- named move sets for different conductor personalities
harmony.MOVE_SETS = {
  -- classical: circle of fifths, relative keys
  classical = {"fifth_up", "fifth_down", "fourth_up", "relative_minor",
               "relative_major", "parallel_minor", "parallel_dorian"},

  -- jazz: coltrane changes, tritone subs, modal interchange
  jazz = {"coltrane_up", "coltrane_down", "tritone", "fifth_up",
          "parallel_lydian", "to_diminished", "to_whole_tone", "random_mode"},

  -- world: exotic scales, chromatic shifts
  world = {"to_hirajoshi", "to_hungarian", "to_persian", "to_messiaen",
           "half_up", "half_down", "random_mode", "fifth_up"},

  -- minimal: small movements, same scale family
  minimal = {"half_up", "half_down", "whole_up", "fifth_up", "fifth_down"},

  -- chaos: everything
  chaos = {"coltrane_up", "tritone", "to_messiaen", "to_whole_tone",
           "random_mode", "random_root", "to_hirajoshi", "to_persian",
           "to_diminished", "to_hungarian", "half_up", "fifth_up"},
}

-- pick and execute a random move from a move set
function harmony.random_move(root, scale_idx, move_set_name)
  local set = harmony.MOVE_SETS[move_set_name or "classical"]
  if not set then set = harmony.MOVE_SETS.classical end
  local move_name = set[math.random(#set)]
  local move_fn = harmony.MOVES[move_name]
  if move_fn then
    return move_fn(root, scale_idx), move_name
  end
  return nil, nil
end

-- ======== EUCLIDEAN RHYTHM ========
-- bjorklund algorithm

function harmony.euclidean(steps, pulses, offset)
  offset = offset or 0
  if pulses >= steps then
    local pattern = {}
    for i = 1, steps do pattern[i] = true end
    return pattern
  end
  if pulses <= 0 then
    local pattern = {}
    for i = 1, steps do pattern[i] = false end
    return pattern
  end

  -- bjorklund
  local pattern = {}
  local counts = {}
  local remainders = {}
  local divisor = steps - pulses
  remainders[1] = pulses
  local level = 0

  while true do
    counts[level + 1] = math.floor(divisor / remainders[level + 1])
    local new_rem = divisor % remainders[level + 1]
    remainders[level + 2] = new_rem
    divisor = remainders[level + 1]
    level = level + 1
    if remainders[level + 1] <= 1 then break end
  end

  counts[level + 1] = divisor

  local function build(lev)
    if lev == -1 then
      pattern[#pattern + 1] = false
    elseif lev == -2 then
      pattern[#pattern + 1] = true
    else
      for _ = 1, counts[lev + 1] do
        build(lev - 1)
      end
      if remainders[lev + 1] > 0 then
        build(lev - 2)
      end
    end
  end

  build(level)

  -- apply offset (rotate)
  if offset > 0 then
    local rotated = {}
    for i = 1, steps do
      rotated[i] = pattern[((i - 1 + offset) % steps) + 1]
    end
    return rotated
  end

  return pattern
end

return harmony
