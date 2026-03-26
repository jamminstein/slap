-- evolution.lua
-- pattern mutation + parameter sweep system for slap
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
-- operates on a tracks table passed in

function evo.pattern_mutate(tracks, track_idx, mutation_type, args)
  args = args or {}
  local t = tracks[track_idx]
  if not t then return end
  local NUM_STEPS = #t.steps

  if mutation_type == "shift" then
    local interval = args.interval or ({-5, -3, -2, 2, 3, 5, 7})[math.random(7)]
    for i = 1, NUM_STEPS do
      if t.steps[i].on then
        t.steps[i].note = util.clamp(t.steps[i].note + interval, 24, 96)
      end
    end

  elseif mutation_type == "thin" then
    local count = args.count or math.random(1, 2)
    local active = {}
    for i = 1, NUM_STEPS do
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
    for i = 1, NUM_STEPS do
      if not t.steps[i].on then table.insert(inactive, i) end
    end
    for _ = 1, math.min(count, #inactive) do
      local idx = math.random(#inactive)
      t.steps[inactive[idx]].on = true
      table.remove(inactive, idx)
    end

  elseif mutation_type == "accent" then
    for i = 1, NUM_STEPS do
      if t.steps[i].on and t.steps[i].vel > 0.6 then
        t.steps[i].vel = math.min(1, t.steps[i].vel + 0.1)
      end
    end

  elseif mutation_type == "ghost" then
    for i = 1, NUM_STEPS do
      if t.steps[i].on and t.steps[i].vel < 0.6 then
        t.steps[i].vel = math.max(0.1, t.steps[i].vel - 0.1)
      end
    end

  elseif mutation_type == "rotate" then
    local n = args.n or 1
    local saved = {}
    for i = 1, NUM_STEPS do
      saved[i] = {on = t.steps[i].on, note = t.steps[i].note, vel = t.steps[i].vel}
    end
    for i = 1, NUM_STEPS do
      local src = ((i - 1 + n) % NUM_STEPS) + 1
      t.steps[i].on = saved[src].on
      t.steps[i].note = saved[src].note
      t.steps[i].vel = saved[src].vel
    end

  elseif mutation_type == "replace_one" then
    local scale_notes = args.scale_notes or {}
    if #scale_notes > 0 then
      local active = {}
      for i = 1, NUM_STEPS do
        if t.steps[i].on then table.insert(active, i) end
      end
      if #active > 0 then
        local idx = active[math.random(#active)]
        local new_note = scale_notes[math.random(#scale_notes)]
        t.steps[idx].note = new_note
      end
    end

  elseif mutation_type == "velocity_drift" then
    for i = 1, NUM_STEPS do
      if t.steps[i].on then
        local drift = (math.random() - 0.5) * 0.15
        t.steps[i].vel = util.clamp(t.steps[i].vel + drift, 0.1, 1.0)
      end
    end

  elseif mutation_type == "gate_shape" then
    local shape = args.shape or "random"
    for i = 1, NUM_STEPS do
      local g
      if shape == "ramp" then g = (i - 1) / (NUM_STEPS - 1)
      elseif shape == "reverse" then g = 1 - (i - 1) / (NUM_STEPS - 1)
      elseif shape == "random" then g = 0.1 + math.random() * 0.9
      elseif shape == "short" then g = 0.1 + math.random() * 0.3
      elseif shape == "long" then g = 0.6 + math.random() * 0.4
      else g = 0.5 end
      -- gate is per-track, not per-step, but we apply to track
    end
  end
end

-- generate a fresh pattern for a track from a note pool
function evo.generate_pattern(tracks, track_idx, pool, density, vel_lo, vel_hi)
  local t = tracks[track_idx]
  if not t then return end
  for i = 1, #t.steps do
    t.steps[i].note = pool[math.random(#pool)]
    t.steps[i].vel = vel_lo + math.random() * (vel_hi - vel_lo)
    t.steps[i].on = math.random() < density
  end
  t.steps[1].on = true
end

return evo
