-- slap
-- 4-part autonomous synth sequencer
-- inspired by Fred's Lab:
-- MANTA / ZKIT / TOROID / BZZT
--
-- E1: page select
-- E2/E3: page params (per page)
-- K2: play/stop
-- K3: hold=ALT, tap=page action
--
-- pages: SEQ / VOICE / MOD / AUTO
--
-- v2.0 @jamminstein

engine.name = "Slap"

local musicutil = require "musicutil"
local util = require "util"
local bez = include("lib/bezier_mod")
local evo = include("lib/evolution")
local personalities = include("lib/personalities")
local song_engine = include("lib/song_engine")
local robot = include("lib/robot")

-- ======== CONSTANTS ========

local PAGES = {"SEQ", "VOICE", "MIX", "MOD", "AUTO"}
local NUM_TRACKS = 4
local MAX_STEPS = 24
local TRACK_NAMES = {"MANTA", "ZKIT", "TOROID", "BZZT"}
local TRACK_SHORT = {"MNT", "ZKT", "TRD", "BZT"}

-- bezier modulation routing targets
local MOD_ROUTES = {
  {name = "MNT.cut", param = "t1_cutoff", sc_param = "cutoff", track = 1, base_mult = 0.5},
  {name = "ZKT.cut", param = "t2_cutoff", sc_param = "cutoff", track = 2, base_mult = 0.5},
  {name = "TRD.cut", param = "t3_cutoff", sc_param = "cutoff", track = 3, base_mult = 0.5},
  {name = "TRD.mrp", param = "t3_morph",  sc_param = "morph",  track = 3, base_mult = 0.3},
  {name = "BZT.cut", param = "t4_cutoff", sc_param = "cutoff", track = 4, base_mult = 0.5},
  {name = "BZT.pwm", param = "t4_pwm",    sc_param = "pwm",    track = 4, base_mult = 0.3},
}
local mod_amounts = {0, 0, 0, 0, 0, 0}
local mod_values = {0, 0, 0, 0, 0, 0}  -- live modulation output (-1 to 1)
local selected_route = 1

-- ======== STATE ========

local current_page = 1
local playing = false
local selected_track = 1
local selected_step = 1
local k3_held = false
local k3_press_time = 0
local seq_clock = nil

-- explorer
local explorer_on = false
local robot_profile = 1

-- scale
local scale_notes = {}

-- tracks
local tracks = {}

-- grid
local g = grid.connect()
local held_steps = {}

-- visual feedback
local param_flash = 0
local param_flash_name = ""
local step_flash = {}  -- per-track, per-step trigger flash
for t = 1, NUM_TRACKS do
  step_flash[t] = {}
  for i = 1, MAX_STEPS do step_flash[t][i] = 0 end
end

-- ======== SCALE ========

function build_scale()
  scale_notes = musicutil.generate_scale(26, "minor pentatonic", 7)
  tracks._scale_notes = scale_notes
end

-- ======== TRACK INIT ========

function init_tracks()
  for i = 1, NUM_TRACKS do
    tracks[i] = {
      steps = {},
      num_steps = 16,  -- default, overridden below
      position = 0,    -- per-track playhead
      cutoff = 2000, res = 0.3, gate = 0.7, level = 1.0,
    }
    for s = 1, MAX_STEPS do
      tracks[i].steps[s] = {on = false, note = 60, vel = 0.8}
    end
  end

  -- MANTA: 12-step pads (3/4 against 4/4)
  local m = tracks[1]
  m.num_steps = 12
  m.cutoff = 3500; m.res = 0.15; m.gate = 0.95
  m.spread = 0.4; m.brightness = 0.6
  local m_pat = {{1,50,0.5},{4,57,0.45},{7,53,0.5},{10,55,0.4}}
  for _, p in ipairs(m_pat) do m.steps[p[1]] = {on=true, note=p[2], vel=p[3]} end

  -- ZKIT: 16-step acid bass (standard 4/4)
  local z = tracks[2]
  z.num_steps = 16
  z.cutoff = 500; z.res = 0.75; z.gate = 0.45; z.accent = 0.85
  local z_pat = {{1,38,1.0},{4,38,0.7},{6,41,0.9},{8,43,0.6},{9,45,1.0},{12,45,0.5},{14,43,0.8},{16,41,0.6}}
  for _, p in ipairs(z_pat) do z.steps[p[1]] = {on=true, note=p[2], vel=p[3]} end

  -- TOROID: 14-step melody (7/8 feel)
  local t = tracks[3]
  t.num_steps = 14
  t.cutoff = 4500; t.res = 0.3; t.gate = 0.55
  t.morph = 0.35; t.fmamt = 0.25; t.lfoRate = 3; t.lfoDepth = 0.15
  local t_pat = {{1,62,0.7},{2,65,0.6},{3,69,0.7},{5,74,0.8},{7,69,0.6},{9,65,0.7},{11,62,0.5},{13,60,0.6},{14,62,0.5}}
  for _, p in ipairs(t_pat) do t.steps[p[1]] = {on=true, note=p[2], vel=p[3]} end

  -- BZZT: 10-step percussion (5/8 feel)
  local b = tracks[4]
  b.num_steps = 10
  b.cutoff = 7000; b.res = 0.15; b.gate = 0.15
  b.engine_sel = 0; b.pwm = 0.5; b.bits = 10
  local b_pat = {{1,36,1.0},{3,84,0.5},{5,36,0.8},{7,84,0.45},{9,36,1.0},{10,60,0.3}}
  for _, p in ipairs(b_pat) do b.steps[p[1]] = {on=true, note=p[2], vel=p[3]} end

  tracks._scale_notes = scale_notes
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

  params:add_control("reverb_mix", "reverb mix",
    controlspec.new(0, 1, 'lin', 0, 0.3))
  params:set_action("reverb_mix", function(v) engine.reverb_mix(v) end)

  params:add_control("reverb_room", "reverb room",
    controlspec.new(0, 1, 'lin', 0, 0.7))
  params:set_action("reverb_room", function(v) engine.reverb_room(v) end)

  params:add_control("reverb_damp", "reverb damp",
    controlspec.new(0, 1, 'lin', 0, 0.5))
  params:set_action("reverb_damp", function(v) engine.reverb_damp(v) end)

  -- bezier mod
  params:add_separator("MODULATION")
  params:add_control("bez_speed", "bez speed",
    controlspec.new(0.01, 3, 'exp', 0, 0.15))
  params:set_action("bez_speed", function(v)
    bez.set_speed("curve1", v)
    bez.set_speed("curve2", v * 2.3)
    bez.set_speed("curve3", v * 4.7)
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
  params:set_action("robot_profile", function(v) robot_profile = v end)

  -- per-track params
  for i = 1, NUM_TRACKS do
    local t = tracks[i]
    local pre = "t" .. i .. "_"
    params:add_separator(TRACK_NAMES[i])

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

  for i = 1, NUM_TRACKS do send_track_params(i) end
  params:set("clock_tempo", 110)

  g.key = grid_key

  -- main loop: screen + modulation at 15fps
  clock.run(function()
    while true do
      clock.sleep(1/15)
      apply_bezier_modulation()
      robot.update(1/15)
      -- decay flashes
      param_flash = param_flash * 0.8
      for t = 1, NUM_TRACKS do
        for i = 1, MAX_STEPS do step_flash[t][i] = step_flash[t][i] * 0.7 end
      end
      redraw()
      grid_redraw()
    end
  end)
end

-- ======== BEZIER MODULATION ========

function apply_bezier_modulation()
  bez.update(1/15)
  local b1 = bez.get_raw("curve1")
  local b2 = bez.get_raw("curve2")
  local b3 = bez.get_raw("curve3")
  local lfo_val = bez.get_raw("lfo")
  local sources = {b1, b2, b3, lfo_val, (b1+lfo_val)*0.5, (b2+b3)*0.5}

  for i, route in ipairs(MOD_ROUTES) do
    if mod_amounts[i] > 0.01 then
      local base = params:get(route.param)
      local raw = sources[i] * mod_amounts[i]
      mod_values[i] = raw  -- store for screen
      local mod = raw * base * route.base_mult
      engine.set_param(route.track - 1, route.sc_param, util.clamp(base + mod, 30, 16000))
    else
      mod_values[i] = 0
    end
  end
end

-- ======== SEQUENCER ========

function trigger_note(track_idx)
  local t = tracks[track_idx]
  local step = t.steps[t.position]
  if step and step.on then
    local freq = musicutil.note_num_to_freq(step.note)
    local amp = step.vel * t.level
    send_track_params(track_idx)
    engine.note_on(track_idx - 1, freq, amp)
    step_flash[track_idx][t.position] = 1
    clock.run(function()
      clock.sleep(clock.get_beat_sec() * t.gate * 0.25)
      engine.note_off(track_idx - 1)
    end)
  end
end

local conductor_tick_count = 0

function start_sequencer()
  playing = true
  seq_clock = clock.run(function()
    while playing do
      clock.sync(1/4)
      robot.beat()
      -- each track advances independently through its own length
      for t = 1, NUM_TRACKS do
        tracks[t].position = (tracks[t].position % tracks[t].num_steps) + 1
        trigger_note(t)
      end
      -- conductor: fires every 4 ticks (once per bar)
      conductor_tick_count = conductor_tick_count + 1
      if conductor_tick_count % 4 == 0 then
        local energy = explorer_on and song_engine.get_energy() or 0.3
        local profile = robot.profiles[robot_profile]
        evo.conductor_tick(tracks, energy, profile)
      end
    end
  end)
end

function stop_sequencer()
  playing = false
  if seq_clock then clock.cancel(seq_clock); seq_clock = nil end
  for i = 0, 3 do engine.note_off(i) end
  for t = 1, NUM_TRACKS do tracks[t].position = 0 end
  conductor_tick_count = 0
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
-- SEQ:   E2=step       E3=note       ALT+E2=track      ALT+E3=velocity
-- VOICE: E2=cutoff     E3=voice-param ALT+E2=res        ALT+E3=voice-param2
-- MOD:   E2=route sel  E3=amount     ALT+E2=bez speed   ALT+E3=tension
-- AUTO:  E2=profile    E3=reverb     ALT+E2=xmod        ALT+E3=lfo freq

function enc(n, d)
  if n == 1 then
    current_page = util.clamp(current_page + d, 1, #PAGES)
    return
  end

  if current_page == 1 then -- SEQ
    if k3_held then
      if n == 2 then
        selected_track = util.clamp(selected_track + d, 1, NUM_TRACKS)
        selected_step = util.clamp(selected_step, 1, tracks[selected_track].num_steps)
        flash(TRACK_NAMES[selected_track])
      elseif n == 3 then
        local step = tracks[selected_track].steps[selected_step]
        step.vel = util.clamp(step.vel + d * 0.05, 0.1, 1.0)
        flash("vel:" .. string.format("%.0f", step.vel * 100))
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
      -- ALT: E2=resonance, E3=voice-specific param 2
      if n == 2 then
        user_delta(pre .. "res", d * 0.02)
      elseif n == 3 then
        if selected_track == 1 then user_delta(pre .. "brightness", d * 0.02)
        elseif selected_track == 2 then user_delta(pre .. "gate", d * 0.02)
        elseif selected_track == 3 then user_delta(pre .. "fmamt", d * 0.02)
        elseif selected_track == 4 then user_delta(pre .. "bits", d)
        end
      end
    else
      -- E2=cutoff, E3=voice-specific primary param
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
      -- ALT: E2=reverb room, E3=reverb damp
      if n == 2 then user_delta("reverb_room", d * 0.02)
      elseif n == 3 then user_delta("reverb_damp", d * 0.02) end
    else
      -- E2=selected track level, E3=reverb mix (master)
      if n == 2 then
        user_delta("t" .. selected_track .. "_level", d * 0.02)
      elseif n == 3 then
        user_delta("reverb_mix", d * 0.02)
      end
    end

  elseif current_page == 4 then -- MOD
    if k3_held then
      -- ALT: E2=bez tension, E3=lfo freq
      if n == 2 then user_delta("bez_tension", d * 0.03)
      elseif n == 3 then
        local f = params:get("lfo_freq")
        user_set("lfo_freq", util.clamp(f * (1 + d * 0.05), 0.01, 10))
      end
    else
      -- E2=select route, E3=route depth (the power knob)
      if n == 2 then
        selected_route = util.clamp(selected_route + d, 1, #MOD_ROUTES)
        flash(MOD_ROUTES[selected_route].name)
      elseif n == 3 then
        user_delta("mod_" .. selected_route, d * 0.03)
        flash(string.format("%.0f%%", mod_amounts[selected_route] * 100))
      end
    end

  elseif current_page == 5 then -- AUTO
    if k3_held then
      if n == 2 then user_delta("xmod_speed", d * 0.02)
      elseif n == 3 then user_delta("reverb_damp", d * 0.02) end
    else
      if n == 2 then
        robot_profile = util.clamp(robot_profile + d, 1, #robot.profiles)
        params:set("robot_profile", robot_profile)
        -- update explorer personality if running
        if explorer_on then
          stop_explorer()
          start_explorer()
        end
        flash(robot.profiles[robot_profile].name)
      elseif n == 3 then
        user_delta("reverb_mix", d * 0.02)
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
    else
      k3_held = false
      if os.clock() - k3_press_time < 0.3 then
        -- TAP actions
        if current_page == 1 then
          -- randomize selected track pattern
          local sc = tracks._scale_notes or scale_notes
          if #sc > 0 then
            evo.generate_pattern(tracks, selected_track, sc, 0.4 + math.random() * 0.4, 0.3, 1.0)
          end
          flash("RANDOM")
        elseif current_page == 2 then
          -- cycle track
          selected_track = (selected_track % NUM_TRACKS) + 1
          flash(TRACK_NAMES[selected_track])
        elseif current_page == 3 then
          -- cycle track on mixer
          selected_track = (selected_track % NUM_TRACKS) + 1
          flash(TRACK_NAMES[selected_track])
        elseif current_page == 4 then
          -- burst randomize bezier + crank a random mod route
          bez.randomize()
          local ri = math.random(1, #MOD_ROUTES)
          mod_amounts[ri] = util.clamp(mod_amounts[ri] + 0.2, 0, 1)
          params:set("mod_" .. ri, mod_amounts[ri])
          flash("BURST")
        elseif current_page == 5 then
          -- toggle explorer
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
    if z == 1 and x <= tracks[y].num_steps then
      tracks[y].steps[x].on = not tracks[y].steps[x].on
      selected_track = y; selected_step = x
      held_steps[y..","..x] = true
    elseif z == 0 then
      held_steps[y..","..x] = nil
    end
  elseif y >= 5 and y <= 8 and z == 1 then
    local octave = 5 - (y - 5)
    local target = scale_notes[1] + (octave - 1) * 12 + (x - 1) * 2
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
  for y = 5, 8 do
    for x = 1, 16 do g:led(x, y, (x % 5 == 1) and 4 or 2) end
  end
  g:refresh()
end

-- ======== SCREEN DRAWING ========

local function draw_header(name)
  screen.level(15)
  screen.font_size(8)
  screen.move(2, 8)
  screen.text(name)
  -- page dots
  for i = 1, #PAGES do
    screen.level(i == current_page and 15 or 3)
    screen.rect(44 + (i-1)*6, 3, 4, 4)
    screen.fill()
  end
  if k3_held then
    screen.level(15); screen.move(98, 8); screen.text("ALT")
  end
  -- param flash overlay
  if param_flash > 0.2 then
    screen.level(math.floor(param_flash * 12))
    screen.move(112, 8)
    screen.text_right(param_flash_name)
  end
  -- user override dot
  if explorer_on and evo.user_override_count() > 0 then
    screen.level(12); screen.rect(126, 1, 2, 2); screen.fill()
  end
end

local function draw_step_bar()
  if not playing then
    screen.level(3); screen.move(2, 63); screen.text("K2:play")
    if explorer_on then
      screen.level(12); screen.move(70, 63); screen.text("EXPLORE")
    end
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
    screen.rect(x, 60, w, 3)
    screen.fill()
  end
end

-- ---- PAGE 1: SEQ ----

local function draw_seq_page()
  -- header uses track name instead of "SEQ"
  draw_header(TRACK_NAMES[selected_track])

  -- full 4-track step display (12px per row), polymetric
  for t = 1, NUM_TRACKS do
    local y0 = 10 + (t-1) * 12
    local is_sel = (t == selected_track)
    local ns = tracks[t].num_steps
    local tpos = tracks[t].position

    -- show track length indicator
    screen.level(is_sel and 6 or 2)
    screen.move(ns * 8, y0); screen.line(ns * 8, y0 + 10); screen.stroke()

    for s = 1, 16 do
      local x = (s-1) * 8
      local stp = tracks[t].steps[s]
      local in_range = (s <= ns)
      local is_play = (s == tpos and playing and in_range)
      local is_cur = (is_sel and s == selected_step)
      local fl = step_flash[t][s] or 0

      if not in_range then
        -- beyond track length: invisible
      else
        local max_h = 10
        local h = stp.on and math.max(3, math.floor(stp.vel * max_h)) or max_h
        local y_off = max_h - h

        local lvl
        if is_play and stp.on then lvl = 15
        elseif is_play then lvl = is_sel and 7 or 4
        elseif fl > 0.2 then lvl = math.floor(5 + fl * 8)
        elseif stp.on then lvl = is_sel and 10 or 5
        else lvl = is_sel and 3 or 1 end

        screen.level(lvl)
        if stp.on or is_play then
          screen.rect(x + 1, y0 + y_off, 6, h)
          screen.fill()
        else
          screen.rect(x + 1, y0, 6, max_h)
          screen.stroke()
        end
      end

      -- selected cell: bright blinking outline
      if is_cur and in_range then
        screen.level(15)
        screen.rect(x, y0 - 1, 8, 12)
        screen.stroke()
      end
    end
  end

  -- info bar
  local step = tracks[selected_track].steps[selected_step]
  local nn = musicutil.note_num_to_name(step.note, true)
  screen.level(10); screen.move(0, 63)
  screen.text(TRACK_SHORT[selected_track] .. " " .. selected_step .. "/" .. tracks[selected_track].num_steps .. ":" .. nn)
  if step.on then
    screen.level(6); screen.move(68, 63)
    screen.text("v" .. string.format("%.0f", step.vel * 100))
  end
  screen.level(playing and 15 or 3); screen.move(124, 63); screen.text_right(playing and ">" or "||")
end

-- ---- PAGE 2: VOICE ----

local function draw_voice_page()
  draw_header("VOICE")

  local t = tracks[selected_track]

  -- track name big
  screen.level(15); screen.font_size(16)
  screen.move(64, 24)
  screen.text_center(TRACK_NAMES[selected_track])
  screen.font_size(8)

  -- filter curve visualization (simple LP response)
  local cut_norm = math.log(t.cutoff / 30) / math.log(12000 / 30) -- 0-1
  local res_h = t.res * 12
  local cx = 4 + cut_norm * 120
  screen.level(6)
  -- flat line before cutoff
  screen.move(4, 36)
  screen.line(math.max(4, cx - 8), 36)
  -- resonance peak
  screen.line(cx, 36 - res_h)
  -- rolloff after cutoff
  screen.line(math.min(124, cx + 20), 42)
  screen.line(124, 44)
  screen.stroke()
  -- cutoff position marker
  screen.level(12)
  screen.move(cx, 44); screen.line(cx, 46); screen.stroke()

  -- param readouts (two columns)
  screen.font_size(8)

  -- left: E2 param + ALT E2 param
  screen.level(k3_held and 5 or 10)
  screen.move(2, 52)
  screen.text("cut:" .. string.format("%.0f", t.cutoff))

  screen.level(k3_held and 10 or 5)
  screen.move(2, 60)
  screen.text("res:" .. string.format("%.2f", t.res))

  -- right: E3 param + ALT E3 param
  screen.level(k3_held and 5 or 10)
  screen.move(68, 52)
  if selected_track == 1 then screen.text("sprd:" .. string.format("%.2f", t.spread or 0))
  elseif selected_track == 2 then screen.text("acnt:" .. string.format("%.2f", t.accent or 0))
  elseif selected_track == 3 then screen.text("mrph:" .. string.format("%.2f", t.morph or 0))
  elseif selected_track == 4 then
    screen.text("eng:" .. ({"PLS","FM","WAV","NOI"})[(t.engine_sel or 0) + 1])
  end

  screen.level(k3_held and 10 or 5)
  screen.move(68, 60)
  if selected_track == 1 then screen.text("brt:" .. string.format("%.2f", t.brightness or 0))
  elseif selected_track == 2 then screen.text("gate:" .. string.format("%.2f", t.gate))
  elseif selected_track == 3 then screen.text("fm:" .. string.format("%.2f", t.fmamt or 0))
  elseif selected_track == 4 then screen.text("bits:" .. string.format("%.0f", t.bits or 10))
  end
end

-- ---- PAGE 3: MOD ----

local function draw_mod_page()
  draw_header("MIX")

  -- 4 vertical faders side by side
  local fader_w = 24
  local fader_h = 40
  local gap = 6
  local start_x = 4

  for t = 1, 4 do
    local x = start_x + (t-1) * (fader_w + gap)
    local y = 12
    local is_sel = (t == selected_track)
    local level = tracks[t].level
    local fill_h = math.floor(level * fader_h)

    -- fader track (outline)
    screen.level(is_sel and 6 or 2)
    screen.rect(x, y, fader_w, fader_h)
    screen.stroke()

    -- fader fill (from bottom)
    screen.level(is_sel and 12 or 5)
    screen.rect(x + 1, y + fader_h - fill_h, fader_w - 2, fill_h)
    screen.fill()

    -- live activity: cutoff as a bouncing line across the fader
    local cut_norm = math.log(math.max(tracks[t].cutoff, 30) / 30) / math.log(12000 / 30)
    local cut_y = y + fader_h - math.floor(cut_norm * fader_h)
    screen.level(is_sel and 15 or 8)
    screen.move(x + 2, cut_y)
    screen.line(x + fader_w - 2, cut_y)
    screen.stroke()

    -- mod pulse: flickering brightness on the fader
    local total_mod = 0
    for i, route in ipairs(MOD_ROUTES) do
      if route.track == t and mod_amounts[i] > 0.01 then
        total_mod = total_mod + math.abs(mod_values[i] or 0)
      end
    end
    if total_mod > 0.05 then
      screen.level(math.floor(total_mod * 10))
      screen.rect(x + 1, cut_y - 2, fader_w - 2, 4)
      screen.fill()
    end

    -- track name below
    screen.level(is_sel and 15 or 6)
    screen.move(x + fader_w / 2, y + fader_h + 8)
    screen.text_center(TRACK_SHORT[t])

    -- step count tiny
    screen.level(3)
    screen.move(x + fader_w / 2, y + fader_h + 14)
    screen.text_center(tostring(tracks[t].num_steps))
  end

  -- master reverb bar (right side)
  local rx = 120
  local rev = params:get("reverb_mix")
  local rev_h = math.floor(rev * fader_h)
  screen.level(3)
  screen.rect(rx, 12, 6, fader_h)
  screen.stroke()
  screen.level(8)
  screen.rect(rx + 1, 12 + fader_h - rev_h, 4, rev_h)
  screen.fill()
  screen.level(5)
  screen.move(rx + 3, 12 + fader_h + 8)
  screen.text_center("R")
end

-- ---- PAGE 4: MOD ----

local function draw_crazy_mod_page()
  draw_header("MOD")

  -- full-width bezier waveforms stacked, alive and moving
  local curves = {"curve1", "curve2", "curve3"}
  local curve_labels = {"BZ1", "BZ2", "BZ3"}
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

  -- route matrix: 6 routes as horizontal animated bars
  for i, route in ipairs(MOD_ROUTES) do
    local y = 34 + (i-1) * 5
    local is_sel = (i == selected_route)
    local amt = mod_amounts[i]
    local mv = mod_values[i] or 0

    -- label
    screen.level(is_sel and 15 or 4)
    screen.move(0, y + 4)
    screen.text(route.name:sub(1, 7))

    -- amount bar
    local bar_x = 42
    local bar_max = 84
    screen.level(2)
    screen.rect(bar_x, y, bar_max, 4)
    screen.stroke()

    -- fill: amount
    if amt > 0.01 then
      screen.level(is_sel and 8 or 4)
      screen.rect(bar_x, y, math.floor(amt * bar_max), 4)
      screen.fill()
    end

    -- live pulse: modulation value flickers on top
    if math.abs(mv) > 0.01 then
      local center = bar_x + math.floor(bar_max * 0.5)
      local pulse_w = math.floor(math.abs(mv) * bar_max * 0.5)
      screen.level(math.floor(6 + math.abs(mv) * 9))
      screen.rect(center, y, pulse_w * (mv > 0 and 1 or -1), 4)
      screen.fill()
    end
  end
end

-- ---- PAGE 5: AUTO ----

local function draw_auto_page()
  draw_header("AUTO")

  local p = robot.profiles[robot_profile]
  local energy = explorer_on and song_engine.get_energy() or 0.3

  -- robot avatar (left side)
  robot.draw(robot_profile, 22, 36, energy, explorer_on)

  -- profile info (right side)
  screen.level(15); screen.font_size(16)
  screen.move(48, 22)
  screen.text(p.name)
  screen.font_size(8)

  screen.level(6)
  screen.move(48, 32)
  screen.text(p.desc)

  if explorer_on then
    local section = song_engine.get_section_name()
    local progress = song_engine.get_progress()

    -- section name
    screen.level(12); screen.move(48, 38)
    screen.text(section)

    -- progress bar
    screen.level(3)
    screen.rect(48, 41, 78, 5); screen.stroke()
    screen.level(10)
    screen.rect(49, 42, progress * 76, 3); screen.fill()

    -- energy bar
    screen.level(math.floor(energy * 15))
    screen.rect(48, 50, math.floor(energy * 50), 3); screen.fill()
    screen.level(5)
    screen.move(100, 53)
    screen.text("E:" .. string.format("%.0f", energy * 100))
  else
    screen.level(4); screen.move(48, 42)
    screen.text("K3: explore")
    screen.level(3); screen.move(48, 52)
    screen.text("E2: profile")
  end

  draw_step_bar()
end

-- ======== REDRAW ========

function redraw()
  screen.clear()
  screen.aa(0)
  screen.font_face(1)
  screen.font_size(8)

  if current_page == 1 then draw_seq_page()
  elseif current_page == 2 then draw_voice_page()
  elseif current_page == 3 then draw_mod_page()
  elseif current_page == 4 then draw_crazy_mod_page()
  elseif current_page == 5 then draw_auto_page()
  end

  screen.update()
end

-- ======== CLEANUP ========

function cleanup()
  stop_sequencer()
  if explorer_on then stop_explorer() end
end
