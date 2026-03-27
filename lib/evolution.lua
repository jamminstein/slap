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
local USER_COOLDOWN = 8.0
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

function evo.user_owned_check(param_name)
  return is_user_owned(param_name)
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
      local fp = filter_pool(scale_notes, track_idx)
      local active = {}
      for i = 1, ns do
        if t.steps[i].on then table.insert(active, i) end
      end
      if #active > 0 and #fp > 0 then
        local idx = active[math.random(#active)]
        -- melodic intelligence: pick note relative to neighbors
        local prev_note = nil
        for j = idx - 1, 1, -1 do
          if t.steps[j].on then prev_note = t.steps[j].note; break end
        end
        if not prev_note then prev_note = t.steps[idx].note end

        -- 70% stepwise (within 4 semitones), 20% skip (5-7), 10% leap
        local roll = math.random()
        local candidates = {}
        if roll < 0.7 then
          -- stepwise: notes within 4 semitones of previous
          for _, n in ipairs(fp) do
            if math.abs(n - prev_note) <= 4 then table.insert(candidates, n) end
          end
        elseif roll < 0.9 then
          -- skip: 5-7 semitones
          for _, n in ipairs(fp) do
            local d = math.abs(n - prev_note)
            if d >= 5 and d <= 7 then table.insert(candidates, n) end
          end
        end
        -- leap or fallback: any note in pool
        if #candidates == 0 then candidates = fp end

        -- root gravity on beat 1
        local root = scale_notes[1] or 50
        if idx == 1 and math.random() < 0.6 then
          -- favor root/octave on beat 1
          local root_notes = {}
          for _, n in ipairs(fp) do
            if n % 12 == root % 12 then table.insert(root_notes, n) end
          end
          if #root_notes > 0 then candidates = root_notes end
        end

        t.steps[idx].note = candidates[math.random(#candidates)]
      end
    end

  elseif mutation_type == "velocity_drift" then
    for i = 1, ns do
      if t.steps[i].on then
        local drift = (math.random() - 0.5) * 0.15
        t.steps[i].vel = util.clamp(t.steps[i].vel + drift, 0.1, 1.0)
      end
    end

  elseif mutation_type == "crescendo" then
    -- ramp velocity from low to high across pattern
    for i = 1, ns do
      if t.steps[i].on then
        local ramp = (i - 1) / math.max(ns - 1, 1)
        t.steps[i].vel = util.clamp(0.2 + ramp * 0.7 + (math.random() - 0.5) * 0.1, 0.1, 1.0)
      end
    end

  elseif mutation_type == "decrescendo" then
    -- ramp velocity from high to low
    for i = 1, ns do
      if t.steps[i].on then
        local ramp = 1 - (i - 1) / math.max(ns - 1, 1)
        t.steps[i].vel = util.clamp(0.2 + ramp * 0.7 + (math.random() - 0.5) * 0.1, 0.1, 1.0)
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

  elseif mutation_type == "set_length" then
    -- drift toward a target length, one step at a time
    local target = args.target or 16
    local ns = t.num_steps or #t.steps
    local sc = args.scale_notes or {}
    if ns < target then
      -- extend by 1
      local new_len = math.min(ns + 1, 24)
      for i = ns + 1, new_len do
        if not t.steps[i] then t.steps[i] = {} end
        t.steps[i].on = math.random() < 0.4
        t.steps[i].note = #sc > 0 and sc[math.random(#sc)] or 60
        t.steps[i].vel = 0.4 + math.random() * 0.5
      end
      t.num_steps = new_len
    elseif ns > target then
      -- truncate by 1
      t.num_steps = math.max(ns - 1, 4)
    end
  end
end

-- per-track pitch ranges (constrain to musical register)
local TRACK_RANGES = {
  {lo = 36, hi = 55},  -- track 1 (MANTA): C2-G3, low-mid pads
  {lo = 26, hi = 45},  -- track 2 (ZKIT): D1-A2, BASS only
  {lo = 48, hi = 67},  -- track 3 (TOROID): C3-G4, mid melody
  {lo = 36, hi = 72},  -- track 4 (BZZT): C2-C5, percussion
}

-- filter a note pool to a track's range
local function filter_pool(pool, track_idx)
  local range = TRACK_RANGES[track_idx] or {lo = 36, hi = 72}
  local filtered = {}
  for _, n in ipairs(pool) do
    if n >= range.lo and n <= range.hi then
      table.insert(filtered, n)
    end
  end
  -- if nothing in range, use closest octave
  if #filtered == 0 then
    local center = math.floor((range.lo + range.hi) / 2)
    for _, n in ipairs(pool) do
      local adjusted = n
      while adjusted < range.lo do adjusted = adjusted + 12 end
      while adjusted > range.hi do adjusted = adjusted - 12 end
      if adjusted >= range.lo and adjusted <= range.hi then
        table.insert(filtered, adjusted)
      end
    end
  end
  if #filtered == 0 then return pool end
  return filtered
end

-- generate a fresh pattern for a track from a note pool
-- uses melodic intelligence: stepwise motion, root gravity on beat 1
function evo.generate_pattern(tracks, track_idx, pool, density, vel_lo, vel_hi)
  local t = tracks[track_idx]
  if not t then return end
  local ns = t.num_steps or #t.steps
  local fp = filter_pool(pool, track_idx)
  if #fp == 0 then return end

  -- start with root-ish note
  local root = pool[1] or 50
  local root_candidates = {}
  for _, n in ipairs(fp) do
    if n % 12 == root % 12 then table.insert(root_candidates, n) end
  end
  local prev_note = #root_candidates > 0 and root_candidates[math.random(#root_candidates)] or fp[math.random(#fp)]

  for i = 1, ns do
    if not t.steps[i] then t.steps[i] = {on = false, note = 60, vel = 0.8, prob = 100} end
    t.steps[i].on = math.random() < density

    -- melodic contour: mostly stepwise
    local candidates = {}
    for _, n in ipairs(fp) do
      if math.abs(n - prev_note) <= 5 then table.insert(candidates, n) end
    end
    if #candidates == 0 then candidates = fp end

    -- beat 1: root gravity
    if i == 1 and #root_candidates > 0 then
      t.steps[i].note = root_candidates[math.random(#root_candidates)]
    else
      t.steps[i].note = candidates[math.random(#candidates)]
    end
    prev_note = t.steps[i].note

    -- velocity contour: slight accent on downbeats
    local base_vel = vel_lo + math.random() * (vel_hi - vel_lo)
    if i == 1 or (ns >= 8 and i == math.floor(ns / 2) + 1) then
      base_vel = math.min(1.0, base_vel + 0.15)  -- accent downbeats
    end
    t.steps[i].vel = base_vel
    t.steps[i].prob = t.steps[i].prob or 100
  end
  t.steps[1].on = true
end

-- ======== HOME SYSTEM ========
-- saves starting patterns so the conductor can return to them
-- creates A-B-A form: depart → explore → come home

local home_patterns = nil
local ticks_since_home = 0

function evo.save_home(tracks)
  home_patterns = {}
  for t = 1, 4 do
    home_patterns[t] = {
      steps = {}, num_steps = tracks[t].num_steps,
    }
    for s = 1, 24 do
      local st = tracks[t].steps[s]
      if st then
        home_patterns[t].steps[s] = {on = st.on, note = st.note, vel = st.vel, prob = st.prob or 100}
      end
    end
  end
  ticks_since_home = 0
end

-- return types:
-- "full"     = ABA: restore all tracks fully (chorus)
-- "partial"  = restore 1-2 tracks, rest keeps evolving (verse callback)
-- "rhythm"   = restore rhythm (on/off) but keep current notes (variation)
-- "melody"   = restore notes but keep current rhythm (reharmonized return)
-- "ghost"    = restore at low velocity (memory/echo of the original)

function evo.return_home(tracks, return_type)
  if not home_patterns then return false end
  return_type = return_type or "full"

  if return_type == "full" then
    -- restore everything
    for ti = 1, 4 do
      local home = home_patterns[ti]
      if home then
        tracks[ti].num_steps = home.num_steps
        for s = 1, 24 do
          local src = home.steps[s]
          if src then
            tracks[ti].steps[s].on = src.on
            tracks[ti].steps[s].note = src.note
            tracks[ti].steps[s].vel = src.vel
          end
        end
      end
    end

  elseif return_type == "partial" then
    -- restore 1-2 random tracks
    local count = math.random(1, 2)
    local indices = {1, 2, 3, 4}
    for i = 4, 2, -1 do
      local j = math.random(1, i)
      indices[i], indices[j] = indices[j], indices[i]
    end
    for i = 1, count do
      local ti = indices[i]
      local home = home_patterns[ti]
      if home then
        tracks[ti].num_steps = home.num_steps
        for s = 1, 24 do
          local src = home.steps[s]
          if src then
            tracks[ti].steps[s].on = src.on
            tracks[ti].steps[s].note = src.note
            tracks[ti].steps[s].vel = src.vel
          end
        end
      end
    end

  elseif return_type == "rhythm" then
    -- restore on/off pattern but keep current notes
    for ti = 1, 4 do
      local home = home_patterns[ti]
      if home then
        tracks[ti].num_steps = home.num_steps
        for s = 1, 24 do
          local src = home.steps[s]
          if src then
            tracks[ti].steps[s].on = src.on
            tracks[ti].steps[s].vel = src.vel
          end
        end
      end
    end

  elseif return_type == "melody" then
    -- restore notes but keep current rhythm
    for ti = 1, 4 do
      local home = home_patterns[ti]
      if home then
        for s = 1, math.min(tracks[ti].num_steps, home.num_steps) do
          local src = home.steps[s]
          if src then
            tracks[ti].steps[s].note = src.note
          end
        end
      end
    end

  elseif return_type == "ghost" then
    -- restore pattern at very low velocity (echo of original)
    for ti = 1, 4 do
      local home = home_patterns[ti]
      if home then
        tracks[ti].num_steps = home.num_steps
        for s = 1, 24 do
          local src = home.steps[s]
          if src then
            tracks[ti].steps[s].on = src.on
            tracks[ti].steps[s].note = src.note
            tracks[ti].steps[s].vel = src.vel * 0.35
          end
        end
      end
    end
  end

  ticks_since_home = 0
  return true
end

-- ======== CONDUCTOR ========
-- the multi-handed maestro: uses the active conductor's style weights
-- to decide what to touch, when, and how aggressively.
-- each conductor (MONONEON, THUNDERCAT, etc.) has a unique fingerprint.

local ACTION_NAMES = {
  "replace_one", "velocity_drift", "rotate", "thicken",
  "thin", "shift", "extend", "truncate", "accent", "ghost",
  "crescendo", "decrescendo"
}

-- default fallback weights — THIN and GHOST are heavy, THICKEN is rare
local DEFAULT_STYLE = {
  replace_one = 0.12, velocity_drift = 0.10, rotate = 0.07,
  thicken = 0.03, thin = 0.15, shift = 0.06,
  extend = 0.03, truncate = 0.04, accent = 0.08, ghost = 0.16,
  crescendo = 0.08, decrescendo = 0.08,
}

function evo.conductor_tick(tracks, energy, conductor_profile)
  -- conductor_profile: the robot.profiles entry with .style and .intensity_range
  local style = (conductor_profile and conductor_profile.style) or DEFAULT_STYLE
  local ir = (conductor_profile and conductor_profile.intensity_range) or {0.2, 0.5}

  -- intensity scales with energy within the conductor's range
  local intensity = ir[1] + (ir[2] - ir[1]) * energy

  local sc = tracks._scale_notes or {}
  local lock_16 = conductor_profile and conductor_profile.lock_16

  -- lock_16: force all tracks to 16 steps every tick
  if lock_16 then
    for ti = 1, 4 do
      if tracks[ti] then tracks[ti].num_steps = 16 end
    end
  end

  -- ======== ARRANGEMENT INTELLIGENCE ========
  -- per-conductor arrangement profiles
  -- each conductor has arr = {lo={configs}, mid={configs}, hi={configs}, rate=ticks}
  local FALLBACK_ARR = {
    lo = {{1,0,0,0}, {0,1,0,0}, {1,1,0,0}},
    mid = {{1,1,0,0}, {0,1,0,1}, {1,1,1,0}},
    hi = {{1,1,1,0}, {1,1,1,1}, {0,1,1,1}},
    rate = 16,
  }
  local arr_profile = (conductor_profile and conductor_profile.arr) or FALLBACK_ARR

  -- every N ticks, consider changing arrangement
  if not evo._arr_counter then evo._arr_counter = 0 end
  if not evo._arr_current then evo._arr_current = {1, 1, 1, 0} end -- start with trio
  evo._arr_counter = evo._arr_counter + 1

  local arr_rate = arr_profile.rate or 16
  if evo._arr_counter >= arr_rate and math.random() < 0.3 * intensity then
    evo._arr_counter = 0
    -- pick from conductor's energy-appropriate configs
    local pool
    if energy < 0.3 then
      pool = arr_profile.lo or FALLBACK_ARR.lo
    elseif energy < 0.6 then
      pool = arr_profile.mid or FALLBACK_ARR.mid
    else
      pool = arr_profile.hi or FALLBACK_ARR.hi
    end
    evo._arr_current = pool[math.random(#pool)]
  end

  -- apply arrangement: set probability to 0 for silent tracks
  for ti = 1, 4 do
    local prob_param = "t" .. ti .. "_probability"
    if not is_user_owned(prob_param) then
      if evo._arr_current[ti] == 0 then
        -- this track should be silent
        local ok, cur = pcall(function() return params:get(prob_param) end)
        if ok and cur > 5 then
          -- fade out over a few ticks
          params:set(prob_param, math.max(0, cur - 15))
        end
      else
        -- this track should be active, restore if low
        local ok, cur = pcall(function() return params:get(prob_param) end)
        if ok and cur < 40 then
          -- fade in
          params:set(prob_param, math.min(cur + 10, 70 + energy * 30))
        end
      end
    end
  end

  -- density check: thin the densest track if total is too high
  local total_active = 0
  local track_density = {}
  for ti = 1, 4 do
    local count = 0
    local ns = tracks[ti].num_steps or 16
    for s = 1, ns do
      if tracks[ti].steps[s] and tracks[ti].steps[s].on then count = count + 1 end
    end
    track_density[ti] = count / ns
    total_active = total_active + count
  end

  local max_total = lock_16 and 32 or 24  -- reasonable limits
  if total_active > max_total then
    local densest = 1
    for ti = 2, 4 do
      if track_density[ti] > track_density[densest] then densest = ti end
    end
    evo.pattern_mutate(tracks, densest, "thin", {count = 2})
    evo.pattern_mutate(tracks, densest, "ghost")
  end

  -- the maestro can touch MULTIPLE things per tick at high intensity
  -- but limit to 1-2 (was up to 3, too chaotic)
  local num_actions = 1
  if math.random() < intensity * 0.5 then num_actions = num_actions + 1 end

  for _ = 1, num_actions do
    if math.random() > intensity then goto continue end

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

    -- lock_16: skip length changes, re-roll as ghost/replace
    if lock_16 and (action == "extend" or action == "truncate") then
      action = math.random() < 0.5 and "ghost" or "replace_one"
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

  -- ======== KNOB RIDING ========
  -- conductor-specific knobs + universal "every conductor explores these"
  local knobs = conductor_profile and conductor_profile.knobs or {}

  -- universal knobs: params that EVERY conductor should touch
  -- mostly drift, but some jump for occasional radical moments
  local universal_knobs = {
    -- weights bumped: things should MOVE constantly
    {param="t1_brightness",weight=0.25, range={0.15, 0.6}, mode="drift"},  -- capped: >0.6 = bells
    {param="t1_brightness",weight=0.04, range={0.1, 0.75}, mode="jump"},   -- occasional bright
    {param="t1_res",       weight=0.2,  range={0.05, 0.5}, mode="drift"},
    {param="t1_res",       weight=0.03, range={0.02, 0.7}, mode="jump"},
    {param="t2_res",       weight=0.2,  range={0.2, 0.85}, mode="drift"},
    {param="t2_res",       weight=0.04, range={0.1, 0.95}, mode="jump"},
    {param="t2_accent",    weight=0.15, range={0.2, 0.9},  mode="drift"},
    {param="t2_accent",    weight=0.04, range={0, 1},      mode="jump"},
    {param="t3_res",       weight=0.18, range={0.1, 0.6},  mode="drift"},
    {param="t3_fmamt",     weight=0.25, range={0, 0.35},   mode="drift"},  -- capped low
    {param="t3_fmamt",     weight=0.03, range={0.2, 0.6},  mode="jump"},   -- less extreme
    {param="t3_morph",     weight=0.2,  range={0, 0.8},    mode="drift"},
    {param="t3_morph",     weight=0.04, range={0, 1},      mode="jump"},
    {param="t3_lfoRate",   weight=0.15, range={0.5, 10},   mode="drift"},
    {param="t3_lfoRate",   weight=0.03, range={0.1, 20},   mode="jump"},
    {param="t3_lfoDepth",  weight=0.18, range={0, 0.35},   mode="drift"},
    {param="t3_lfoDepth",  weight=0.03, range={0.2, 0.5},  mode="jump"},
    {param="t4_res",       weight=0.18, range={0.05, 0.5}, mode="drift"},
    {param="t4_bits",      weight=0.15, range={6, 16},     mode="drift"},
    {param="t4_bits",      weight=0.03, range={4, 8},      mode="jump"},
    {param="t4_pwm",       weight=0.2,  range={0.1, 0.9},  mode="drift"},
    {param="t4_pwm",       weight=0.03, range={0.05, 0.95},mode="jump"},
    {param="t1_spread",    weight=0.2,  range={0.1, 0.5},  mode="drift"},  -- subtle detuning
    {param="t1_spread",    weight=0.03, range={0, 0.7},    mode="jump"},
    {param="t1_cutoff",    weight=0.15, range={500, 6000},  mode="drift"},
    {param="t2_cutoff",    weight=0.15, range={200, 4000},  mode="drift"},
    {param="t3_cutoff",    weight=0.15, range={500, 8000},  mode="drift"},
    {param="t4_cutoff",    weight=0.1,  range={2000,10000}, mode="drift"},
    {param="t4_engine",    weight=0.02, range={1, 4},       mode="jump"}
  }

  -- combine conductor knobs + universal
  local all_knobs = {}
  for _, k in ipairs(knobs) do table.insert(all_knobs, k) end
  for _, k in ipairs(universal_knobs) do table.insert(all_knobs, k) end

  for _, knob in ipairs(all_knobs) do
    -- each knob fires based on its weight * intensity
    if math.random() < knob.weight * intensity then
      if is_user_owned(knob.param) then goto skip_knob end

      local lo = knob.range[1]
      local hi = knob.range[2]

      if knob.mode == "jump" then
        -- move toward a random target
        local center = (lo + hi) * 0.5
        local spread = (hi - lo) * 0.5
        local target = center + (math.random() - 0.5) * spread * 2 * energy
        evo.sweep_toward(knob.param, util.clamp(target, lo, hi), 0.12)
      elseif knob.mode == "drift" then
        -- random walk within range
        local ok, cur = pcall(function() return params:get(knob.param) end)
        if ok then
          local drift = (math.random() - 0.5) * (hi - lo) * 0.08
          -- gravity: pull toward center when at extremes
          local center = (lo + hi) * 0.5
          local gravity = (center - cur) * 0.02
          evo.sweep_toward(knob.param, util.clamp(cur + drift + gravity, lo, hi), 0.06)
        end
      end

      ::skip_knob::
    end
  end

  -- ======== HOME RETURN ========
  -- periodically return to starting patterns (creates structural form)
  ticks_since_home = ticks_since_home + 1
  local home_tendency = conductor_profile and conductor_profile.home_tendency or 0.03
  local home_interval = lock_16 and 16 or 32  -- locked = return sooner

  if ticks_since_home > home_interval and math.random() < home_tendency then
    -- pick return type based on conductor character
    local return_types
    if lock_16 then
      -- locked: favor full and rhythm returns (structural)
      return_types = {"full", "full", "rhythm", "partial", "ghost"}
    else
      -- loose: favor partial and ghost returns (suggestive)
      return_types = {"partial", "partial", "melody", "ghost", "ghost", "rhythm"}
    end
    local rtype = return_types[math.random(#return_types)]
    evo.return_home(tracks, rtype)
    -- signal to UI
    if evo._harmony_callback then
      -- reuse flash via a pseudo-callback
    end
  end

  -- (probability riding now handled by arrangement intelligence above)

  -- ======== HARMONIC MOVES ========
  -- occasional key/scale changes based on conductor's harmony_set
  local harm_set = conductor_profile and conductor_profile.harmony_set
  local harm_chance = conductor_profile and conductor_profile.harmony_chance or 0.03
  local requantize = conductor_profile and conductor_profile.requantize or false
  if harm_set and math.random() < harm_chance * intensity then
    if evo._harmony_callback then
      evo._harmony_callback(harm_set, requantize)
    end
  end
end

-- set by slap.lua so conductor can trigger harmonic moves
function evo.set_harmony_callback(fn)
  evo._harmony_callback = fn
end

return evo
