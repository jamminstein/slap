-- slap
-- 4-part autonomous synth sequencer
-- inspired by Fred's Lab:
-- MANTA / ZKIT / TOROID / BZZT
--
-- 6 pages: SEQ / VOICE / MIX / MOD / ASSIST / AUTO
-- E1: page select
-- K2: play/stop
-- K3: hold=ALT, tap=page action
--
-- grid rows 1-4: step toggles
-- grid row 5: mute toggles
-- grid row 6: solo toggles
-- grid rows 7-8: pattern snapshots
--
-- v3.0 @jamminstein

engine.name = "Slap"

local musicutil = require "musicutil"
local util = require "util"
local bez = include("lib/bezier_mod")
local evo = include("lib/evolution")
local personalities = include("lib/personalities")
local song_engine = include("lib/song_engine")
local robot = include("lib/robot")
local harmony = include("lib/harmony")

-- ======== CONSTANTS ========

local PAGES = {"SEQ", "VOICE", "MIX", "MOD", "ASSIST", "AUTO"}
local NUM_TRACKS = 4
local MAX_STEPS = 24
local TRACK_NAMES = {"MANTA", "ZKIT", "TOROID", "BZZT"}
local TRACK_SHORT = {"MNT", "ZKT", "TRD", "BZT"}

-- timbral presets: each reshapes all 4 voices at once
local TIMBRES = {
  {name = "BASS",    desc = "sub heavy",
    t1 = {cutoff=1500, res=0.1, gate=0.9, spread=0.2, brightness=0.3},
    t2 = {cutoff=800, res=0.7, gate=0.5, accent=0.9},
    t3 = {cutoff=2000, res=0.2, gate=0.7, morph=0.1, fmamt=0.05},
    t4 = {cutoff=3000, res=0.1, gate=0.1, engine_sel=0, pwm=0.5, bits=12}},
  {name = "GLITCH",  desc = "broken digital",
    t1 = {cutoff=6000, res=0.4, gate=0.3, spread=0.8, brightness=0.9},
    t2 = {cutoff=3000, res=0.8, gate=0.15, accent=0.6},
    t3 = {cutoff=8000, res=0.5, gate=0.2, morph=0.9, fmamt=0.7},
    t4 = {cutoff=10000, res=0.3, gate=0.05, engine_sel=1, pwm=0.3, bits=6}},
  {name = "CLASSIC", desc = "warm analog",
    t1 = {cutoff=4000, res=0.15, gate=0.85, spread=0.4, brightness=0.5},
    t2 = {cutoff=1200, res=0.5, gate=0.6, accent=0.5},
    t3 = {cutoff=5000, res=0.25, gate=0.5, morph=0.3, fmamt=0.1},
    t4 = {cutoff=6000, res=0.15, gate=0.15, engine_sel=0, pwm=0.5, bits=14}},
  {name = "DARK",    desc = "low and murky",
    t1 = {cutoff=800, res=0.2, gate=0.95, spread=0.6, brightness=0.15},
    t2 = {cutoff=300, res=0.6, gate=0.7, accent=0.3},
    t3 = {cutoff=1500, res=0.3, gate=0.8, morph=0.5, fmamt=0.2},
    t4 = {cutoff=2000, res=0.2, gate=0.2, engine_sel=3, pwm=0.5, bits=10}},
  {name = "BRIGHT",  desc = "crystalline",
    t1 = {cutoff=10000, res=0.1, gate=0.7, spread=0.9, brightness=0.95},
    t2 = {cutoff=5000, res=0.3, gate=0.3, accent=0.7},
    t3 = {cutoff=12000, res=0.15, gate=0.4, morph=0.7, fmamt=0.4},
    t4 = {cutoff=12000, res=0.1, gate=0.08, engine_sel=2, pwm=0.5, bits=16}},
  {name = "ACID",    desc = "squelch madness",
    t1 = {cutoff=2000, res=0.3, gate=0.6, spread=0.3, brightness=0.4},
    t2 = {cutoff=600, res=0.9, gate=0.3, accent=1.0},
    t3 = {cutoff=3000, res=0.6, gate=0.4, morph=0.4, fmamt=0.3},
    t4 = {cutoff=5000, res=0.4, gate=0.1, engine_sel=0, pwm=0.3, bits=10}},
  {name = "SPACE",   desc = "vast and distant",
    t1 = {cutoff=3000, res=0.1, gate=0.95, spread=0.8, brightness=0.6},
    t2 = {cutoff=1000, res=0.3, gate=0.8, accent=0.4},
    t3 = {cutoff=4000, res=0.2, gate=0.7, morph=0.6, fmamt=0.15},
    t4 = {cutoff=4000, res=0.1, gate=0.25, engine_sel=3, pwm=0.5, bits=12}},
  {name = "PERC",    desc = "all rhythm",
    t1 = {cutoff=5000, res=0.2, gate=0.15, spread=0.1, brightness=0.7},
    t2 = {cutoff=2000, res=0.5, gate=0.1, accent=0.8},
    t3 = {cutoff=7000, res=0.3, gate=0.1, morph=0.8, fmamt=0.5},
    t4 = {cutoff=8000, res=0.2, gate=0.05, engine_sel=0, pwm=0.5, bits=8}},
  {name = "WILDERNESS", desc = "weird machines",
    t1 = {cutoff=4000, res=0.35, gate=0.7, spread=0.9, brightness=0.95},
    t2 = {cutoff=500, res=0.85, gate=0.3, accent=1.0},
    t3 = {cutoff=6000, res=0.4, gate=0.5, morph=0.0, fmamt=0.7},
    t4 = {cutoff=9000, res=0.3, gate=0.1, engine_sel=1, pwm=0.15, bits=5}},
  {name = "ALIEN",   desc = "otherworldly",
    t1 = {cutoff=8000, res=0.1, gate=0.95, spread=0.95, brightness=0.1},
    t2 = {cutoff=200, res=0.9, gate=0.6, accent=0.4},
    t3 = {cutoff=3000, res=0.5, gate=0.8, morph=1.0, fmamt=0.6},
    t4 = {cutoff=12000, res=0.05, gate=0.03, engine_sel=3, pwm=0.5, bits=4}},
}
local current_timbre = 0  -- 0 = none active

local SCALE_NAMES = harmony.SCALE_NAMES  -- 23 scales
local SCALE_SHORT = harmony.SCALE_NAMES  -- same, they're already short

-- clock divisions per track: {name, sync_value}
local DIVISIONS = {
  {"1/32", 1/8}, {"1/16", 1/4}, {"1/8", 1/2}, {"1/4", 1}, {"1/2", 2},
}

-- bezier modulation routing targets
local MOD_ROUTES = {
  {name = "MNT.cut", param = "t1_cutoff", sc_param = "cutoff", track = 1, base_mult = 0.35},
  {name = "MNT.spd", param = "t1_spread", sc_param = "spread", track = 1, base_mult = 0.4},
  {name = "ZKT.cut", param = "t2_cutoff", sc_param = "cutoff", track = 2, base_mult = 0.35},
  {name = "ZKT.acc", param = "t2_accent", sc_param = "accent", track = 2, base_mult = 0.4},
  {name = "TRD.cut", param = "t3_cutoff", sc_param = "cutoff", track = 3, base_mult = 0.35},
  {name = "TRD.mrp", param = "t3_morph",  sc_param = "morph",  track = 3, base_mult = 0.4},
  {name = "BZT.cut", param = "t4_cutoff", sc_param = "cutoff", track = 4, base_mult = 0.3},
  {name = "BZT.pwm", param = "t4_pwm",    sc_param = "pwm",    track = 4, base_mult = 0.4},
}
local mod_amounts = {0, 0, 0, 0, 0, 0, 0, 0}
local mod_values = {0, 0, 0, 0, 0, 0, 0, 0}
local selected_route = 1

-- ======== STATE ========

local current_page = 1
local playing = false
local selected_track = 1
local selected_step = 1
local k3_held = false
local k3_press_time = 0
local k3_encoder_used = false  -- true if encoder turned while K3 held

-- explorer
local explorer_on = false
local robot_profile = 1
local conductor_intensity_mult = 1.0  -- user-controllable on AUTO E3

-- scale
local scale_notes = {}
local root_note = 38  -- D2
local scale_type = 1  -- minor pentatonic

-- swing
local swing_amount = 0  -- 0-100

-- mute/solo
local track_mute = {false, false, false, false}
local track_solo = {false, false, false, false}

-- pattern snapshots (8 slots)
local snapshots = {}

-- MIDI
local midi_out_device = nil
local midi_out_ch = 0  -- 0 = off

-- OP-XY: per-track MIDI channels
local opxy_device = nil
local opxy_channels = {0, 0, 0, 0}  -- 0 = off, 1-16 = channel per track

-- micro-assistants
local ASSISTANT_NAMES = {"LSD", "WATER", "TURM"}
local assistant_intensity = {0.5, 0.5, 0.5}
local assistant_activity = {0, 0, 0}
local selected_assistant = 1

-- tracks
local tracks = {}

-- grid
local g = grid.connect()
local held_steps = {}

-- visual feedback
local param_flash = 0
local param_flash_name = ""
local step_flash = {}
for t = 1, NUM_TRACKS do
  step_flash[t] = {}
  for i = 1, MAX_STEPS do step_flash[t][i] = 0 end
end

-- ======== SCALE ========

function build_scale()
  scale_notes = harmony.build_scale(root_note, scale_type)
  tracks._scale_notes = scale_notes
end

-- ======== TRACK INIT ========

function init_tracks()
  for i = 1, NUM_TRACKS do
    tracks[i] = {
      steps = {},
      num_steps = 16,
      position = 0,
      division = 2,       -- index into DIVISIONS (1/16 default)
      cutoff = 2000, res = 0.3, gate = 0.7, level = 1.0,
      probability = 100,  -- 0-100% chance each step fires
    }
    for s = 1, MAX_STEPS do
      tracks[i].steps[s] = {on = false, note = 60, vel = 0.8, prob = 100}
    end
  end

  -- MANTA: 12-step pads, 1/8 division — euclidean E(4,12)
  local m = tracks[1]
  m.num_steps = 12; m.division = 3; m.probability = 85
  m.cutoff = 2000; m.res = 0.15; m.gate = 0.8
  m.spread = 0.3; m.brightness = 0.4
  local m_euc = harmony.euclidean(12, 4, 0)
  local m_notes = {50, 53, 55, 57, 50, 55, 53, 50, 57, 55, 50, 53}
  for s = 1, 12 do
    m.steps[s] = {on = m_euc[s] or false, note = m_notes[s], vel = 0.4 + math.random() * 0.25, prob = 100}
  end

  -- ZKIT: 16-step acid bass, 1/16 division — euclidean E(6,16)
  local z = tracks[2]
  z.num_steps = 16; z.division = 2; z.probability = 80
  z.cutoff = 400; z.res = 0.6; z.gate = 0.4; z.accent = 0.7
  local z_euc = harmony.euclidean(16, 6, 0)
  local z_notes = {38, 38, 45, 38, 43, 38, 45, 43, 38, 38, 45, 38, 43, 38, 45, 38}
  for s = 1, 16 do
    z.steps[s] = {on = z_euc[s] or false, note = z_notes[s], vel = z_euc[s] and (0.6 + math.random() * 0.35) or 0.5, prob = 100}
  end

  -- TOROID: 14-step melody, 1/16 division — euclidean E(5,14)
  local t = tracks[3]
  t.num_steps = 14; t.division = 2; t.probability = 70
  t.cutoff = 2500; t.res = 0.25; t.gate = 0.5
  t.morph = 0.35; t.fmamt = 0.25; t.lfoRate = 3; t.lfoDepth = 0.15
  local t_euc = harmony.euclidean(14, 5, 2)
  local t_notes = {62, 60, 65, 62, 67, 65, 60, 62, 67, 65, 62, 60, 65, 67}
  for s = 1, 14 do
    t.steps[s] = {on = t_euc[s] or false, note = t_notes[s], vel = t_euc[s] and (0.5 + math.random() * 0.35) or 0.5, prob = 100}
  end

  -- BZZT: 10-step percussion, 1/32 division — euclidean E(4,10)
  local b = tracks[4]
  b.num_steps = 10; b.division = 1; b.probability = 75
  b.cutoff = 7000; b.res = 0.15; b.gate = 0.15
  b.engine_sel = 0; b.pwm = 0.5; b.bits = 10
  local b_euc = harmony.euclidean(10, 4, 1)
  local b_notes = {48, 60, 55, 48, 67, 60, 48, 55, 67, 60}
  for s = 1, 10 do
    b.steps[s] = {on = b_euc[s] or false, note = b_notes[s], vel = b_euc[s] and (0.6 + math.random() * 0.35) or 0.5, prob = 100}
  end

  tracks._scale_notes = scale_notes
end

-- ======== SNAPSHOTS ========

function save_snapshot(slot)
  snapshots[slot] = {}
  for t = 1, NUM_TRACKS do
    snapshots[slot][t] = {
      steps = {}, num_steps = tracks[t].num_steps, division = tracks[t].division,
    }
    for s = 1, MAX_STEPS do
      local st = tracks[t].steps[s]
      snapshots[slot][t].steps[s] = {on = st.on, note = st.note, vel = st.vel, prob = st.prob}
    end
  end
end

function load_snapshot(slot)
  if not snapshots[slot] then return false end
  for t = 1, NUM_TRACKS do
    local snap = snapshots[slot][t]
    tracks[t].num_steps = snap.num_steps
    tracks[t].division = snap.division
    for s = 1, MAX_STEPS do
      local st = snap.steps[s]
      tracks[t].steps[s] = {on = st.on, note = st.note, vel = st.vel, prob = st.prob}
    end
  end
  return true
end

-- ======== ENGINE PARAM SYNC ========

function send_track_params(i)
  local t = tracks[i]
  engine.set_param(i - 1, "cutoff", t.cutoff)
  engine.set_param(i - 1, "res", t.res)
  if i == 1 then
    engine.set_param(0, "spread", t.spread or 0.3)
    engine.set_param(0, "brightness", t.brightness or 0.7)
  elseif i == 2 then
    engine.set_param(1, "accent", t.accent or 0.5)
  elseif i == 3 then
    engine.set_param(2, "morph", t.morph or 0.5)
    engine.set_param(2, "fmamt", t.fmamt or 0.3)
    engine.set_param(2, "lfoRate", t.lfoRate or 2)
    engine.set_param(2, "lfoDepth", t.lfoDepth or 0.2)
  elseif i == 4 then
    engine.set_param(3, "engine_sel", t.engine_sel or 0)
    engine.set_param(3, "pwm", t.pwm or 0.5)
    engine.set_param(3, "bits", t.bits or 10)
  end
end

local function apply_timbre(idx)
  local t = TIMBRES[idx]
  if not t then return end
  current_timbre = idx
  local mappings = {t.t1, t.t2, t.t3, t.t4}
  for i = 1, 4 do
    local m = mappings[i]
    local pre = "t" .. i .. "_"
    local tr = tracks[i]
    for k, v in pairs(m) do
      if k == "engine_sel" then
        tr.engine_sel = v
        pcall(function() params:set(pre .. "engine", v + 1) end)
        engine.set_param(i - 1, "engine_sel", v)
        evo.user_touched(pre .. "engine")
      else
        pcall(function() params:set(pre .. k, v) end)
        tr[k] = v
        -- protect from conductor/assistant override for 8 seconds
        evo.user_touched(pre .. k)
      end
    end
    send_track_params(i)
  end
  -- preset-specific reverb
  if t.name == "SPACE" then
    params:set("reverb_mix", 0.5)
    params:set("reverb_room", 0.9)
  elseif t.name == "PERC" or t.name == "BASS" then
    params:set("reverb_mix", 0.15)
  elseif t.name == "DARK" then
    params:set("reverb_mix", 0.35)
    params:set("reverb_room", 0.7)
  end
end

local function flash(name)
  param_flash = 1
  param_flash_name = name
end

local function user_delta(name, delta)
  params:delta(name, delta)
  evo.user_touched(name)
  flash(name)
end

local function user_set(name, val)
  params:set(name, val)
  evo.user_touched(name)
  flash(name)
end

-- ======== PARAMS ========

function init_params()
  params:add_separator("SLAP")

  -- scale
  params:add_number("root_note", "root note", 24, 72, root_note)
  params:set_action("root_note", function(v) root_note = v; build_scale() end)

  params:add_option("scale_type", "scale", harmony.SCALE_NAMES, scale_type)
  params:set_action("scale_type", function(v) scale_type = v; build_scale() end)

  params:add_number("swing", "swing", 0, 80, 0)
  params:set_action("swing", function(v) swing_amount = v end)

  -- reverb
  params:add_control("reverb_mix", "reverb mix",
    controlspec.new(0, 1, 'lin', 0, 0.3))
  params:set_action("reverb_mix", function(v) engine.reverb_mix(v) end)

  params:add_control("reverb_room", "reverb room",
    controlspec.new(0, 1, 'lin', 0, 0.7))
  params:set_action("reverb_room", function(v) engine.reverb_room(v) end)

  params:add_control("reverb_damp", "reverb damp",
    controlspec.new(0, 1, 'lin', 0, 0.5))
  params:set_action("reverb_damp", function(v) engine.reverb_damp(v) end)

  -- compressor
  params:add_separator("COMPRESSOR")
  params:add_control("comp_thresh", "comp threshold",
    controlspec.new(0.05, 1, 'exp', 0, 0.5))
  params:set_action("comp_thresh", function(v) engine.comp_thresh(v) end)

  params:add_control("comp_ratio", "comp ratio",
    controlspec.new(1, 20, 'exp', 0, 3))
  params:set_action("comp_ratio", function(v) engine.comp_ratio(v) end)

  params:add_control("comp_makeup", "comp makeup",
    controlspec.new(0.5, 4, 'exp', 0, 1.0))
  params:set_action("comp_makeup", function(v) engine.comp_makeup(v) end)

  -- MIDI
  params:add_separator("MIDI")
  params:add_number("midi_out_device", "midi out device", 1, 4, 1)
  params:set_action("midi_out_device", function(v)
    midi_out_device = midi.connect(v)
  end)
  params:add_number("midi_out_ch", "midi out ch (0=off)", 0, 16, 0)
  params:set_action("midi_out_ch", function(v) midi_out_ch = v end)

  -- OP-XY
  params:add_separator("OP-XY")
  params:add_number("opxy_device", "opxy device", 1, 4, 1)
  params:set_action("opxy_device", function(v) opxy_device = midi.connect(v) end)
  for i = 1, 4 do
    params:add_number("opxy_ch_" .. i, TRACK_SHORT[i] .. " opxy ch (0=off)", 0, 16, 0)
    params:set_action("opxy_ch_" .. i, function(v) opxy_channels[i] = v end)
  end

  -- bezier mod
  params:add_separator("MODULATION")
  params:add_control("bez_speed", "bez speed",
    controlspec.new(0.01, 5, 'exp', 0, 0.3))
  params:set_action("bez_speed", function(v)
    bez.set_speed("curve1", v)
    bez.set_speed("curve2", v * 2.3)
    bez.set_speed("curve3", v * 4.7)
    bez.set_speed("curve4", v * 0.5)  -- slowest
    bez.set_speed("curve5", v * 8)    -- fastest
  end)
  params:add_control("bez_tension", "bez tension",
    controlspec.new(0.1, 1.5, 'lin', 0.01, 0.6))
  params:set_action("bez_tension", function(v) bez.set_tension(v) end)

  params:add_control("lfo_freq", "lfo freq",
    controlspec.new(0.01, 10, 'exp', 0, 0.3, "hz"))
  params:set_action("lfo_freq", function(v) bez.set_speed("lfo", v) end)

  params:add_control("xmod_speed", "xmod speed",
    controlspec.new(0, 1, 'lin', 0.01, 0))
  params:set_action("xmod_speed", function(v)
    bez.set_xmod("curve1", "speed", v)
    bez.set_xmod("curve2", "speed", v)
    bez.set_xmod("curve3", "speed", v)
  end)

  for i, route in ipairs(MOD_ROUTES) do
    params:add_control("mod_" .. i, "mod>" .. route.name,
      controlspec.new(0, 1, 'lin', 0.01, 0))
    params:set_action("mod_" .. i, function(v) mod_amounts[i] = v end)
  end

  -- explorer
  params:add_separator("AUTONOMOUS")
  params:add_option("robot_profile", "robot", robot.NAMES, 1)
  params:set_action("robot_profile", function(v)
    robot_profile = v
    local prof = robot.profiles[v]
    if not prof then return end

    -- apply default mod routes
    if prof.default_mods then
      for i, amt in ipairs(prof.default_mods) do
        if i <= #MOD_ROUTES then
          mod_amounts[i] = amt
          pcall(function() params:set("mod_" .. i, amt) end)
        end
      end
    end

    -- apply default timbre
    if prof.default_timbre and prof.default_timbre > 0 and prof.default_timbre <= #TIMBRES then
      current_timbre = prof.default_timbre
      apply_timbre(current_timbre)
    end

    -- apply default clock divisions
    if prof.default_divisions then
      for i, div in ipairs(prof.default_divisions) do
        if tracks[i] then
          tracks[i].division = div
          pcall(function() params:set("t" .. i .. "_division", div) end)
        end
      end
    end

    -- regenerate patterns when switching conductor
    local sc = tracks._scale_notes or scale_notes
    if #sc > 0 and playing then
      if prof.lock_16 then
        -- locked conductors: per-conductor euclidean patterns + probability
        local pulses = prof.default_pulses or {3, 5, 4, 4}
        local probs = prof.default_probability or {90, 95, 85, 90}
        for t = 1, NUM_TRACKS do
          tracks[t].num_steps = 16
          local p = pulses[t] or 4
          local euc = harmony.euclidean(16, p, math.random(0, 15))
          for s = 1, 16 do
            tracks[t].steps[s].on = euc[s] or false
            if tracks[t].steps[s].on and #sc > 0 then
              tracks[t].steps[s].note = sc[math.random(#sc)]
              tracks[t].steps[s].vel = 0.5 + math.random() * 0.4
            end
          end
          tracks[t].probability = probs[t] or 90
          pcall(function() params:set("t" .. t .. "_probability", tracks[t].probability) end)
        end
      else
        -- loose conductors: random sparse patterns
        for t = 1, NUM_TRACKS do
          local density = 0.2 + math.random() * 0.3
          evo.generate_pattern(tracks, t, sc, density, 0.3, 0.9)
        end
      end
      evo.save_home(tracks)
    end

    -- restart explorer with new personality
    if explorer_on then
      stop_explorer()
      start_explorer()
    end
  end)

  -- per-track params
  for i = 1, NUM_TRACKS do
    local t = tracks[i]
    local pre = "t" .. i .. "_"
    params:add_separator(TRACK_NAMES[i])

    params:add_option(pre.."division", "clock div",
      {"1/32","1/16","1/8","1/4","1/2"}, t.division)
    params:set_action(pre.."division", function(v) t.division = v end)

    params:add_number(pre.."probability", "probability", 0, 100, t.probability)
    params:set_action(pre.."probability", function(v) t.probability = v end)

    params:add_control(pre.."cutoff", "cutoff",
      controlspec.new(30, 12000, 'exp', 0, t.cutoff, "hz"))
    params:set_action(pre.."cutoff", function(v) t.cutoff = v; engine.set_param(i-1, "cutoff", v) end)

    params:add_control(pre.."res", "resonance",
      controlspec.new(0, 1, 'lin', 0.01, t.res))
    params:set_action(pre.."res", function(v) t.res = v; engine.set_param(i-1, "res", v) end)

    params:add_control(pre.."gate", "gate length",
      controlspec.new(0.05, 1, 'lin', 0.01, t.gate))
    params:set_action(pre.."gate", function(v) t.gate = v end)

    params:add_control(pre.."level", "level",
      controlspec.new(0, 1, 'lin', 0.01, t.level))
    params:set_action(pre.."level", function(v) t.level = v end)

    if i == 1 then
      params:add_control(pre.."spread", "spectral spread",
        controlspec.new(0, 1, 'lin', 0.01, t.spread or 0.4))
      params:set_action(pre.."spread", function(v) t.spread = v; engine.set_param(0, "spread", v) end)
      params:add_control(pre.."brightness", "brightness",
        controlspec.new(0, 1, 'lin', 0.01, t.brightness or 0.6))
      params:set_action(pre.."brightness", function(v) t.brightness = v; engine.set_param(0, "brightness", v) end)
    elseif i == 2 then
      params:add_control(pre.."accent", "filter accent",
        controlspec.new(0, 1, 'lin', 0.01, t.accent or 0.8))
      params:set_action(pre.."accent", function(v) t.accent = v; engine.set_param(1, "accent", v) end)
    elseif i == 3 then
      params:add_control(pre.."morph", "waveform morph",
        controlspec.new(0, 1, 'lin', 0.01, t.morph or 0.35))
      params:set_action(pre.."morph", function(v) t.morph = v; engine.set_param(2, "morph", v) end)
      params:add_control(pre.."fmamt", "FM amount",
        controlspec.new(0, 1, 'lin', 0.01, t.fmamt or 0.25))
      params:set_action(pre.."fmamt", function(v) t.fmamt = v; engine.set_param(2, "fmamt", v) end)
      params:add_control(pre.."lfoRate", "LFO rate",
        controlspec.new(0.1, 20, 'exp', 0, t.lfoRate or 3, "hz"))
      params:set_action(pre.."lfoRate", function(v) t.lfoRate = v; engine.set_param(2, "lfoRate", v) end)
      params:add_control(pre.."lfoDepth", "LFO depth",
        controlspec.new(0, 1, 'lin', 0.01, t.lfoDepth or 0.15))
      params:set_action(pre.."lfoDepth", function(v) t.lfoDepth = v; engine.set_param(2, "lfoDepth", v) end)
    elseif i == 4 then
      params:add_option(pre.."engine", "engine",
        {"PULSE", "FM", "WAVES", "NOISE"}, (t.engine_sel or 0) + 1)
      params:set_action(pre.."engine", function(v) t.engine_sel = v-1; engine.set_param(3, "engine_sel", v-1) end)
      params:add_control(pre.."pwm", "pulse width",
        controlspec.new(0.05, 0.95, 'lin', 0.01, t.pwm or 0.5))
      params:set_action(pre.."pwm", function(v) t.pwm = v; engine.set_param(3, "pwm", v) end)
      params:add_control(pre.."bits", "bit depth",
        controlspec.new(4, 16, 'lin', 1, t.bits or 10, "bits"))
      params:set_action(pre.."bits", function(v) t.bits = v; engine.set_param(3, "bits", v) end)
    end
  end
end

-- ======== INIT ========

function init()
  build_scale()
  init_tracks()
  init_params()
  bez.init()
  song_engine.init(personalities, evo, tracks)
  midi_out_device = midi.connect(1)
  opxy_device = midi.connect(1)

  for i = 1, NUM_TRACKS do send_track_params(i) end

  -- default stereo spread
  local default_pan = {-0.5, 0.3, -0.2, 0.5}
  for i = 1, 4 do
    tracks[i].pan = default_pan[i]
    engine.set_param(i - 1, "pan", default_pan[i])
  end

  params:set("clock_tempo", 110)

  -- activate default mod routes for starting conductor
  local init_prof = robot.profiles[robot_profile]
  if init_prof and init_prof.default_mods then
    for i, amt in ipairs(init_prof.default_mods) do
      if i <= #MOD_ROUTES then
        mod_amounts[i] = amt
        pcall(function() params:set("mod_" .. i, amt) end)
      end
    end
  end

  -- harmony callback: conductor triggers key/scale changes
  evo.set_harmony_callback(function(move_set, requantize)
    local result, move_name = harmony.random_move(root_note, scale_type, move_set)
    if result then
      root_note = result.root
      scale_type = result.scale_idx
      params:set("root_note", root_note)
      params:set("scale_type", scale_type)
      build_scale()
      -- requantize: snap ALL existing notes to the new scale immediately
      if requantize and #scale_notes > 0 then
        for t = 1, NUM_TRACKS do
          for s = 1, tracks[t].num_steps do
            local step = tracks[t].steps[s]
            if step.on then
              step.note = musicutil.snap_note_to_array(step.note, scale_notes)
            end
          end
        end
      end
      flash(move_name .. (requantize and "!" or ""))
    end
  end)

  g.key = grid_key

  -- main loop: screen + modulation at 15fps
  clock.run(function()
    while true do
      clock.sleep(1/15)
      apply_bezier_modulation()
      robot.update(1/15)
      param_flash = param_flash * 0.8
      for a = 1, 3 do assistant_activity[a] = assistant_activity[a] * 0.92 end
      for t = 1, NUM_TRACKS do
        for i = 1, MAX_STEPS do step_flash[t][i] = step_flash[t][i] * 0.7 end
      end
      redraw()
      grid_redraw()
    end
  end)

  -- MICRO-ASSISTANTS
  -- LSD: perception
  clock.run(function()
    while true do
      clock.sleep(2.5 + math.random() * 4)
      if not playing or assistant_intensity[1] < 0.01 or conductor_intensity_mult < 0.01 then goto lsd_skip end
      local inten = assistant_intensity[1] * conductor_intensity_mult
      local picks = {
        {"bez_speed",0.01,3,0.04},{"bez_tension",0.1,1.5,0.05},
        {"xmod_speed",0,0.8,0.04},{"lfo_freq",0.01,8,0.03},
      }
      local p = picks[math.random(#picks)]
      if not evo.user_owned_check(p[1]) then
        local ok, cur = pcall(function() return params:get(p[1]) end)
        if ok then
          local drift = (math.random()-0.5) * (p[3]-p[2]) * p[4] * inten * 2
          params:set(p[1], util.clamp(cur+drift, p[2], p[3]))
        end
      end
      assistant_activity[1] = 1
      ::lsd_skip::
    end
  end)

  -- WATER: space + levels + pan
  clock.run(function()
    while true do
      clock.sleep(3 + math.random() * 5)
      if not playing or assistant_intensity[2] < 0.01 or conductor_intensity_mult < 0.01 then goto water_skip end
      local inten = assistant_intensity[2] * conductor_intensity_mult
      local picks = {
        {"reverb_room",0.2,0.95,0.03},{"reverb_damp",0.1,0.9,0.03},
        {"t1_res",0.05,0.6,0.02},{"t2_res",0.1,0.9,0.03},
        {"t3_res",0.05,0.7,0.02},{"t4_res",0.05,0.5,0.02},
        {"t1_gate",0.4,1.0,0.02},{"t2_gate",0.1,0.8,0.03},
        {"t3_gate",0.2,0.9,0.02},{"t4_gate",0.05,0.4,0.02},
        {"t1_level",0.3,1.0,0.03},{"t2_level",0.3,1.0,0.03},
        {"t3_level",0.3,1.0,0.03},{"t4_level",0.2,1.0,0.03},
      }
      -- drift pan from current position (respects user override)
      local pt = math.random(1, 4)
      if not evo.user_owned_check("pan_" .. pt) then
        local cur_pan = tracks[pt].pan or 0
        local pan_drift = (math.random() - 0.5) * inten * 0.15
        tracks[pt].pan = util.clamp(cur_pan + pan_drift, -0.8, 0.8)
        engine.set_param(pt - 1, "pan", tracks[pt].pan)
      end
      for _ = 1, math.random(1,2) do
        local p = picks[math.random(#picks)]
        if not evo.user_owned_check(p[1]) then
          local ok, cur = pcall(function() return params:get(p[1]) end)
          if ok then
            local drift = (math.random()-0.5) * (p[3]-p[2]) * p[4] * inten * 2
            params:set(p[1], util.clamp(cur+drift, p[2], p[3]))
          end
        end
      end
      -- arrangement breathing: drop 1-2 tracks to low probability
      -- then bring them back — creates verse/chorus dynamics
      if math.random() < 0.06 * inten then
        -- pick 1-2 tracks to make sparse
        local num_drop = math.random(1, 2)
        local dropped = {}
        for _ = 1, num_drop do
          local dt = math.random(1, 4)
          local pp = "t" .. dt .. "_probability"
          if not evo.user_owned_check(pp) then
            local ok, cur = pcall(function() return params:get(pp) end)
            if ok and cur > 40 then
              params:set(pp, 15 + math.random() * 20) -- drop to 15-35%
              table.insert(dropped, {param = pp, restore = cur})
            end
          end
        end
        -- schedule restore after 4-16 beats
        if #dropped > 0 then
          clock.run(function()
            clock.sleep(clock.get_beat_sec() * (4 + math.random() * 12))
            for _, d in ipairs(dropped) do
              pcall(function() params:set(d.param, d.restore) end)
            end
          end)
        end
      end

      -- momentary mute (rarer, more dramatic)
      if math.random() < 0.03 * inten then
        local mt = math.random(1, 4)
        if not evo.user_owned_check("mute_" .. mt) then
          track_mute[mt] = true
          clock.run(function()
            clock.sleep(clock.get_beat_sec() * (2 + math.random() * 6))
            track_mute[mt] = false
          end)
        end
      end
      assistant_activity[2] = 1
      ::water_skip::
    end
  end)

  -- TURMERIC: warm color
  clock.run(function()
    while true do
      clock.sleep(4 + math.random() * 6)
      if not playing or assistant_intensity[3] < 0.01 or conductor_intensity_mult < 0.01 then goto turmeric_skip end
      local inten = assistant_intensity[3] * conductor_intensity_mult
      local picks = {
        {"t1_spread",0.15,0.6,0.02},{"t1_brightness",0.2,0.7,0.02},
        {"t1_gate",0.4,0.9,0.02},   -- MANTA gate: gentle range
        {"t2_gate",0.2,0.6,0.02},   -- ZKIT gate
        {"t3_gate",0.3,0.7,0.02},   -- TOROID gate
        {"t3_lfoRate",0.5,8,0.02},{"t3_lfoDepth",0.0,0.3,0.02},
        {"t4_pwm",0.15,0.85,0.02},{"t4_bits",8,16,0.02},
        {"t3_fmamt",0.0,0.4,0.02},{"t3_morph",0.1,0.7,0.02},
      }
      local p = picks[math.random(#picks)]
      if not evo.user_owned_check(p[1]) then
        local ok, cur = pcall(function() return params:get(p[1]) end)
        if ok then
          local drift = (math.random()-0.5) * (p[3]-p[2]) * p[4] * inten * 2
          params:set(p[1], util.clamp(cur+drift, p[2], p[3]))
        end
      end
      assistant_activity[3] = 1
      ::turmeric_skip::
    end
  end)
end

-- ======== BEZIER MODULATION ========

function apply_bezier_modulation()
  bez.update(1/15)
  local b1 = bez.get_raw("curve1")
  local b2 = bez.get_raw("curve2")
  local b3 = bez.get_raw("curve3")
  local b4 = bez.get_raw("curve4")
  local b5 = bez.get_raw("curve5")
  local lfo_val = bez.get_raw("lfo")
  -- 8 sources for 8 routes
  local sources = {
    b4,                        -- MNT.cut: slow sweeps
    b1,                        -- MNT.spd: gentle spectral drift
    b1,                        -- ZKT.cut: slow filter
    b2,                        -- ZKT.acc: medium accent
    b2,                        -- TRD.cut: medium filter
    b3 + lfo_val * 0.3,       -- TRD.mrp: morph (alive)
    b5,                        -- BZT.cut: fast
    (b4 + b2) * 0.5,          -- BZT.pwm: blended
  }

  for i, route in ipairs(MOD_ROUTES) do
    if mod_amounts[i] > 0.01 then
      local base = params:get(route.param)
      local raw = sources[i] * mod_amounts[i]
      mod_values[i] = raw
      local mod = raw * base * route.base_mult
      engine.set_param(route.track - 1, route.sc_param, util.clamp(base + mod, 30, 16000))
    else
      mod_values[i] = 0
    end
  end
end

-- ======== SEQUENCER ========

local function is_track_audible(t)
  if track_mute[t] then return false end
  local any_solo = false
  for i = 1, NUM_TRACKS do if track_solo[i] then any_solo = true; break end end
  if any_solo and not track_solo[t] then return false end
  return true
end

function trigger_note(track_idx)
  local t = tracks[track_idx]
  local step = t.steps[t.position]
  if not step or not step.on then return end
  if not is_track_audible(track_idx) then return end

  -- step probability
  local prob = step.prob or 100
  local track_prob = t.probability or 100
  local final_prob = (prob / 100) * (track_prob / 100)
  if math.random() > final_prob then return end

  -- apply p-locks (per-step param overrides)
  local restore_cutoff = nil
  if step.p_cutoff then
    restore_cutoff = t.cutoff
    engine.set_param(track_idx - 1, "cutoff", step.p_cutoff)
  end
  if step.p_morph and track_idx == 3 then
    engine.set_param(2, "morph", step.p_morph)
  end
  if step.p_accent and track_idx == 2 then
    engine.set_param(1, "accent", step.p_accent)
  end

  local freq = musicutil.note_num_to_freq(step.note)
  local amp = step.vel * t.level
  send_track_params(track_idx)
  engine.note_on(track_idx - 1, freq, amp)
  step_flash[track_idx][t.position] = 1

  -- MIDI out
  if midi_out_device and midi_out_ch > 0 then
    midi_out_device:note_on(step.note, math.floor(step.vel * 127), midi_out_ch)
  end

  -- OP-XY out (per-track channel)
  local opxy_ch = opxy_channels[track_idx]
  if opxy_device and opxy_ch > 0 then
    opxy_device:note_on(step.note, math.floor(step.vel * 127), opxy_ch)
    -- send filter CC1 for expression
    opxy_device:cc(1, math.floor((t.cutoff / 12000) * 127), opxy_ch)
  end

  clock.run(function()
    clock.sleep(clock.get_beat_sec() * t.gate * DIVISIONS[t.division][2])
    engine.note_off(track_idx - 1)
    if restore_cutoff then engine.set_param(track_idx - 1, "cutoff", restore_cutoff) end
    if midi_out_device and midi_out_ch > 0 then
      midi_out_device:note_off(step.note, 0, midi_out_ch)
    end
    if opxy_device and opxy_ch > 0 then
      opxy_device:note_off(step.note, 0, opxy_ch)
    end
  end)
end

local track_clocks = {}
local conductor_tick_count = 0

function start_sequencer()
  playing = true
  evo.save_home(tracks)  -- remember starting patterns for returns

  -- each track runs its own clock at its own division
  for t = 1, NUM_TRACKS do
    track_clocks[t] = clock.run(function()
      local swing_tick = 0
      while playing do
        local div = DIVISIONS[tracks[t].division][2]

        -- swing: delay even ticks
        swing_tick = swing_tick + 1
        if swing_tick % 2 == 0 and swing_amount > 0 then
          clock.sleep(clock.get_beat_sec() * div * swing_amount * 0.01 * 0.5)
        end

        clock.sync(div)
        tracks[t].position = (tracks[t].position % tracks[t].num_steps) + 1
        trigger_note(t)
      end
    end)
  end

  -- conductor clock (once per bar)
  track_clocks[5] = clock.run(function()
    while playing do
      clock.sync(1)
      robot.beat()
      if conductor_intensity_mult < 0.01 then goto skip_conductor end
      do
        local energy = explorer_on and song_engine.get_energy() or 0.3
        local profile = robot.profiles[robot_profile]
        -- scale conductor by user intensity multiplier
        local saved_ir = profile.intensity_range
        profile.intensity_range = {saved_ir[1] * conductor_intensity_mult,
                                    saved_ir[2] * conductor_intensity_mult}
        evo.conductor_tick(tracks, energy, profile)
        profile.intensity_range = saved_ir
      end
      ::skip_conductor::
    end
  end)
end

function stop_sequencer()
  playing = false
  for i = 1, 5 do
    if track_clocks[i] then clock.cancel(track_clocks[i]); track_clocks[i] = nil end
  end
  for i = 0, 3 do engine.note_off(i) end
  for t = 1, NUM_TRACKS do tracks[t].position = 0 end
end

-- ======== EXPLORER ========

local function start_explorer()
  if explorer_on then return end
  explorer_on = true
  local p = robot.profiles[robot_profile]
  song_engine.start(p and p.personality or 1)
end

local function stop_explorer()
  explorer_on = false
  song_engine.stop()
end

-- ======== ENCODERS ========

function enc(n, d)
  if n == 1 then
    current_page = util.clamp(current_page + d, 1, #PAGES)
    return
  end

  -- track that encoder was used during K3 hold
  if k3_held then k3_encoder_used = true end

  if current_page == 1 then -- SEQ
    if k3_held then
      if n == 2 then
        selected_track = util.clamp(selected_track + d, 1, NUM_TRACKS)
        selected_step = util.clamp(selected_step, 1, tracks[selected_track].num_steps)
        flash(TRACK_NAMES[selected_track])
      elseif n == 3 then
        -- ALT+E3: density — turn right to fill, left to thin
        local t = tracks[selected_track]
        local ns = t.num_steps
        local sc = tracks._scale_notes or scale_notes
        if d > 0 then
          -- fill: activate a random inactive step
          local inactive = {}
          for s = 1, ns do if not t.steps[s].on then table.insert(inactive, s) end end
          if #inactive > 0 then
            local idx = inactive[math.random(#inactive)]
            t.steps[idx].on = true
            t.steps[idx].note = #sc > 0 and sc[math.random(#sc)] or 60
            t.steps[idx].vel = 0.5 + math.random() * 0.4
          end
          -- count active
          local count = 0
          for s = 1, ns do if t.steps[s].on then count = count + 1 end end
          flash(count .. "/" .. ns)
        else
          -- thin: deactivate a random active step (keep at least 1)
          local active = {}
          for s = 1, ns do if t.steps[s].on then table.insert(active, s) end end
          if #active > 1 then
            local idx = active[math.random(#active)]
            t.steps[idx].on = false
          end
          local count = 0
          for s = 1, ns do if t.steps[s].on then count = count + 1 end end
          flash(count .. "/" .. ns)
        end
      end
    else
      if n == 2 then
        selected_step = util.clamp(selected_step + d, 1, tracks[selected_track].num_steps)
      elseif n == 3 then
        local step = tracks[selected_track].steps[selected_step]
        step.note = util.clamp(step.note + d, 24, 96)
        step.note = musicutil.snap_note_to_array(step.note, scale_notes)
        flash(musicutil.note_num_to_name(step.note, true))
      end
    end

  elseif current_page == 2 then -- VOICE
    local pre = "t" .. selected_track .. "_"
    if k3_held then
      if n == 2 then
        -- ALT+E2: cycle track
        selected_track = util.clamp(selected_track + d, 1, NUM_TRACKS)
        flash(TRACK_NAMES[selected_track])
      elseif n == 3 then
        -- ALT+E3: scale root + type combined (fine: root, coarse: type)
        root_note = util.clamp(root_note + d, 24, 72)
        params:set("root_note", root_note)
        flash(musicutil.note_num_to_name(root_note, true) .. " " .. SCALE_SHORT[scale_type])
      end
    else
      if n == 2 then
        local t = tracks[selected_track]
        user_set(pre .. "cutoff", util.clamp(t.cutoff * (1 + d * 0.03), 30, 12000))
      elseif n == 3 then
        if selected_track == 1 then user_delta(pre .. "spread", d * 0.02)
        elseif selected_track == 2 then user_delta(pre .. "accent", d * 0.02)
        elseif selected_track == 3 then user_delta(pre .. "morph", d * 0.02)
        elseif selected_track == 4 then
          local eng = (tracks[4].engine_sel + d) % 4
          if eng < 0 then eng = 3 end
          user_set(pre .. "engine", eng + 1)
          flash(({"PLS","FM","WAV","NOI"})[eng + 1])
        end
      end
    end

  elseif current_page == 3 then -- MIX
    if k3_held then
      -- ALT: E2=pan, E3=swing
      if n == 2 then
        local t = tracks[selected_track]
        t.pan = util.clamp((t.pan or 0) + d * 0.05, -1, 1)
        engine.set_param(selected_track - 1, "pan", t.pan)
        evo.user_touched("pan_" .. selected_track)
        local side = t.pan < -0.1 and "L" or (t.pan > 0.1 and "R" or "C")
        flash(TRACK_SHORT[selected_track] .. " " .. side .. string.format("%.0f", math.abs(t.pan) * 100))
      elseif n == 3 then
        swing_amount = util.clamp(swing_amount + d * 2, 0, 80)
        params:set("swing", swing_amount)
        flash("sw:" .. swing_amount)
      end
    else
      -- E2=track level, E3=reverb mix
      if n == 2 then
        local pre = "t" .. selected_track .. "_level"
        local cur = tracks[selected_track].level
        local new_val = util.clamp(cur + d * 0.05, 0, 1)
        tracks[selected_track].level = new_val
        params:set(pre, new_val)
        evo.user_touched(pre)  -- protect from WATER for 8 seconds
        flash(TRACK_SHORT[selected_track] .. " " .. string.format("%.0f%%", new_val * 100))
      elseif n == 3 then
        local cur = params:get("reverb_mix")
        local new_val = util.clamp(cur + d * 0.05, 0, 1)
        params:set("reverb_mix", new_val)
        evo.user_touched("reverb_mix")
        flash("rev:" .. string.format("%.0f%%", new_val * 100))
      end
    end

  elseif current_page == 4 then -- MOD
    if k3_held then
      if n == 2 then user_delta("bez_tension", d * 0.03)
      elseif n == 3 then
        local f = params:get("lfo_freq")
        user_set("lfo_freq", util.clamp(f * (1 + d * 0.05), 0.01, 10))
      end
    else
      if n == 2 then
        selected_route = util.clamp(selected_route + d, 1, #MOD_ROUTES)
        flash(MOD_ROUTES[selected_route].name)
      elseif n == 3 then
        user_delta("mod_" .. selected_route, d * 0.03)
        flash(string.format("%.0f%%", mod_amounts[selected_route] * 100))
      end
    end

  elseif current_page == 5 then -- ASSIST
    if n == 2 then
      selected_assistant = util.clamp(selected_assistant + d, 1, 3)
      flash(ASSISTANT_NAMES[selected_assistant])
    elseif n == 3 then
      assistant_intensity[selected_assistant] = util.clamp(
        assistant_intensity[selected_assistant] + d * 0.03, 0, 1)
      flash(string.format("%.0f%%", assistant_intensity[selected_assistant] * 100))
    end

  elseif current_page == 6 then -- AUTO
    if k3_held then
      if n == 2 then user_delta("xmod_speed", d * 0.02)
      elseif n == 3 then user_delta("reverb_damp", d * 0.02) end
    else
      if n == 2 then
        robot_profile = util.clamp(robot_profile + d, 1, #robot.profiles)
        -- param action handles explorer restart, don't do it twice
        params:set("robot_profile", robot_profile)
        flash(robot.profiles[robot_profile].name)
      elseif n == 3 then
        -- conductor intensity multiplier
        conductor_intensity_mult = util.clamp(conductor_intensity_mult + d * 0.05, 0, 2)
        flash("INT:" .. string.format("%.0f%%", conductor_intensity_mult * 100))
      end
    end
  end
end

-- ======== KEYS ========

function key(n, z)
  if n == 3 then
    if z == 1 then
      k3_held = true
      k3_press_time = os.clock()
      k3_encoder_used = false
    else
      k3_held = false
      if os.clock() - k3_press_time < 0.3 and not k3_encoder_used then
        if current_page == 1 then
          -- generate euclidean pattern with random pulse count
          local t = tracks[selected_track]
          local ns = t.num_steps
          local pulses = math.random(math.floor(ns * 0.2), math.floor(ns * 0.7))
          local offset = math.random(0, ns - 1)
          local euc = harmony.euclidean(ns, pulses, offset)
          local sc = tracks._scale_notes or scale_notes
          for s = 1, ns do
            t.steps[s].on = euc[s] or false
            if t.steps[s].on and #sc > 0 then
              t.steps[s].note = sc[math.random(#sc)]
              t.steps[s].vel = 0.4 + math.random() * 0.5
            end
          end
          flash("E(" .. pulses .. "," .. ns .. ")")
        elseif current_page == 2 then
          -- cycle timbral presets
          current_timbre = (current_timbre % #TIMBRES) + 1
          apply_timbre(current_timbre)
          flash(TIMBRES[current_timbre].name)
        elseif current_page == 3 then
          selected_track = (selected_track % NUM_TRACKS) + 1
          selected_step = util.clamp(selected_step, 1, tracks[selected_track].num_steps)
          flash(TRACK_NAMES[selected_track])
        elseif current_page == 4 then
          bez.randomize()
          local ri = math.random(1, #MOD_ROUTES)
          mod_amounts[ri] = util.clamp(mod_amounts[ri] + 0.2, 0, 1)
          params:set("mod_" .. ri, mod_amounts[ri])
          flash("BURST")
        elseif current_page == 5 then
          selected_assistant = (selected_assistant % 3) + 1
          flash(ASSISTANT_NAMES[selected_assistant])
        elseif current_page == 6 then
          if explorer_on then stop_explorer() else start_explorer() end
          flash(explorer_on and "EXPLORE" or "MANUAL")
        end
      end
    end
  elseif n == 2 and z == 1 then
    if playing then stop_sequencer() else start_sequencer() end
  end
end

-- ======== GRID ========

function grid_key(x, y, z)
  if y >= 1 and y <= 4 then
    -- step toggles
    if z == 1 and x <= tracks[y].num_steps then
      tracks[y].steps[x].on = not tracks[y].steps[x].on
      selected_track = y; selected_step = x
      held_steps[y..","..x] = true
    elseif z == 0 then
      held_steps[y..","..x] = nil
    end
  elseif y == 5 and z == 1 and x <= 4 then
    -- mute toggles
    track_mute[x] = not track_mute[x]
    flash(TRACK_SHORT[x] .. (track_mute[x] and " MUTE" or " ON"))
  elseif y == 6 and z == 1 and x <= 4 then
    -- solo toggles
    track_solo[x] = not track_solo[x]
    flash(TRACK_SHORT[x] .. (track_solo[x] and " SOLO" or " OFF"))
  elseif y == 7 and z == 1 and x <= 8 then
    -- save snapshot (row 7)
    save_snapshot(x)
    flash("SAVE " .. x)
  elseif y == 8 and z == 1 and x <= 8 then
    -- load snapshot (row 8)
    if load_snapshot(x) then flash("LOAD " .. x)
    else flash("EMPTY") end
  elseif y >= 5 and y <= 8 and z == 1 and x > 8 then
    -- note keyboard (right half of bottom rows)
    local octave = 5 - (y - 5)
    local target = scale_notes[1] + (octave - 1) * 12 + (x - 9) * 2
    target = musicutil.snap_note_to_array(util.clamp(target, 24, 96), scale_notes)
    local assigned = false
    for kid, _ in pairs(held_steps) do
      local ty, tx = kid:match("(%d+),(%d+)")
      ty = tonumber(ty); tx = tonumber(tx)
      if ty and tx then
        tracks[ty].steps[tx].note = target
        tracks[ty].steps[tx].on = true
        assigned = true
      end
    end
    if not assigned then
      send_track_params(selected_track)
      engine.note_on(selected_track - 1, musicutil.note_num_to_freq(target), 0.7)
      clock.run(function() clock.sleep(0.3); engine.note_off(selected_track - 1) end)
    end
  end
end

function grid_redraw()
  g:all(0)
  -- rows 1-4: steps
  for t = 1, 4 do
    local ns = tracks[t].num_steps
    local tpos = tracks[t].position
    for s = 1, 16 do
      local br = 0
      if s <= ns then
        local step = tracks[t].steps[s]
        if step.on then br = 5 end
        if s == tpos and playing then br = step.on and 15 or 4 end
        if t == selected_track and s == selected_step then br = math.max(br, 8) end
      end
      g:led(s, t, br)
    end
  end
  -- row 5: mutes (cols 1-4)
  for t = 1, 4 do g:led(t, 5, track_mute[t] and 15 or 3) end
  -- row 6: solos (cols 1-4)
  for t = 1, 4 do g:led(t, 6, track_solo[t] and 15 or 3) end
  -- rows 7-8: snapshots (cols 1-8)
  for x = 1, 8 do
    g:led(x, 7, snapshots[x] and 8 or 2)  -- save row
    g:led(x, 8, snapshots[x] and 6 or 1)  -- load row
  end
  -- rows 5-8 cols 9-16: note keyboard
  for y = 5, 8 do
    for x = 9, 16 do g:led(x, y, ((x-9) % 5 == 0) and 4 or 2) end
  end
  g:refresh()
end

-- ======== SCREEN DRAWING ========

local function draw_header(name)
  screen.level(15); screen.font_size(8)
  screen.move(2, 8); screen.text(name)
  for i = 1, #PAGES do
    screen.level(i == current_page and 15 or 3)
    screen.rect(44 + (i-1)*5, 3, 3, 4); screen.fill()
  end
  if k3_held then screen.level(15); screen.move(98, 8); screen.text("ALT") end
  if param_flash > 0.2 then
    screen.level(math.floor(param_flash * 12))
    screen.move(126, 8); screen.text_right(param_flash_name)
  end
  if explorer_on and evo.user_override_count() > 0 then
    screen.level(12); screen.rect(126, 1, 2, 2); screen.fill()
  end
end

local function draw_step_bar()
  if not playing then
    screen.level(3); screen.move(2, 63); screen.text("K2:play")
    if explorer_on then screen.level(12); screen.move(70, 63); screen.text("EXPLORE") end
    return
  end
  local st = tracks[selected_track]
  for i = 1, st.num_steps do
    local x = 2 + (i-1) * (122 / st.num_steps)
    local step = st.steps[i]
    local w = math.max(2, math.floor(122 / st.num_steps) - 1)
    local fl = step_flash[selected_track][i] or 0
    if i == st.position and playing then screen.level(15)
    elseif fl > 0.2 then screen.level(math.floor(4 + fl * 8))
    elseif step.on then screen.level(4)
    else screen.level(1) end
    screen.rect(x, 60, w, 3); screen.fill()
  end
end

-- PAGE 1: SEQ
local function draw_seq_page()
  draw_header(TRACK_NAMES[selected_track])

  for t = 1, NUM_TRACKS do
    local y0 = 10 + (t-1) * 12
    local is_sel = (t == selected_track)
    local ns = tracks[t].num_steps
    local tpos = tracks[t].position
    local muted = not is_track_audible(t)

    screen.level(is_sel and 6 or 2)
    screen.move(ns * 8, y0); screen.line(ns * 8, y0 + 10); screen.stroke()

    for s = 1, 16 do
      local x = (s-1) * 8
      local stp = tracks[t].steps[s]
      local in_range = (s <= ns)
      local is_play = (s == tpos and playing and in_range)
      local is_cur = (is_sel and s == selected_step)
      local fl = step_flash[t][s] or 0

      if in_range then
        local max_h = 10
        local h = stp.on and math.max(3, math.floor(stp.vel * max_h)) or max_h
        local y_off = max_h - h

        local lvl
        if muted then lvl = stp.on and 2 or 0
        elseif is_play and stp.on then lvl = 15
        elseif is_play then lvl = is_sel and 7 or 4
        elseif fl > 0.2 then lvl = math.floor(5 + fl * 8)
        elseif stp.on then lvl = is_sel and 10 or 5
        else lvl = is_sel and 3 or 1 end

        if lvl > 0 then
          screen.level(lvl)
          if stp.on or is_play then
            screen.rect(x + 1, y0 + y_off, 6, h); screen.fill()
          else
            screen.rect(x + 1, y0, 6, max_h); screen.stroke()
          end
        end
      end

      if is_cur and in_range then
        screen.level(15); screen.rect(x, y0 - 1, 8, 12); screen.stroke()
      end
    end
  end

  local step = tracks[selected_track].steps[selected_step]
  local nn = musicutil.note_num_to_name(step.note, true)
  screen.level(10); screen.move(0, 63)
  screen.text(TRACK_SHORT[selected_track] .. " " .. selected_step .. "/" .. tracks[selected_track].num_steps .. ":" .. nn)
  local prob = step.prob or 100
  if prob < 100 then
    screen.level(6); screen.move(72, 63); screen.text("p" .. prob .. "%")
  end
  screen.level(playing and 15 or 3); screen.move(124, 63); screen.text_right(playing and ">" or "||")
end

-- PAGE 2: VOICE
local function draw_voice_page()
  draw_header("VOICE")
  local t = tracks[selected_track]

  screen.level(15); screen.font_size(16)
  screen.move(64, 24); screen.text_center(TRACK_NAMES[selected_track])
  screen.font_size(8)

  -- scale + timbre display
  screen.level(6); screen.move(2, 33)
  screen.text(musicutil.note_num_to_name(root_note, true) .. " " .. SCALE_SHORT[scale_type])
  if current_timbre > 0 then
    screen.level(15); screen.font_size(8)
    screen.move(126, 18)
    screen.text_right(TIMBRES[current_timbre].name)
    screen.level(5)
    screen.move(126, 26)
    screen.text_right(TIMBRES[current_timbre].desc)
  end

  -- division display
  screen.move(90, 33); screen.text(DIVISIONS[t.division][1])

  -- filter curve
  local cut_norm = math.log(math.max(t.cutoff,30) / 30) / math.log(12000 / 30)
  local res_h = t.res * 12
  local cx = 4 + cut_norm * 120
  screen.level(6)
  screen.move(4, 40); screen.line(math.max(4, cx-8), 40)
  screen.line(cx, 40 - res_h)
  screen.line(math.min(124, cx+20), 46); screen.line(124, 48)
  screen.stroke()
  screen.level(12); screen.move(cx, 48); screen.line(cx, 50); screen.stroke()

  screen.level(k3_held and 5 or 10); screen.move(2, 56)
  screen.text("cut:" .. string.format("%.0f", t.cutoff))
  screen.level(k3_held and 10 or 5); screen.move(2, 63)
  screen.text("res:" .. string.format("%.2f", t.res))

  screen.level(k3_held and 5 or 10); screen.move(68, 56)
  if selected_track == 1 then screen.text("sprd:" .. string.format("%.2f", t.spread or 0))
  elseif selected_track == 2 then screen.text("acnt:" .. string.format("%.2f", t.accent or 0))
  elseif selected_track == 3 then screen.text("mrph:" .. string.format("%.2f", t.morph or 0))
  elseif selected_track == 4 then
    screen.text("eng:" .. ({"PLS","FM","WAV","NOI"})[(t.engine_sel or 0) + 1])
  end
end

-- PAGE 3: MIX
local function draw_mix_page()
  draw_header("MIX")

  local ch_w = 22; local ch_h = 46; local gap = 4; local start_x = 2; local y_top = 11

  for t = 1, 4 do
    local x = start_x + (t-1) * (ch_w + gap)
    local is_sel = (t == selected_track)
    local level = tracks[t].level
    local fill_h = math.floor(level * ch_h)
    local muted = not is_track_audible(t)

    screen.level(1); screen.rect(x, y_top, ch_w, ch_h); screen.fill()
    screen.level(3); screen.move(x+ch_w/2, y_top+2); screen.line(x+ch_w/2, y_top+ch_h-2); screen.stroke()

    for row = 0, fill_h - 1 do
      local fy = y_top + ch_h - 1 - row
      local grad = math.floor(3 + (row / ch_h) * 9)
      if is_sel then grad = grad + 3 end
      if muted then grad = math.floor(grad * 0.3) end
      screen.level(math.min(grad, 15))
      screen.rect(x+3, fy, ch_w-6, 1); screen.fill()
    end

    local knob_y = y_top + ch_h - fill_h
    screen.level(is_sel and 15 or 10)
    screen.rect(x+1, knob_y-1, ch_w-2, 3); screen.fill()

    -- mute indicator
    if muted then
      screen.level(8); screen.move(x+ch_w/2, y_top+ch_h/2+3); screen.text_center("M")
    end

    screen.level(is_sel and 15 or 6)
    screen.move(x+ch_w/2, y_top+ch_h+7); screen.text_center(TRACK_SHORT[t])

    -- pan indicator (inside bottom of fader strip)
    local pan_val = tracks[t].pan or 0
    local pan_x = x + ch_w/2 + pan_val * (ch_w/2 - 3)
    screen.level(12)
    screen.move(x+2, y_top+ch_h-2); screen.line(x+ch_w-2, y_top+ch_h-2); screen.stroke()
    screen.level(15)
    screen.rect(pan_x-1, y_top+ch_h-3, 3, 3); screen.fill()
  end

  -- reverb
  local mx = start_x + 4 * (ch_w + gap)
  local rev = params:get("reverb_mix")
  local rev_h = math.floor(rev * ch_h)
  screen.level(1); screen.rect(mx, y_top, 18, ch_h); screen.fill()
  screen.level(3); screen.move(mx+9, y_top+2); screen.line(mx+9, y_top+ch_h-2); screen.stroke()
  for row = 0, rev_h - 1 do
    screen.level(math.floor(3 + (row / ch_h) * 8))
    screen.rect(mx+4, y_top+ch_h-1-row, 10, 1); screen.fill()
  end
  screen.level(12); screen.rect(mx+2, y_top+ch_h-rev_h-1, 14, 3); screen.fill()
  screen.level(8); screen.move(mx+9, y_top+ch_h+7); screen.text_center("REV")

  -- comp/swing indicators bottom
  screen.level(4); screen.move(0, y_top+ch_h+13)
  local comp_t = params:get("comp_thresh")
  local comp_m = params:get("comp_makeup")
  screen.text("C:" .. string.format("%.0f", comp_t*100) .. "/" .. string.format("%.1f", comp_m))
  if swing_amount > 0 then
    screen.move(mx, y_top+ch_h+13); screen.text("sw" .. swing_amount)
  end
end

-- PAGE 4: MOD
local function draw_mod_page()
  draw_header("MOD")

  local curves = {"curve1", "curve2", "curve3"}
  for ci, cname in ipairs(curves) do
    local history, idx = bez.get_history(cname)
    local y_center = 14 + (ci-1) * 8
    screen.level(4 + ci * 3)
    for i = 1, 126 do
      local hi = ((idx - 1 + math.floor(i * 0.5)) % 64) + 1
      local val = history[hi] or 0
      local py = y_center - val * 4
      if i == 1 then screen.move(i, py) else screen.line(i, py) end
    end
    screen.stroke()
  end

  for i, route in ipairs(MOD_ROUTES) do
    local y = 34 + (i-1) * 5
    local is_sel = (i == selected_route)
    local amt = mod_amounts[i]
    local mv = mod_values[i] or 0

    screen.level(is_sel and 15 or 4); screen.move(0, y+4); screen.text(route.name:sub(1,7))
    local bar_x = 42; local bar_max = 84
    screen.level(2); screen.rect(bar_x, y, bar_max, 4); screen.stroke()
    if amt > 0.01 then
      screen.level(is_sel and 8 or 4); screen.rect(bar_x, y, math.floor(amt*bar_max), 4); screen.fill()
    end
    if math.abs(mv) > 0.01 then
      local center = bar_x + math.floor(bar_max * 0.5)
      local pw = math.floor(math.abs(mv) * bar_max * 0.5)
      screen.level(math.floor(6 + math.abs(mv) * 9))
      screen.rect(center, y, pw * (mv > 0 and 1 or -1), 4); screen.fill()
    end
  end
end

-- PAGE 5: ASSIST
local function draw_assist_page()
  draw_header("ASSIST")

  local names = {"LSD", "WATER", "TURMERIC"}
  local descs = {"perception", "space + levels", "warm color"}
  local colors = {15, 10, 7}

  for a = 1, 3 do
    local y = 12 + (a-1) * 17
    local is_sel = (a == selected_assistant)
    local inten = assistant_intensity[a]
    local act = assistant_activity[a]

    screen.level(is_sel and 15 or 6)
    screen.font_size(is_sel and 16 or 8)
    screen.move(2, y + (is_sel and 12 or 8)); screen.text(names[a])
    screen.font_size(8)

    screen.level(4); screen.move(is_sel and 68 or 56, y+5); screen.text(descs[a])

    local bar_x = is_sel and 68 or 56; local bar_w = 58
    screen.level(2); screen.rect(bar_x, y+8, bar_w, 5); screen.stroke()
    screen.level(is_sel and 10 or 5)
    screen.rect(bar_x, y+8, math.floor(inten*bar_w), 5); screen.fill()

    if act > 0.1 then
      screen.level(math.floor(act * colors[a]))
      screen.rect(bar_x + math.floor(inten*bar_w) - 3, y+7, 6, 7); screen.fill()
    end

    screen.level(is_sel and 12 or 4)
    screen.move(bar_x + bar_w + 2, y+12); screen.text(string.format("%.0f", inten*100))
  end

  draw_step_bar()
end

-- PAGE 6: AUTO
local function draw_auto_page()
  draw_header("AUTO")

  local p = robot.profiles[robot_profile]
  if not p then p = robot.profiles[1] end
  local energy = explorer_on and song_engine.get_energy() or 0.3

  robot.draw(robot_profile, 22, 36, energy, explorer_on)

  screen.level(15); screen.font_size(16)
  screen.move(48, 22); screen.text(p.name)
  screen.font_size(8)

  screen.level(6); screen.move(48, 32); screen.text(p.desc)

  -- conductor intensity with label
  local int_pct = conductor_intensity_mult * 100
  local int_label = "OFF"
  if int_pct > 150 then int_label = "CHAOS"
  elseif int_pct > 90 then int_label = "FULL"
  elseif int_pct > 50 then int_label = "MODERATE"
  elseif int_pct > 10 then int_label = "GENTLE"
  elseif int_pct > 0 then int_label = "MINIMAL" end
  screen.level(conductor_intensity_mult < 0.01 and 4 or 10); screen.move(48, 42)
  screen.text(string.format("%.0f%%", int_pct) .. " " .. int_label)

  if explorer_on then
    local section = song_engine.get_section_name()
    local progress = song_engine.get_progress()

    screen.level(12); screen.move(90, 42); screen.text(section)

    screen.level(3); screen.rect(48, 46, 78, 4); screen.stroke()
    screen.level(10); screen.rect(49, 47, progress * 76, 2); screen.fill()

    screen.level(math.floor(energy * 15))
    screen.rect(48, 53, math.floor(energy * 50), 3); screen.fill()
  else
    screen.level(4); screen.move(48, 52); screen.text("K3: explore")
  end

  draw_step_bar()
end

-- ======== REDRAW ========

function redraw()
  screen.clear(); screen.aa(0); screen.font_face(1); screen.font_size(8)

  if current_page == 1 then draw_seq_page()
  elseif current_page == 2 then draw_voice_page()
  elseif current_page == 3 then draw_mix_page()
  elseif current_page == 4 then draw_mod_page()
  elseif current_page == 5 then draw_assist_page()
  elseif current_page == 6 then draw_auto_page()
  end

  screen.update()
end

-- ======== CLEANUP ========

function cleanup()
  stop_sequencer()
  if explorer_on then stop_explorer() end
end
