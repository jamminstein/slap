-- song_engine.lua
-- conductor for personality-based autonomous evolution
-- supports two modes:
--   standard: section-based forms with fixed energy arcs
--   atemporal: drunk-walk energy, stochastic transitions, section stretching

local util = require "util"

local song = {}

song.active = false
song.personality_idx = 1
song.section_idx = 1
song.tick = 0
song.section_ticks = 0
song.song_count = 0
song.energy = 0.5
song.progress = 0
song.mood_name = ""  -- for display

-- references set during init
song.personalities = nil
song.evo = nil
song.tracks = nil
song.clock_id = nil

-- anchors: saved param state for restore on stop
song.anchors = {}

local ANCHOR_PARAMS = {
  "t1_cutoff", "t1_res", "t1_gate", "t1_level", "t1_spread", "t1_brightness",
  "t2_cutoff", "t2_res", "t2_gate", "t2_level", "t2_accent",
  "t3_cutoff", "t3_res", "t3_gate", "t3_level", "t3_morph", "t3_fmamt", "t3_lfoRate", "t3_lfoDepth",
  "t4_cutoff", "t4_res", "t4_gate", "t4_level", "t4_pwm", "t4_bits",
  "reverb_mix", "reverb_room", "reverb_damp",
}

local function save_anchors()
  song.anchors = {}
  for _, p in ipairs(ANCHOR_PARAMS) do
    local ok, val = pcall(function() return params:get(p) end)
    if ok then song.anchors[p] = val end
  end
end

local function restore_anchors()
  for p, val in pairs(song.anchors) do
    pcall(function() params:set(p, val) end)
  end
end

local function get_personality()
  return song.personalities[song.personality_idx]
end

local function get_section()
  local p = get_personality()
  if not p or not p.form then return nil end
  return p.form[song.section_idx]
end

local function compute_section_ticks(section, personality)
  local tpb = personality.ticks_per_bar or 2
  local bars = section.bars or 8

  -- atemporal: randomize section length dramatically
  if personality.atemporal then
    local base = section.bars_range or {24, 96}
    bars = math.random(base[1], base[2])
  end

  return bars * tpb
end

local function on_section_start()
  local p = get_personality()
  local s = get_section()
  if not p or not s then return end

  song.tick = 0
  song.section_ticks = compute_section_ticks(s, p)
  song.progress = 0
  song.mood_name = s.name or ""

  -- atemporal: start energy from current level (continuity), not section start
  if p.atemporal then
    -- gentle nudge toward section's center energy
    local center = (s.energy[1] + s.energy[2]) * 0.5
    song.energy = song.energy * 0.7 + center * 0.3
  else
    song.energy = s.energy[1]
  end

  -- generate fresh patterns
  local should_regen = (song.section_idx == 1 or s.transition == "cut")
  -- atemporal: 40% chance to regenerate 1-2 tracks on any section start
  if p.atemporal and not should_regen and math.random() < 0.4 then
    should_regen = true
  end

  if should_regen then
    local regen_tracks = p.focus_tracks or {}
    -- atemporal: only regenerate 1-2 random tracks, not all
    if p.atemporal and #regen_tracks > 2 then
      local shuffled = {}
      for _, ti in ipairs(regen_tracks) do table.insert(shuffled, ti) end
      -- fisher-yates partial shuffle
      for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
      end
      regen_tracks = {shuffled[1]}
      if math.random() < 0.4 then table.insert(regen_tracks, shuffled[2]) end
    end

    for _, ti in ipairs(regen_tracks) do
      if song.tracks[ti] then
        local density = p.density_range and
          (p.density_range[1] + (p.density_range[2] - p.density_range[1]) * song.energy) or 0.5
        local scale = song.tracks._scale_notes or {}
        if #scale > 0 then
          song.evo.generate_pattern(song.tracks, ti, scale, density, 0.4, 0.9)
        end
      end
    end
  end
end

local function transition_to_next()
  local p = get_personality()
  if not p then return end

  -- atemporal: chance to SKIP a section (jump to random one)
  if p.atemporal and math.random() < 0.25 then
    song.section_idx = math.random(1, #p.form)
  else
    song.section_idx = song.section_idx + 1
  end

  if song.section_idx > #p.form then
    song.song_count = song.song_count + 1
    if p.on_cycle == "vary" then
      song.section_idx = 1
      for _, section in ipairs(p.form) do
        if p.atemporal then
          -- dramatic length variation
          section.bars = util.clamp(section.bars + math.random(-8, 8), 16, 128)
        else
          section.bars = util.clamp(section.bars + math.random(-2, 2), 4, 24)
        end
      end
    else
      song.stop()
      return
    end
  end

  on_section_start()
end

local function conductor_tick()
  local p = get_personality()
  local s = get_section()
  if not p or not s then return end

  song.tick = song.tick + 1
  song.progress = util.clamp(song.tick / math.max(song.section_ticks, 1), 0, 1)

  if p.atemporal then
    -- ATEMPORAL: energy drunk walk with soft bounds from section range
    local drift = (math.random() - 0.5) * 0.04
    -- gentle gravity toward section's energy center
    local center = (s.energy[1] + s.energy[2]) * 0.5
    local gravity = (center - song.energy) * 0.005
    song.energy = util.clamp(song.energy + drift + gravity, 0.03, 0.97)
  else
    -- STANDARD: linear interpolation
    song.energy = s.energy[1] + (s.energy[2] - s.energy[1]) * song.progress
  end

  -- call mood function
  local mood_fn = p.moods and p.moods[s.mood]
  if mood_fn then
    local ok, err = pcall(mood_fn, song.evo, song.tracks, song.progress, song.energy)
    if not ok then print("personality error: " .. tostring(err)) end
  end

  -- section transition
  if song.tick >= song.section_ticks then
    if p.atemporal and math.random() < 0.35 then
      -- 35% chance to EXTEND current section instead of transitioning
      local extend = math.random(12, 32) * (p.ticks_per_bar or 1)
      song.section_ticks = song.section_ticks + extend
      -- reset progress but keep energy (it's drunk-walking anyway)
      song.tick = math.floor(song.section_ticks * 0.6)
    else
      transition_to_next()
    end
  end
end

-- PUBLIC API

function song.init(personalities_table, evolution_module, tracks_table)
  song.personalities = personalities_table
  song.evo = evolution_module
  song.tracks = tracks_table
end

function song.start(personality_idx)
  if song.active then song.stop() end

  song.personality_idx = personality_idx or 1
  song.section_idx = 1
  song.song_count = 0
  song.active = true

  save_anchors()
  on_section_start()

  local p = get_personality()
  local speed = p and p.tick_speed or 1

  song.clock_id = clock.run(function()
    while song.active do
      clock.sync(speed)
      if song.active then
        local ok, err = pcall(conductor_tick)
        if not ok then print("conductor error: " .. tostring(err)) end
      end
    end
  end)
end

function song.stop()
  song.active = false
  if song.clock_id then
    clock.cancel(song.clock_id)
    song.clock_id = nil
  end
  restore_anchors()
end

function song.get_personality_name()
  local p = get_personality()
  return p and p.name or "?"
end

function song.get_section_name()
  return song.mood_name or "?"
end

function song.get_progress()
  return song.progress
end

function song.get_energy()
  return song.energy
end

function song.get_form_progress()
  local p = get_personality()
  if not p or not p.form then return 0 end
  return (song.section_idx - 1 + song.progress) / #p.form
end

return song
