-- slap
-- 4-part autonomous synth sequencer
-- inspired by Fred's Lab:
-- MANTA / ZKIT / TOROID / BZZT
--
-- E1: page select
-- E2/E3: page params
-- K2: play/stop
-- K3: tap=page action, hold=ALT
--
-- pages: SEQ / VOICE / MOD / AUTO
--
-- v1.0 @jamminstein

engine.name = "Slap"

local musicutil = require "musicutil"
local util = require "util"
local bez = include("lib/bezier_mod")
local evo = include("lib/evolution")
local personalities = include("lib/personalities")
local song_engine = include("lib/song_engine")

-- ======== CONSTANTS ========

local PAGES = {"SEQ", "VOICE", "MOD", "AUTO"}
local NUM_TRACKS = 4
local NUM_STEPS = 16
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
local mod_amounts = {0, 0, 0, 0, 0, 0}  -- per-route modulation depth (0-1)
local selected_route = 1

-- ======== STATE ========

local current_page = 1
local playing = false
local selected_track = 1
local selected_step = 1
local position = 0
local k3_held = false
local k3_press_time = 0
local seq_clock = nil
local screen_dirty = true

-- explorer
local explorer_on = false
local explorer_style = 1

-- scale
local scale_notes = {}

-- tracks
local tracks = {}

-- grid
local g = grid.connect()
local held_steps = {}

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
      cutoff = 2000, res = 0.3, gate = 0.7, level = 1.0,
    }
    for s = 1, NUM_STEPS do
      tracks[i].steps[s] = {on = false, note = 60, vel = 0.8}
    end
  end

  -- MANTA: sustained spectral pads
  local m = tracks[1]
  m.cutoff = 3500; m.res = 0.15; m.gate = 0.95
  m.spread = 0.4; m.brightness = 0.6
  local m_pat = {{1,50,0.5},{5,57,0.45},{9,53,0.5},{13,55,0.4}}
  for _, p in ipairs(m_pat) do
    m.steps[p[1]] = {on = true, note = p[2], vel = p[3]}
  end

  -- ZKIT: acid bassline
  local z = tracks[2]
  z.cutoff = 500; z.res = 0.75; z.gate = 0.45; z.accent = 0.85
  local z_pat = {{1,38,1.0},{4,38,0.7},{6,41,0.9},{8,43,0.6},{9,45,1.0},{12,45,0.5},{14,43,0.8},{16,41,0.6}}
  for _, p in ipairs(z_pat) do
    z.steps[p[1]] = {on = true, note = p[2], vel = p[3]}
  end

  -- TOROID: melodic arpeggio
  local t = tracks[3]
  t.cutoff = 4500; t.res = 0.3; t.gate = 0.55
  t.morph = 0.35; t.fmamt = 0.25; t.lfoRate = 3; t.lfoDepth = 0.15
  local t_pat = {{1,62,0.7},{2,65,0.6},{3,69,0.7},{5,74,0.8},{7,69,0.6},{9,65,0.7},{11,62,0.5},{13,60,0.6},{15,62,0.7}}
  for _, p in ipairs(t_pat) do
    t.steps[p[1]] = {on = true, note = p[2], vel = p[3]}
  end

  -- BZZT: percussive hits
  local b = tracks[4]
  b.cutoff = 7000; b.res = 0.15; b.gate = 0.15
  b.engine_sel = 0; b.pwm = 0.5; b.bits = 10
  local b_pat = {{1,36,1.0},{3,84,0.5},{5,36,0.8},{7,84,0.45},{9,36,1.0},{10,60,0.3},{11,84,0.55},{13,36,0.7},{15,84,0.6},{16,60,0.25}}
  for _, p in ipairs(b_pat) do
    b.steps[p[1]] = {on = true, note = p[2], vel = p[3]}
  end

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

-- helper: set param AND mark user-owned
local function user_delta(name, delta)
  params:delta(name, delta)
  evo.user_touched(name)
end

local function user_set(name, val)
  params:set(name, val)
  evo.user_touched(name)
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

  -- bezier mod params
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

  -- per-route modulation amounts
  for i, route in ipairs(MOD_ROUTES) do
    params:add_control("mod_" .. i, "mod>" .. route.name,
      controlspec.new(0, 1, 'lin', 0.01, 0))
    params:set_action("mod_" .. i, function(v) mod_amounts[i] = v end)
  end

  -- explorer
  params:add_separator("AUTONOMOUS")
  params:add_option("explorer_style", "personality", personalities.NAMES, 1)
  params:set_action("explorer_style", function(v) explorer_style = v end)

  -- per-track params
  for i = 1, NUM_TRACKS do
    local t = tracks[i]
    local pre = "t" .. i .. "_"

    params:add_separator(TRACK_NAMES[i])

    params:add_control(pre .. "cutoff", "cutoff",
      controlspec.new(30, 12000, 'exp', 0, t.cutoff, "hz"))
    params:set_action(pre .. "cutoff", function(v)
      t.cutoff = v; engine.set_param(i - 1, "cutoff", v)
    end)

    params:add_control(pre .. "res", "resonance",
      controlspec.new(0, 1, 'lin', 0.01, t.res))
    params:set_action(pre .. "res", function(v)
      t.res = v; engine.set_param(i - 1, "res", v)
    end)

    params:add_control(pre .. "gate", "gate length",
      controlspec.new(0.05, 1, 'lin', 0.01, t.gate))
    params:set_action(pre .. "gate", function(v) t.gate = v end)

    params:add_control(pre .. "level", "level",
      controlspec.new(0, 1, 'lin', 0.01, t.level))
    params:set_action(pre .. "level", function(v) t.level = v end)

    if i == 1 then
      params:add_control(pre .. "spread", "spectral spread",
        controlspec.new(0, 1, 'lin', 0.01, t.spread or 0.4))
      params:set_action(pre .. "spread", function(v)
        t.spread = v; engine.set_param(0, "spread", v)
      end)
      params:add_control(pre .. "brightness", "brightness",
        controlspec.new(0, 1, 'lin', 0.01, t.brightness or 0.6))
      params:set_action(pre .. "brightness", function(v)
        t.brightness = v; engine.set_param(0, "brightness", v)
      end)
    elseif i == 2 then
      params:add_control(pre .. "accent", "filter accent",
        controlspec.new(0, 1, 'lin', 0.01, t.accent or 0.8))
      params:set_action(pre .. "accent", function(v)
        t.accent = v; engine.set_param(1, "accent", v)
      end)
    elseif i == 3 then
      params:add_control(pre .. "morph", "waveform morph",
        controlspec.new(0, 1, 'lin', 0.01, t.morph or 0.35))
      params:set_action(pre .. "morph", function(v)
        t.morph = v; engine.set_param(2, "morph", v)
      end)
      params:add_control(pre .. "fmamt", "FM amount",
        controlspec.new(0, 1, 'lin', 0.01, t.fmamt or 0.25))
      params:set_action(pre .. "fmamt", function(v)
        t.fmamt = v; engine.set_param(2, "fmamt", v)
      end)
      params:add_control(pre .. "lfoRate", "LFO rate",
        controlspec.new(0.1, 20, 'exp', 0, t.lfoRate or 3, "hz"))
      params:set_action(pre .. "lfoRate", function(v)
        t.lfoRate = v; engine.set_param(2, "lfoRate", v)
      end)
      params:add_control(pre .. "lfoDepth", "LFO depth",
        controlspec.new(0, 1, 'lin', 0.01, t.lfoDepth or 0.15))
      params:set_action(pre .. "lfoDepth", function(v)
        t.lfoDepth = v; engine.set_param(2, "lfoDepth", v)
      end)
    elseif i == 4 then
      params:add_option(pre .. "engine", "engine",
        {"PULSE", "FM", "WAVES", "NOISE"}, (t.engine_sel or 0) + 1)
      params:set_action(pre .. "engine", function(v)
        t.engine_sel = v - 1; engine.set_param(3, "engine_sel", v - 1)
      end)
      params:add_control(pre .. "pwm", "pulse width",
        controlspec.new(0.05, 0.95, 'lin', 0.01, t.pwm or 0.5))
      params:set_action(pre .. "pwm", function(v)
        t.pwm = v; engine.set_param(3, "pwm", v)
      end)
      params:add_control(pre .. "bits", "bit depth",
        controlspec.new(4, 16, 'lin', 1, t.bits or 10, "bits"))
      params:set_action(pre .. "bits", function(v)
        t.bits = v; engine.set_param(3, "bits", v)
      end)
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

  -- screen + modulation refresh
  clock.run(function()
    while true do
      clock.sleep(1 / 15)
      apply_bezier_modulation()
      redraw()
      grid_redraw()
    end
  end)
end

-- ======== BEZIER MODULATION ROUTING ========

function apply_bezier_modulation()
  local dt = 1 / 15
  bez.update(dt)

  local b1 = bez.get_raw("curve1")
  local b2 = bez.get_raw("curve2")
  local b3 = bez.get_raw("curve3")
  local lfo_val = bez.get_raw("lfo")

  -- combine sources: route 1-3 use curves, 4-6 use lfo blend
  local sources = {b1, b2, b3, lfo_val, (b1 + lfo_val) * 0.5, (b2 + b3) * 0.5}

  for i, route in ipairs(MOD_ROUTES) do
    if mod_amounts[i] > 0.01 then
      local base = params:get(route.param)
      local mod = sources[i] * mod_amounts[i] * base * route.base_mult
      local modulated = util.clamp(base + mod, 30, 16000)
      engine.set_param(route.track - 1, route.sc_param, modulated)
    end
  end
end

-- ======== SEQUENCER ========

function trigger_note(track_idx)
  local t = tracks[track_idx]
  local step = t.steps[position]
  if step.on then
    local freq = musicutil.note_num_to_freq(step.note)
    local amp = step.vel * t.level
    send_track_params(track_idx)
    engine.note_on(track_idx - 1, freq, amp)
    clock.run(function()
      clock.sleep(clock.get_beat_sec() * t.gate * 0.25)
      engine.note_off(track_idx - 1)
    end)
  end
end

function start_sequencer()
  playing = true
  seq_clock = clock.run(function()
    while playing do
      clock.sync(1 / 4)
      position = (position % NUM_STEPS) + 1
      for t = 1, NUM_TRACKS do
        trigger_note(t)
      end
    end
  end)
end

function stop_sequencer()
  playing = false
  if seq_clock then clock.cancel(seq_clock); seq_clock = nil end
  for i = 0, 3 do engine.note_off(i) end
  position = 0
end

-- ======== EXPLORER ========

local function start_explorer()
  if explorer_on then return end
  explorer_on = true
  song_engine.start(explorer_style)
end

local function stop_explorer()
  explorer_on = false
  song_engine.stop()
end

-- ======== INPUT: ENCODERS ========

function enc(n, d)
  if n == 1 then
    current_page = util.clamp(current_page + d, 1, #PAGES)
    return
  end

  if current_page == 1 then
    -- SEQ: step editing
    if k3_held then
      -- ALT: E2=track select, E3=velocity
      if n == 2 then
        selected_track = util.clamp(selected_track + d, 1, NUM_TRACKS)
      elseif n == 3 then
        local step = tracks[selected_track].steps[selected_step]
        step.vel = util.clamp(step.vel + d * 0.05, 0.1, 1.0)
      end
    else
      -- E2=step select, E3=note
      if n == 2 then
        selected_step = util.clamp(selected_step + d, 1, NUM_STEPS)
      elseif n == 3 then
        local step = tracks[selected_track].steps[selected_step]
        step.note = util.clamp(step.note + d, 24, 96)
        step.note = musicutil.snap_note_to_array(step.note, scale_notes)
      end
    end

  elseif current_page == 2 then
    -- VOICE: per-track sound params
    if k3_held then
      -- ALT: E2=gate, E3=level
      if n == 2 then
        user_delta("t" .. selected_track .. "_gate", d * 0.02)
      elseif n == 3 then
        user_delta("t" .. selected_track .. "_level", d * 0.02)
      end
    else
      -- E2=cutoff, E3=resonance
      if n == 2 then
        local t = tracks[selected_track]
        local new_cut = util.clamp(t.cutoff * (1 + d * 0.03), 30, 12000)
        user_set("t" .. selected_track .. "_cutoff", new_cut)
      elseif n == 3 then
        user_delta("t" .. selected_track .. "_res", d * 0.02)
      end
    end

  elseif current_page == 3 then
    -- MOD: bezier routing
    if k3_held then
      -- ALT: E2=bez tension, E3=lfo freq
      if n == 2 then user_delta("bez_tension", d * 0.03)
      elseif n == 3 then
        local f = params:get("lfo_freq")
        user_set("lfo_freq", util.clamp(f * (1 + d * 0.05), 0.01, 10))
      end
    else
      -- E2=bez speed, E3=selected route amount
      if n == 2 then
        local spd = params:get("bez_speed")
        user_set("bez_speed", util.clamp(spd * (1 + d * 0.05), 0.01, 3))
      elseif n == 3 then
        user_delta("mod_" .. selected_route, d * 0.02)
      end
    end

  elseif current_page == 4 then
    -- AUTO: personality + explorer
    if k3_held then
      -- ALT: E2=xmod, E3=reverb
      if n == 2 then user_delta("xmod_speed", d * 0.02)
      elseif n == 3 then user_delta("reverb_mix", d * 0.02) end
    else
      -- E2=personality, E3=track select
      if n == 2 then
        explorer_style = util.clamp(explorer_style + d, 1, #personalities.NAMES)
        params:set("explorer_style", explorer_style)
      elseif n == 3 then
        selected_track = util.clamp(selected_track + d, 1, NUM_TRACKS)
      end
    end
  end

  screen_dirty = true
end

-- ======== INPUT: KEYS ========

function key(n, z)
  if n == 3 then
    if z == 1 then
      k3_held = true
      k3_press_time = os.clock()
    else
      k3_held = false
      local held = os.clock() - k3_press_time
      if held < 0.3 then
        -- TAP: page-specific action
        if current_page == 1 then
          -- toggle selected step
          local step = tracks[selected_track].steps[selected_step]
          step.on = not step.on
        elseif current_page == 2 then
          -- cycle selected track
          selected_track = (selected_track % NUM_TRACKS) + 1
        elseif current_page == 3 then
          -- cycle modulation route
          selected_route = (selected_route % #MOD_ROUTES) + 1
        elseif current_page == 4 then
          -- toggle explorer
          if explorer_on then
            stop_explorer()
          else
            start_explorer()
          end
        end
      end
    end
  elseif n == 2 and z == 1 then
    if playing then stop_sequencer() else start_sequencer() end
  end

  screen_dirty = true
end

-- ======== GRID ========

function grid_key(x, y, z)
  if y >= 1 and y <= 4 then
    if z == 1 then
      tracks[y].steps[x].on = not tracks[y].steps[x].on
      selected_track = y
      selected_step = x
      held_steps[y .. "," .. x] = true
    else
      held_steps[y .. "," .. x] = nil
    end
  elseif y >= 5 and y <= 8 and z == 1 then
    local octave = 5 - (y - 5)
    local target = scale_notes[1] + (octave - 1) * 12 + (x - 1) * 2
    target = musicutil.snap_note_to_array(util.clamp(target, 24, 96), scale_notes)

    local assigned = false
    for key_id, _ in pairs(held_steps) do
      local ty, tx = key_id:match("(%d+),(%d+)")
      ty = tonumber(ty); tx = tonumber(tx)
      if ty and tx then
        tracks[ty].steps[tx].note = target
        tracks[ty].steps[tx].on = true
        assigned = true
      end
    end

    if not assigned then
      local freq = musicutil.note_num_to_freq(target)
      send_track_params(selected_track)
      engine.note_on(selected_track - 1, freq, 0.7)
      clock.run(function()
        clock.sleep(0.3)
        engine.note_off(selected_track - 1)
      end)
    end
  end
  screen_dirty = true
end

function grid_redraw()
  g:all(0)
  for t = 1, 4 do
    for s = 1, NUM_STEPS do
      local step = tracks[t].steps[s]
      local br = 0
      if step.on then br = 5 end
      if s == position and playing then br = step.on and 15 or 4 end
      if t == selected_track and s == selected_step then br = math.max(br, 8) end
      g:led(s, t, br)
    end
  end
  for y = 5, 8 do
    for x = 1, 16 do
      g:led(x, y, (x % 5 == 1) and 4 or 2)
    end
  end
  g:refresh()
end

-- ======== SCREEN ========

local function draw_header(name)
  screen.level(15)
  screen.font_size(8)
  screen.move(2, 8)
  screen.text(name)
  -- page dots
  for i = 1, #PAGES do
    screen.level(i == current_page and 15 or 3)
    screen.rect(44 + (i - 1) * 6, 3, 4, 4)
    screen.fill()
  end
  -- ALT indicator
  if k3_held then
    screen.level(15)
    screen.move(120, 8)
    screen.text("ALT")
  end
  -- user override dot
  if explorer_on and evo.user_override_count() > 0 then
    screen.level(12)
    screen.rect(126, 1, 2, 2)
    screen.fill()
  end
end

local function draw_step_bar()
  if not playing then
    screen.level(3)
    screen.move(2, 62)
    screen.text("K2:play")
    if explorer_on then
      screen.level(12)
      screen.move(70, 62)
      screen.text("EXPLORING")
    end
    return
  end
  for i = 1, NUM_STEPS do
    local x = 2 + (i - 1) * 7.8
    local step = tracks[selected_track].steps[i]
    if i == position then screen.level(15)
    elseif step.on then screen.level(4)
    else screen.level(1) end
    screen.rect(x, 59, 6, 4)
    screen.fill()
  end
end

local function draw_seq_page()
  draw_header("SEQ")

  -- 4 track rows
  for t = 1, NUM_TRACKS do
    local y_base = 10 + (t - 1) * 12
    local is_sel = (t == selected_track)

    for s = 1, NUM_STEPS do
      local x = (s - 1) * 8
      local step = tracks[t].steps[s]
      local is_playing = (s == position and playing)
      local is_cursor = (is_sel and s == selected_step)

      local lvl
      if is_playing and step.on then lvl = 15
      elseif is_playing then lvl = is_sel and 7 or 4
      elseif step.on then lvl = is_sel and 10 or 5
      else lvl = is_sel and 3 or 1 end

      screen.level(lvl)
      if step.on or is_playing then
        screen.rect(x + 1, y_base, 6, 9)
        screen.fill()
      else
        screen.rect(x + 1, y_base, 6, 9)
        screen.stroke()
      end

      if is_cursor then
        screen.level(15)
        screen.rect(x + 2, y_base + 10, 4, 1)
        screen.fill()
      end
    end
  end

  -- info
  local step = tracks[selected_track].steps[selected_step]
  local note_name = musicutil.note_num_to_name(step.note, true)
  screen.level(10)
  screen.move(0, 62)
  screen.text(TRACK_SHORT[selected_track] .. " " .. selected_step .. ":" .. note_name)

  screen.level(playing and 15 or 3)
  screen.move(124, 62)
  screen.text_right(playing and ">" or "||")
end

local function draw_voice_page()
  draw_header("VOICE")

  local t = tracks[selected_track]
  local pre = "t" .. selected_track .. "_"

  -- track name big
  screen.level(15)
  screen.font_size(16)
  screen.move(64, 28)
  screen.text_center(TRACK_NAMES[selected_track])
  screen.font_size(8)

  -- params display
  screen.level(8)
  screen.move(2, 40)
  screen.text("cut:" .. string.format("%.0f", t.cutoff))
  screen.move(64, 40)
  screen.text("res:" .. string.format("%.2f", t.res))

  screen.level(6)
  screen.move(2, 50)
  screen.text("gate:" .. string.format("%.2f", t.gate))
  screen.move(64, 50)
  screen.text("lvl:" .. string.format("%.2f", t.level))

  -- voice-specific
  screen.level(5)
  if selected_track == 1 then
    screen.move(2, 58)
    screen.text("sprd:" .. string.format("%.2f", t.spread or 0))
    screen.move(64, 58)
    screen.text("brt:" .. string.format("%.2f", t.brightness or 0))
  elseif selected_track == 2 then
    screen.move(2, 58)
    screen.text("accent:" .. string.format("%.2f", t.accent or 0))
  elseif selected_track == 3 then
    screen.move(2, 58)
    screen.text("mrph:" .. string.format("%.2f", t.morph or 0))
    screen.move(64, 58)
    screen.text("fm:" .. string.format("%.2f", t.fmamt or 0))
  elseif selected_track == 4 then
    screen.move(2, 58)
    screen.text("eng:" .. ({"PLS", "FM", "WAV", "NOI"})[math.floor(t.engine_sel or 0) + 1])
    screen.move(64, 58)
    screen.text("bits:" .. string.format("%.0f", t.bits or 10))
  end

  draw_step_bar()
end

local function draw_mod_page()
  draw_header("MOD")

  -- bezier waveform displays
  local curves = {"curve1", "curve2", "curve3"}
  for ci, cname in ipairs(curves) do
    local history, idx = bez.get_history(cname)
    local x_off = (ci - 1) * 43
    local y_center = 24
    screen.level(ci == 1 and 10 or (ci == 2 and 7 or 4))
    for i = 1, 42 do
      local hi = ((idx - 1 + i - 1) % 64) + 1
      local val = history[hi] or 0
      local px = x_off + i
      local py = y_center - val * 10
      if i == 1 then screen.move(px, py)
      else screen.line(px, py) end
    end
    screen.stroke()
  end

  -- routing bars
  screen.level(5)
  screen.move(2, 36)
  screen.text("ROUTES")

  for i, route in ipairs(MOD_ROUTES) do
    local x = 2 + (i - 1) * 21
    local y = 40
    local h = math.floor(mod_amounts[i] * 18)

    screen.level(i == selected_route and 15 or 4)
    screen.rect(x, y + 18 - h, 18, h)
    screen.fill()

    screen.level(i == selected_route and 12 or 3)
    screen.move(x + 9, 62)
    local short = route.name:sub(1, 3)
    screen.text_center(short)
  end

  draw_step_bar()
end

local function draw_auto_page()
  draw_header("AUTO")

  -- personality display
  screen.level(15)
  screen.font_size(16)
  screen.move(64, 26)
  screen.text_center(personalities.NAMES[explorer_style])
  screen.font_size(8)

  screen.level(6)
  screen.move(64, 36)
  screen.text_center(personalities[explorer_style].desc)

  -- explorer status
  if explorer_on then
    -- section name + progress bar
    local section = song_engine.get_section_name()
    local progress = song_engine.get_progress()
    local energy = song_engine.get_energy()

    screen.level(12)
    screen.move(2, 48)
    screen.text(section)

    -- progress bar
    screen.level(5)
    screen.rect(50, 44, 76, 6)
    screen.stroke()
    screen.level(10)
    screen.rect(51, 45, progress * 74, 4)
    screen.fill()

    -- energy indicator
    screen.level(math.floor(energy * 15))
    screen.rect(2, 52, math.floor(energy * 30), 3)
    screen.fill()

    screen.level(7)
    screen.move(36, 55)
    screen.text("E:" .. string.format("%.0f%%", energy * 100))
  else
    screen.level(4)
    screen.move(64, 48)
    screen.text_center("K3: start exploring")
  end

  draw_step_bar()
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.font_face(1)

  if current_page == 1 then draw_seq_page()
  elseif current_page == 2 then draw_voice_page()
  elseif current_page == 3 then draw_mod_page()
  elseif current_page == 4 then draw_auto_page()
  end

  screen.update()
end

-- ======== CLEANUP ========

function cleanup()
  stop_sequencer()
  if explorer_on then stop_explorer() end
end
