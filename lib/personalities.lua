-- personalities.lua
-- 5 autonomous personalities for slap
-- each has song form with sections, moods, and energy arcs
-- moods now steer TRACK LENGTHS as part of the arc:
--   tracks have tendencies, not fixed lengths
--   a mood might pull everyone to 16 for a locked chorus,
--   then scatter to odd lengths for a loose verse

local util = require "util"

local P = {}

P.NAMES = {"MANTA", "ZKIT", "TOROID", "BZZT", "ATEMPORAL"}

-- helper: steer one track toward a target length (probability gated)
local function steer_length(evo, tracks, track_idx, target, prob)
  if math.random() < (prob or 0.06) then
    evo.pattern_mutate(tracks, track_idx, "set_length",
      {target = target, scale_notes = tracks._scale_notes or {}})
  end
end

-- helper: steer ALL tracks toward target lengths
local function steer_all(evo, tracks, targets, prob)
  for i = 1, 4 do
    steer_length(evo, tracks, i, targets[i], prob)
  end
end

-- ======================================================================
-- 1. MANTA — The Ambient Drifter
-- tendency: loose odd meters, but BLOOM pulls to 16 for a locked moment
-- ======================================================================
P[1] = {
  name = "MANTA",
  desc = "ambient spectral drift",
  tick_speed = 2,
  ticks_per_bar = 2,
  focus_tracks = {1, 3},
  on_cycle = "vary",
  intervals = {0, 2, 3, 5, 7, 10, 12, 14, 15, 19, 24},
  density_range = {0.2, 0.5},

  form = {
    {name = "EMERGE",   mood = "emerge",   bars = 12, energy = {0.1, 0.3}, transition = "fade"},
    {name = "FLOAT",    mood = "float",    bars = 16, energy = {0.3, 0.5}, transition = "fade"},
    {name = "BLOOM",    mood = "bloom",    bars = 12, energy = {0.5, 0.8}, transition = "push"},
    {name = "DISSOLVE", mood = "dissolve", bars = 8,  energy = {0.6, 0.1}, transition = "fade"},
  },

  moods = {
    emerge = function(evo, tracks, progress, energy)
      -- loose: drift toward odd lengths
      steer_all(evo, tracks, {11, 14, 13, 9}, 0.04)

      evo.sweep_toward("t1_cutoff", 1500 + progress * 2000, 0.02)
      evo.sweep_toward("t1_spread", 0.2 + progress * 0.3, 0.02)
      evo.sweep_toward("t1_brightness", 0.3 + progress * 0.3, 0.02)
      evo.sweep_toward("reverb_mix", 0.4, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1,4), "velocity_drift")
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1,3), "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
    end,
    float = function(evo, tracks, progress, energy)
      -- still loose but lengths start converging
      steer_all(evo, tracks, {12, 15, 14, 10}, 0.04)

      evo.sweep_toward("t1_cutoff", 3000 + progress * 3000, 0.01)
      evo.sweep_toward("t1_spread", 0.5 + progress * 0.3, 0.01)
      evo.sweep_toward("t3_morph", 0.2 + progress * 0.4, 0.02)
      evo.sweep_toward("t3_fmamt", progress * 0.3, 0.02)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(1,3), "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(1,3), "shift",
          {interval = ({5, 7, 12})[math.random(3)]})
      end
    end,
    bloom = function(evo, tracks, progress, energy)
      -- LOCKED: everyone pulls to 16 for the chorus
      steer_all(evo, tracks, {16, 16, 16, 16}, 0.08)

      evo.sweep_toward("t1_cutoff", 6000 + progress * 4000, 0.02)
      evo.sweep_toward("t1_brightness", 0.8, 0.02)
      evo.sweep_toward("t1_spread", 0.8, 0.02)
      evo.sweep_toward("t3_cutoff", 5000 + progress * 3000, 0.02)
      evo.sweep_toward("t3_morph", 0.6 + progress * 0.3, 0.02)
      evo.sweep_toward("reverb_mix", 0.5 + progress * 0.2, 0.01)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1,4), "thicken")
      end
    end,
    dissolve = function(evo, tracks, progress, energy)
      -- scatter back to odd lengths
      steer_all(evo, tracks, {9, 13, 11, 7}, 0.06)

      evo.sweep_toward("t1_cutoff", 2000 - progress * 1000, 0.03)
      evo.sweep_toward("t1_brightness", 0.3, 0.03)
      evo.sweep_toward("reverb_mix", 0.6, 0.02)
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, math.random(1,4), "thin")
      end
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(1,4), "ghost")
      end
    end,
  },
}

-- ======================================================================
-- 2. ZKIT — The Acid Machine
-- tendency: 16-step 4/4 for acid grooves, but BUILD goes polymetric
-- ======================================================================
P[2] = {
  name = "ZKIT",
  desc = "acid bass machine",
  tick_speed = 1,
  ticks_per_bar = 2,
  focus_tracks = {2, 4},
  on_cycle = "vary",
  intervals = {0, 3, 5, 7, 10, 12, -5, -7, -12},
  density_range = {0.5, 0.9},

  form = {
    {name = "PULSE",  mood = "pulse",  bars = 8,  energy = {0.3, 0.4}, transition = "fade"},
    {name = "BUILD",  mood = "build",  bars = 16, energy = {0.4, 0.7}, transition = "push"},
    {name = "ACID",   mood = "acid",   bars = 12, energy = {0.8, 1.0}, transition = "cut"},
    {name = "STRIP",  mood = "strip",  bars = 8,  energy = {0.5, 0.3}, transition = "pull"},
    {name = "ACID II",mood = "acid",   bars = 12, energy = {0.85, 1.0},transition = "cut"},
    {name = "COOL",   mood = "cool",   bars = 8,  energy = {0.4, 0.15},transition = "fade"},
  },

  moods = {
    pulse = function(evo, tracks, progress, energy)
      -- start locked at 16
      steer_all(evo, tracks, {16, 16, 16, 16}, 0.06)

      evo.sweep_toward("t2_cutoff", 400 + progress * 200, 0.02)
      evo.sweep_toward("t2_res", 0.6, 0.02)
      evo.sweep_toward("t2_accent", 0.5, 0.03)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(1,4), "velocity_drift")
      end
    end,
    build = function(evo, tracks, progress, energy)
      -- go polymetric during build: tension through meter
      steer_all(evo, tracks, {14, 16, 12, 10}, 0.05)

      evo.sweep_toward("t2_cutoff", 500 + progress * 2000, 0.02)
      evo.sweep_toward("t2_res", 0.6 + progress * 0.2, 0.02)
      evo.sweep_toward("t2_accent", 0.5 + progress * 0.4, 0.02)
      evo.sweep_toward("t4_cutoff", 5000 + progress * 3000, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 2, "accent")
      end
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 4, "thicken")
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1,4), "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
    end,
    acid = function(evo, tracks, progress, energy)
      -- LOCK to 16 for the acid peak — everything on the grid
      steer_all(evo, tracks, {16, 16, 16, 16}, 0.10)

      evo.sweep_toward("t2_cutoff", 2000 + progress * 4000, 0.03)
      evo.sweep_toward("t2_res", 0.85, 0.03)
      evo.sweep_toward("t2_accent", 0.95, 0.03)
      evo.sweep_toward("t2_gate", 0.3, 0.02)
      evo.sweep_toward("t4_cutoff", 8000, 0.02)
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, 2, "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, 2, "rotate", {n = 1})
      end
    end,
    strip = function(evo, tracks, progress, energy)
      -- loosen: odd meters creep in
      steer_all(evo, tracks, {12, 14, 16, 10}, 0.05)

      evo.sweep_toward("t2_cutoff", 800, 0.03)
      evo.sweep_toward("t2_res", 0.5, 0.03)
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, math.random(1,4), "thin")
      end
    end,
    cool = function(evo, tracks, progress, energy)
      -- drift to odd lengths during cooldown
      steer_all(evo, tracks, {11, 13, 15, 9}, 0.04)

      evo.sweep_toward("t2_cutoff", 400, 0.03)
      evo.sweep_toward("t2_accent", 0.3, 0.03)
      evo.sweep_toward("reverb_mix", 0.35, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1,4), "ghost")
      end
    end,
  },
}

-- ======================================================================
-- 3. TOROID — The Melodic Explorer
-- tendency: odd meters for melody, but SOAR locks to 16 for the hook
-- ======================================================================
P[3] = {
  name = "TOROID",
  desc = "melodic morph explorer",
  tick_speed = 1,
  ticks_per_bar = 2,
  focus_tracks = {3, 1},
  on_cycle = "vary",
  intervals = {0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 19},
  density_range = {0.4, 0.8},

  form = {
    {name = "DRIFT",   mood = "drift",   bars = 10, energy = {0.2, 0.4}, transition = "fade"},
    {name = "WEAVE",   mood = "weave",   bars = 16, energy = {0.4, 0.7}, transition = "push"},
    {name = "SOAR",    mood = "soar",    bars = 12, energy = {0.7, 0.9}, transition = "push"},
    {name = "SCATTER", mood = "scatter", bars = 8,  energy = {0.6, 0.3}, transition = "fade"},
    {name = "RETURN",  mood = "return_",  bars = 10, energy = {0.3, 0.5}, transition = "fade"},
  },

  moods = {
    drift = function(evo, tracks, progress, energy)
      -- loose odd meters
      steer_all(evo, tracks, {11, 14, 13, 9}, 0.04)

      evo.sweep_toward("t3_morph", 0.2 + progress * 0.2, 0.02)
      evo.sweep_toward("t3_fmamt", 0.1, 0.02)
      evo.sweep_toward("t3_cutoff", 3000 + progress * 1500, 0.02)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 3, "velocity_drift")
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1,3), "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
    end,
    weave = function(evo, tracks, progress, energy)
      -- lengths start converging, building anticipation
      steer_all(evo, tracks, {14, 16, 15, 12}, 0.05)

      evo.sweep_toward("t3_morph", 0.3 + progress * 0.3, 0.02)
      evo.sweep_toward("t3_fmamt", progress * 0.4, 0.02)
      evo.sweep_toward("t3_cutoff", 4000 + progress * 4000, 0.02)
      evo.sweep_toward("t1_cutoff", 3000 + progress * 2000, 0.01)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 3, "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.05 then
        evo.pattern_mutate(tracks, 3, "thicken")
      end
    end,
    soar = function(evo, tracks, progress, energy)
      -- LOCKED 16 for the melodic peak — the hook
      steer_all(evo, tracks, {16, 16, 16, 16}, 0.10)

      evo.sweep_toward("t3_morph", 0.7 + progress * 0.2, 0.02)
      evo.sweep_toward("t3_fmamt", 0.4 + progress * 0.3, 0.02)
      evo.sweep_toward("t3_cutoff", 8000 + progress * 4000, 0.02)
      evo.sweep_toward("reverb_mix", 0.4 + progress * 0.2, 0.01)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 3, "shift",
          {interval = ({2, 5, 7})[math.random(3)]})
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1,4), "thicken")
      end
    end,
    scatter = function(evo, tracks, progress, energy)
      -- explode to wild lengths
      steer_all(evo, tracks, {7, 11, 9, 5}, 0.08)

      evo.sweep_toward("t3_morph", 0.5, 0.03)
      evo.sweep_toward("t3_fmamt", 0.2, 0.03)
      if math.random() < 0.15 then
        evo.pattern_mutate(tracks, math.random(1,4), "rotate",
          {n = math.random(-2, 2)})
      end
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1,4), "thin")
      end
    end,
    return_ = function(evo, tracks, progress, energy)
      -- settle back toward natural odd meters
      steer_all(evo, tracks, {12, 14, 13, 10}, 0.04)

      evo.sweep_toward("t3_morph", 0.3, 0.02)
      evo.sweep_toward("t3_fmamt", 0.15, 0.02)
      evo.sweep_toward("t3_cutoff", 3500, 0.02)
      evo.sweep_toward("reverb_mix", 0.3, 0.02)
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1,3), "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
    end,
  },
}

-- ======================================================================
-- 4. BZZT — The Rhythm Architect
-- tendency: short loops (10), but GROOVE locks to 16, BREAK goes wild
-- ======================================================================
P[4] = {
  name = "BZZT",
  desc = "digital rhythm architect",
  tick_speed = 1,
  ticks_per_bar = 2,
  focus_tracks = {4, 2},
  on_cycle = "vary",
  intervals = {0, 5, 7, 12, 24, 36, -12, -24},
  density_range = {0.4, 0.85},

  form = {
    {name = "CLICK",  mood = "click",  bars = 8,  energy = {0.2, 0.4}, transition = "fade"},
    {name = "GROOVE", mood = "groove", bars = 16, energy = {0.4, 0.7}, transition = "push"},
    {name = "SMASH",  mood = "smash",  bars = 12, energy = {0.8, 1.0}, transition = "cut"},
    {name = "BREAK",  mood = "break_", bars = 6,  energy = {0.5, 0.3}, transition = "cut"},
    {name = "SMASH2", mood = "smash",  bars = 10, energy = {0.85, 1.0},transition = "cut"},
    {name = "FADE",   mood = "fade",   bars = 8,  energy = {0.4, 0.1}, transition = "fade"},
  },

  moods = {
    click = function(evo, tracks, progress, energy)
      -- start with short weird loops
      steer_all(evo, tracks, {10, 12, 11, 7}, 0.05)

      evo.sweep_toward("t4_cutoff", 4000 + progress * 2000, 0.02)
      evo.sweep_toward("t4_gate", 0.15, 0.03)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1,4), "velocity_drift")
      end
    end,
    groove = function(evo, tracks, progress, energy)
      -- LOCK to 16: the pocket. everyone on the grid.
      steer_all(evo, tracks, {16, 16, 16, 16}, 0.08)

      evo.sweep_toward("t4_cutoff", 5000 + progress * 3000, 0.02)
      evo.sweep_toward("t2_cutoff", 500 + progress * 800, 0.02)
      evo.sweep_toward("t2_accent", 0.5 + progress * 0.3, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 4, "thicken")
      end
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 4, "accent")
      end
    end,
    smash = function(evo, tracks, progress, energy)
      -- stay locked but dense
      steer_all(evo, tracks, {16, 16, 16, 16}, 0.06)

      evo.sweep_toward("t4_cutoff", 10000, 0.03)
      evo.sweep_toward("t2_cutoff", 1500 + progress * 3000, 0.02)
      evo.sweep_toward("t2_res", 0.7 + progress * 0.15, 0.02)
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, math.random(1,4), "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, 4, "rotate", {n = 1})
      end
    end,
    break_ = function(evo, tracks, progress, energy)
      -- BREAK: scatter to wild short lengths
      steer_all(evo, tracks, {5, 7, 6, 4}, 0.12)

      if math.random() < 0.2 then
        evo.pattern_mutate(tracks, math.random(1,4), "thin")
      end
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1,4), "rotate",
          {n = math.random(-3, 3)})
      end
      evo.sweep_toward("t4_cutoff", 5000, 0.03)
      evo.sweep_toward("t2_cutoff", 600, 0.03)
    end,
    fade = function(evo, tracks, progress, energy)
      -- drift back to natural short loops
      steer_all(evo, tracks, {10, 13, 11, 8}, 0.04)

      evo.sweep_toward("t4_cutoff", 3000 - progress * 1500, 0.03)
      evo.sweep_toward("t2_cutoff", 400, 0.03)
      evo.sweep_toward("reverb_mix", 0.4, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1,4), "ghost")
      end
    end,
  },
}

-- ======================================================================
-- 5. ATEMPORAL — The Formless
-- track lengths drift freely, no target — pure stochastic movement
-- ======================================================================
P[5] = {
  name = "ATEMPORAL",
  desc = "formless drift",
  tick_speed = 1,
  ticks_per_bar = 2,
  focus_tracks = {1, 2, 3, 4},
  atemporal = true,
  on_cycle = "vary",
  intervals = {0, 2, 3, 5, 7, 10, 12, 14, 19, 24, -5, -7, -12},
  density_range = {0.25, 0.65},

  form = {
    {name = "NEBULA",   mood = "nebula",   bars = 48, bars_range = {32, 80},  energy = {0.15, 0.5},  transition = "fade"},
    {name = "CURRENT",  mood = "current",  bars = 36, bars_range = {24, 64},  energy = {0.3, 0.75},  transition = "fade"},
    {name = "ERUPTION", mood = "eruption", bars = 28, bars_range = {16, 48},  energy = {0.5, 0.95},  transition = "fade"},
    {name = "HOLLOW",   mood = "hollow",   bars = 56, bars_range = {40, 96},  energy = {0.6, 0.1},   transition = "fade"},
    {name = "SPORE",    mood = "spore",    bars = 44, bars_range = {28, 72},  energy = {0.1, 0.45},  transition = "fade"},
    {name = "TIDE",     mood = "tide",     bars = 40, bars_range = {24, 80},  energy = {0.2, 0.7},   transition = "fade"},
  },

  moods = {
    nebula = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      -- lengths drift randomly: extend or truncate with equal probability
      if math.random() < 0.06 then
        local t = math.random(1, 4)
        if math.random() < 0.5 then
          evo.pattern_mutate(tracks, t, "extend", {scale_notes = sc})
        else
          evo.pattern_mutate(tracks, t, "truncate")
        end
      end
      -- note changes
      if #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1,4), "replace_one", {scale_notes = sc})
      end
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, math.random(1,4), "velocity_drift")
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1,4), "rotate", {n = ({1,-1})[math.random(2)]})
      end
      if math.random() < 0.03 then
        evo.pattern_mutate(tracks, math.random(1,3), "shift",
          {interval = ({2, 5, 7, -5, -7, 12, -12})[math.random(7)]})
      end
      evo.sweep_toward("t1_spread", 0.3 + energy * 0.5, 0.008)
      evo.sweep_toward("t1_brightness", 0.2 + energy * 0.5, 0.008)
      evo.sweep_toward("t3_morph", 0.2 + math.sin(progress * 3.7) * 0.3, 0.01)
      evo.sweep_toward("reverb_mix", 0.25 + energy * 0.3, 0.008)
      for i = 1, 4 do
        local pre = "t" .. i .. "_"
        local ok, cur = pcall(function() return params:get(pre .. "cutoff") end)
        if ok then evo.sweep_toward(pre .. "cutoff", cur * (1 + (math.random()-0.5)*0.02), 0.008) end
      end
    end,

    current = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      -- lengths tend toward medium polymetric
      steer_all(evo, tracks, {13, 16, 11, 9}, 0.04)

      if math.random() < 0.15 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1,4), "replace_one", {scale_notes = sc})
      end
      if math.random() < 0.08 then evo.pattern_mutate(tracks, 2, "rotate", {n = 1}) end
      if math.random() < 0.05 then evo.pattern_mutate(tracks, 3, "rotate", {n = -1}) end
      if math.random() < 0.06 then evo.pattern_mutate(tracks, 4, "rotate", {n = ({1,2,-1})[math.random(3)]}) end
      if math.random() < 0.07 * energy then evo.pattern_mutate(tracks, math.random(1,4), "thicken") end
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(1,3), "shift",
          {interval = ({2, 5, 7, -5, -7, 12})[math.random(6)]})
      end
      local wave = math.sin(progress * 5.3) * 0.5 + 0.5
      evo.sweep_toward("t2_cutoff", 400 + (energy * wave) * 3000, 0.015)
      evo.sweep_toward("t2_accent", 0.3 + energy * wave * 0.5, 0.015)
      evo.sweep_toward("t3_cutoff", 3000 + energy * 5000, 0.01)
    end,

    eruption = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      -- no length steering: let the conductor go wild
      if math.random() < 0.1 and #sc > 0 then
        evo.generate_pattern(tracks, math.random(1,4), sc, 0.4 + energy * 0.4, 0.5, 1.0)
      end
      if math.random() < 0.15 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1,4), "replace_one", {scale_notes = sc})
      end
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(1,4), "rotate", {n = math.random(-3, 3)})
      end
      if math.random() < 0.06 then
        pcall(function() params:set("t4_engine", math.random(1, 4)) end)
      end
      if math.random() < 0.1 then evo.pattern_mutate(tracks, math.random(1,4), "accent") end
      if math.random() < 0.12 then
        evo.sweep_toward("t2_cutoff", 2000 + math.random() * 6000, 0.06)
        evo.sweep_toward("t2_accent", 0.7 + math.random() * 0.3, 0.06)
      end
      evo.sweep_toward("t2_res", 0.6 + energy * 0.25, 0.02)
      evo.sweep_toward("t3_morph", 0.5 + energy * 0.4, 0.02)
      evo.sweep_toward("t1_cutoff", 3000 + energy * 6000, 0.02)
      evo.sweep_toward("reverb_mix", 0.15, 0.02)
    end,

    hollow = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      -- lengths shrink as things empty out
      steer_all(evo, tracks, {8, 10, 7, 5}, 0.05)

      if math.random() < 0.1 then evo.pattern_mutate(tracks, math.random(1,4), "thin") end
      if math.random() < 0.08 then evo.pattern_mutate(tracks, math.random(1,4), "ghost") end
      if math.random() < 0.05 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1,3), "replace_one", {scale_notes = sc})
      end
      if math.random() < 0.03 then
        evo.pattern_mutate(tracks, math.random(1,4), "shift",
          {interval = ({12, -12, 7, -7})[math.random(4)]})
      end
      for i = 1, 4 do
        local pre = "t" .. i .. "_"
        local ok, cur = pcall(function() return params:get(pre .. "cutoff") end)
        if ok then evo.sweep_toward(pre .. "cutoff", cur * 0.995, 0.01) end
      end
      evo.sweep_toward("reverb_mix", 0.35 + (1 - energy) * 0.3, 0.01)
      evo.sweep_toward("t1_gate", 0.9, 0.01)
    end,

    spore = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      -- very short, minimal
      steer_all(evo, tracks, {6, 8, 5, 4}, 0.04)

      if math.random() < 0.08 then evo.pattern_mutate(tracks, math.random(2,4), "thin") end
      if math.random() < 0.05 then
        evo.pattern_mutate(tracks, ({1,3})[math.random(2)], "thicken", {count = 1})
      end
      if math.random() < 0.08 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1,3), "replace_one", {scale_notes = sc})
      end
      if math.random() < 0.1 then evo.pattern_mutate(tracks, math.random(1,4), "velocity_drift") end
      evo.sweep_toward("t1_cutoff", 1500 + energy * 2500, 0.008)
      evo.sweep_toward("reverb_mix", 0.45, 0.01)
      evo.sweep_toward("reverb_room", 0.85, 0.006)
    end,

    tide = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      -- lengths follow the wave: expand at peaks, contract at troughs
      local wave1 = math.sin(progress * 4.1) * 0.3
      local composite = util.clamp(energy + wave1, 0.05, 0.95)

      local base = math.floor(8 + composite * 12) -- 8-20
      steer_all(evo, tracks, {base, base+2, base-1, base-3}, 0.05)

      if composite > 0.65 then
        if math.random() < 0.1 then evo.pattern_mutate(tracks, math.random(1,4), "thicken") end
        if math.random() < 0.08 then evo.pattern_mutate(tracks, math.random(1,4), "accent") end
      elseif composite < 0.35 then
        if math.random() < 0.08 then evo.pattern_mutate(tracks, math.random(1,4), "thin") end
        if math.random() < 0.06 then evo.pattern_mutate(tracks, math.random(1,4), "ghost") end
      end
      if math.random() < 0.1 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1,4), "replace_one", {scale_notes = sc})
      end
      if math.random() < 0.05 then
        evo.pattern_mutate(tracks, math.random(1,4), "rotate", {n = ({1,-1,2,-2})[math.random(4)]})
      end
      if composite > 0.8 and math.random() < 0.05 and #sc > 0 then
        evo.generate_pattern(tracks, math.random(1,4), sc, 0.4 + composite * 0.3, 0.4, 0.9)
      end
      evo.sweep_toward("t1_cutoff", 1500 + composite * 5000, 0.01)
      evo.sweep_toward("t2_cutoff", 400 + composite * 3000, 0.01)
      evo.sweep_toward("t3_cutoff", 2000 + composite * 5000, 0.01)
      evo.sweep_toward("t4_cutoff", 3000 + composite * 5000, 0.01)
      evo.sweep_toward("t2_accent", 0.3 + composite * 0.5, 0.012)
      evo.sweep_toward("t3_morph", 0.2 + composite * 0.5, 0.01)
      evo.sweep_toward("reverb_mix", 0.2 + (1 - composite) * 0.3, 0.008)
    end,
  },
}

return P
