-- evolution.lua
-- pattern mutation + parameter sweep + conductor system for slap
-- the multi-handed maestro: touches different tracks, different params,
-- different things at different times
--
-- respects user priority: won't overwrite params user recently touched

local util = require "util"
local musicutil = require "musicutil"

local evo = {}

-- ======== USER PRIORITY SYSTEM ========
local USER_COOLDOWN = 4.0
local user_owned = {}

function evo.user_touched(param_name)
  user_owned[param_name] = os.clock()
end

local function is_user_owned(param_name)
  local t = user_owned[param_name]
  if not t then return false end
  if os.clock() - t > USER_COOLDOWN then
    user_owned[param_name] = nil
    return false
  end
  return true
end

function evo.user_override_count()
  local count = 0
  local now = os.clock()
  for p, t in pairs(user_owned) do
    if now - t <= USER_COOLDOWN then count = count + 1
    else user_owned[p] = nil end
  end
  return count
end

-- ======== SWEEP TOWARD ========
function evo.sweep_toward(param_name, target, speed)
  if is_user_owned(param_name) then return end
  local ok, current = pcall(function() return params:get(param_name) end)
  if not ok then return end
  local diff = target - current
  local new_val = current + diff * math.min(speed, 1)
  params:set(param_name, new_val)
end

-- ======== GESTURE ========
function evo.gesture(moves, progress)
  for _, move in ipairs(moves) do
    if not is_user_owned(move.param) then
      local val = move.from + (move.to - move.from) * progress
      params:set(move.param, val)
    end
  end
end

-- ======== PATTERN MUTATION ========
-- all mutations respect t.num_steps (variable-length tracks)

function evo.pattern_mutate(tracks, track_idx, mutation_type, args)
  args = args or {}
  local t = tracks[track_idx]
  if not t then return end
  local ns = t.num_steps or #t.steps

  if mutation_type == "shift" then
    local interval = args.interval or ({-5, -3, -2, 2, 3, 5, 7})[math.random(7)]
    for i = 1, ns do
      if t.steps[i].on then
        t.steps[i].note = util.clamp(t.steps[i].note + interval, 24, 96)
      end
    end

  elseif mutation_type == "thin" then
    local count = args.count or math.random(1, 2)
    local active = {}
    for i = 1, ns do
      if t.steps[i].on then table.insert(active, i) end
    end
    for _ = 1, math.min(count, #active - 2) do
      local idx = math.random(#active)
      t.steps[active[idx]].on = false
      table.remove(active, idx)
    end

  elseif mutation_type == "thicken" then
    local count = args.count or math.random(1, 2)
    local inactive = {}
    for i = 1, ns do
      if not t.steps[i].on then table.insert(inactive, i) end
    end
    for _ = 1, math.min(count, #inactive) do
      local idx = math.random(#inactive)
      t.steps[inactive[idx]].on = true
      table.remove(inactive, idx)
    end

  elseif mutation_type == "accent" then
    for i = 1, ns do
      if t.steps[i].on and t.steps[i].vel > 0.5 then
        t.steps[i].vel = math.min(1, t.steps[i].vel + 0.1)
      end
    end

  elseif mutation_type == "ghost" then
    for i = 1, ns do
      if t.steps[i].on and t.steps[i].vel < 0.6 then
        t.steps[i].vel = math.max(0.1, t.steps[i].vel - 0.1)
      end
    end

  elseif mutation_type == "rotate" then
    local n = args.n or 1
    local saved = {}
    for i = 1, ns do
      saved[i] = {on = t.steps[i].on, note = t.steps[i].note, vel = t.steps[i].vel}
    end
    for i = 1, ns do
      local src = ((i - 1 + n) % ns) + 1
      t.steps[i].on = saved[src].on
      t.steps[i].note = saved[src].note
      t.steps[i].vel = saved[src].vel
    end

  elseif mutation_type == "replace_one" then
    local scale_notes = args.scale_notes or {}
    if #scale_notes > 0 then
      local active = {}
      for i = 1, ns do
        if t.steps[i].on then table.insert(active, i) end
      end
      if #active > 0 then
        local idx = active[math.random(#active)]
        t.steps[idx].note = scale_notes[math.random(#scale_notes)]
      end
    end

  elseif mutation_type == "velocity_drift" then
    for i = 1, ns do
      if t.steps[i].on then
        local drift = (math.random() - 0.5) * 0.15
        t.steps[i].vel = util.clamp(t.steps[i].vel + drift, 0.1, 1.0)
      end
    end

  elseif mutation_type == "extend" then
    -- add 1-2 steps to track length (max 24)
    local add = args.count or math.random(1, 2)
    local new_len = math.min((t.num_steps or #t.steps) + add, 24)
    local sc = args.scale_notes or {}
    -- fill new steps with musical content
    for i = (t.num_steps or #t.steps) + 1, new_len do
      if not t.steps[i] then t.steps[i] = {} end
      t.steps[i].on = math.random() < 0.5
      t.steps[i].note = #sc > 0 and sc[math.random(#sc)] or 60
      t.steps[i].vel = 0.4 + math.random() * 0.5
    end
    t.num_steps = new_len

  elseif mutation_type == "truncate" then
    -- remove 1-2 steps from track length (min 4)
    local rem = args.count or math.random(1, 2)
    t.num_steps = math.max((t.num_steps or #t.steps) - rem, 4)
  end
end

-- generate a fresh pattern for a track from a note pool
function evo.generate_pattern(tracks, track_idx, pool, density, vel_lo, vel_hi)
  local t = tracks[track_idx]
  if not t then return end
  local ns = t.num_steps or #t.steps
  for i = 1, ns do
    if not t.steps[i] then t.steps[i] = {on = false, note = 60, vel = 0.8} end
    t.steps[i].note = pool[math.random(#pool)]
    t.steps[i].vel = vel_lo + math.random() * (vel_hi - vel_lo)
    t.steps[i].on = math.random() < density
  end
  t.steps[1].on = true
end

-- ======== CONDUCTOR ========
-- the multi-handed maestro: uses the active conductor's style weights
-- to decide what to touch, when, and how aggressively.
-- each conductor (MONONEON, THUNDERCAT, etc.) has a unique fingerprint.

local ACTION_NAMES = {
  "replace_one", "velocity_drift", "rotate", "thicken",
  "thin", "shift", "extend", "truncate", "accent", "ghost"
}

-- default fallback weights
local DEFAULT_STYLE = {
  replace_one = 0.15, velocity_drift = 0.15, rotate = 0.10,
  thicken = 0.10, thin = 0.08, shift = 0.08,
  extend = 0.05, truncate = 0.04, accent = 0.12, ghost = 0.13,
}

function evo.conductor_tick(tracks, energy, conductor_profile)
  -- conductor_profile: the robot.profiles entry with .style and .intensity_range
  local style = (conductor_profile and conductor_profile.style) or DEFAULT_STYLE
  local ir = (conductor_profile and conductor_profile.intensity_range) or {0.2, 0.5}

  -- intensity scales with energy within the conductor's range
  local intensity = ir[1] + (ir[2] - ir[1]) * energy

  local sc = tracks._scale_notes or {}

  -- the maestro can touch MULTIPLE things per tick at high intensity
  -- base: 1 action. at high intensity: up to 3.
  local num_actions = 1
  if math.random() < intensity then num_actions = num_actions + 1 end
  if math.random() < intensity * 0.5 then num_actions = num_actions + 1 end

  for _ = 1, num_actions do
    -- roll: should this hand act?
    if math.random() > intensity then goto continue end

    -- pick a random track
    local track_idx = math.random(1, 4)

    -- pick action from this conductor's style weights
    local roll = math.random()
    local cumulative = 0
    local action = "replace_one"
    for _, name in ipairs(ACTION_NAMES) do
      cumulative = cumulative + (style[name] or 0)
      if roll <= cumulative then
        action = name
        break
      end
    end

    -- build musical args
    local args = {scale_notes = sc}
    if action == "rotate" then
      args.n = ({1, -1, 2, -2, 3, -3})[math.random(6)]
    elseif action == "shift" then
      args.interval = ({2, -2, 3, -3, 5, -5, 7, -7, 12, -12})[math.random(10)]
    elseif action == "extend" or action == "truncate" then
      args.count = math.random(1, 2)
      args.scale_notes = sc
    end

    evo.pattern_mutate(tracks, track_idx, action, args)

    ::continue::
  end
end

return evo
