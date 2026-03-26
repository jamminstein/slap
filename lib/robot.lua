-- robot.lua
-- pixel art conductor avatars for slap
-- 6 named conductors, each a musical madman
-- visual style + conducting behavior (action weights for maestro)

local robot = {}

-- ======== CONDUCTOR PROFILES ========
-- each conductor has:
--   personality: which song form drives the autonomous mode
--   conducting_style: weighted actions for the maestro system
--   intensity_range: how active they are {min, max}
--   visual: head/eyes/mouth/feat for the avatar

robot.profiles = {
  -- MONONEON: unpredictable virtuoso, wild jumps, weird lengths
  -- rides cutoffs wildly, morph all over, engine switches
  {
    name = "MONONEON", desc = "unpredictable virtuoso",
    personality = 5,
    head = "square", eyes = "cross", mouth = "zigzag", feat = "sparks",
    intensity_range = {0.6, 0.95}, harmony_set = "chaos", harmony_chance = 0.06, home_tendency = 0.01,
    default_timbre = 0, default_divisions = {1,2,2,1},
    default_mods = {0.4, 0.5, 0.3, 0.6, 0.3, 0.4},
    style = {
      replace_one = 0.15, velocity_drift = 0.10, rotate = 0.15,
      thicken = 0.08, thin = 0.08, shift = 0.15,
      extend = 0.10, truncate = 0.10, accent = 0.05, ghost = 0.04,
    },
    knobs = {
      {param="t1_cutoff", weight=0.7, range={200, 10000}, mode="jump"},
      {param="t2_cutoff", weight=0.8, range={100, 8000},  mode="jump"},
      {param="t3_cutoff", weight=0.7, range={500, 12000}, mode="jump"},
      {param="t3_morph",  weight=0.9, range={0, 1},       mode="jump"},
      {param="t3_fmamt",  weight=0.6, range={0, 0.8},     mode="drift"},
      {param="t4_cutoff", weight=0.6, range={2000, 12000}, mode="jump"},
      {param="t2_accent", weight=0.7, range={0.2, 1},     mode="jump"},
      {param="t1_spread", weight=0.5, range={0, 1},       mode="drift"},
      {param="reverb_mix",weight=0.3, range={0.1, 0.6},   mode="drift"},
      -- bezier route depths: conductor picks these up after user lets go
      {param="mod_1",     weight=0.4, range={0, 0.8},     mode="jump"},
      {param="mod_2",     weight=0.5, range={0, 0.8},     mode="jump"},
      {param="mod_3",     weight=0.4, range={0, 0.7},     mode="jump"},
      {param="mod_4",     weight=0.5, range={0, 0.6},     mode="drift"},
      {param="mod_5",     weight=0.3, range={0, 0.7},     mode="jump"},
      {param="mod_6",     weight=0.3, range={0, 0.5},     mode="drift"},
    },
  },
  -- THUNDERCAT: jazzy, complex harmonies, dreamy, virtuosic
  -- smooth cutoff rides, morph for color, reverb for space
  {
    name = "THUNDERCAT", desc = "jazzy dreamer",
    personality = 3,
    head = "pill", eyes = "round", mouth = "smile", feat = "ears",
    intensity_range = {0.45, 0.8}, harmony_set = "jazz", harmony_chance = 0.05, home_tendency = 0.02,
    default_timbre = 3, default_divisions = {3,2,2,2},
    default_mods = {0.2, 0.3, 0.4, 0.5, 0.2, 0.1},
    style = {
      replace_one = 0.30, velocity_drift = 0.20, rotate = 0.05,
      thicken = 0.12, thin = 0.05, shift = 0.12,
      extend = 0.03, truncate = 0.02, accent = 0.06, ghost = 0.05,
    },
    knobs = {
      {param="t3_cutoff", weight=0.8, range={1000, 10000}, mode="drift"},
      {param="t3_morph",  weight=0.7, range={0.1, 0.8},    mode="drift"},
      {param="t3_fmamt",  weight=0.5, range={0, 0.5},      mode="drift"},
      {param="t1_cutoff", weight=0.5, range={1500, 8000},   mode="drift"},
      {param="t1_brightness",weight=0.6,range={0.3, 0.9},   mode="drift"},
      {param="t2_cutoff", weight=0.4, range={300, 3000},    mode="drift"},
      {param="reverb_mix",weight=0.6, range={0.2, 0.5},     mode="drift"},
      {param="t3_lfoDepth",weight=0.4,range={0, 0.4},       mode="drift"},
      {param="mod_1",     weight=0.3, range={0, 0.5},     mode="drift"},
      {param="mod_3",     weight=0.4, range={0, 0.6},     mode="drift"},
      {param="mod_4",     weight=0.5, range={0, 0.5},     mode="drift"},
    },
  },
  -- THOM YORKE: angular, glitchy, emotional, sudden silences
  -- jerky cutoff moves, gate chops, reverb swells
  {
    name = "THOM YORKE", desc = "angular glitch poet",
    personality = 5,
    head = "diamond", eyes = "line", mouth = "flat", feat = "orbit",
    intensity_range = {0.4, 0.85}, harmony_set = "world", harmony_chance = 0.04, home_tendency = 0.015,
    default_timbre = 2, default_divisions = {3,2,2,1},
    default_mods = {0.3, 0.4, 0.5, 0.3, 0.2, 0.2},
    style = {
      replace_one = 0.10, velocity_drift = 0.08, rotate = 0.20,
      thicken = 0.05, thin = 0.18, shift = 0.12,
      extend = 0.05, truncate = 0.08, accent = 0.04, ghost = 0.10,
    },
    knobs = {
      {param="t1_cutoff", weight=0.5, range={500, 6000},   mode="jump"},
      {param="t2_cutoff", weight=0.6, range={200, 5000},   mode="jump"},
      {param="t3_cutoff", weight=0.7, range={800, 8000},   mode="jump"},
      {param="t4_cutoff", weight=0.5, range={1000, 10000}, mode="jump"},
      {param="t1_gate",   weight=0.4, range={0.3, 1.0},    mode="jump"},
      {param="t2_gate",   weight=0.5, range={0.1, 0.8},    mode="jump"},
      {param="t3_gate",   weight=0.4, range={0.2, 0.9},    mode="jump"},
      {param="reverb_mix",weight=0.7, range={0.1, 0.7},    mode="drift"},
      {param="t3_morph",  weight=0.4, range={0.1, 0.9},    mode="jump"},
      {param="mod_1",     weight=0.3, range={0, 0.7},     mode="jump"},
      {param="mod_2",     weight=0.3, range={0, 0.6},     mode="jump"},
      {param="mod_3",     weight=0.4, range={0, 0.8},     mode="jump"},
      {param="mod_5",     weight=0.2, range={0, 0.5},     mode="jump"},
    },
  },
  -- FLEA: punk energy, explosive, slap bass, high density
  -- rides bass cutoff + accent hard, everything loud
  {
    name = "FLEA", desc = "explosive punk funk",
    personality = 4,
    head = "circle", eyes = "round", mouth = "zigzag", feat = "antenna",
    intensity_range = {0.65, 0.95}, harmony_set = "minimal", harmony_chance = 0.02, home_tendency = 0.03,
    default_timbre = 4, default_divisions = {2,2,2,1},
    default_mods = {0.1, 0.5, 0.2, 0.1, 0.4, 0.1},
    style = {
      replace_one = 0.10, velocity_drift = 0.05, rotate = 0.08,
      thicken = 0.25, thin = 0.03, shift = 0.08,
      extend = 0.06, truncate = 0.02, accent = 0.25, ghost = 0.08,
    },
    knobs = {
      {param="t2_cutoff", weight=0.9, range={300, 10000},  mode="jump"},
      {param="t2_accent", weight=0.9, range={0.5, 1.0},    mode="jump"},
      {param="t2_res",    weight=0.7, range={0.3, 0.9},    mode="drift"},
      {param="t4_cutoff", weight=0.8, range={3000, 12000}, mode="jump"},
      {param="t2_gate",   weight=0.5, range={0.15, 0.6},   mode="jump"},
      {param="t1_cutoff", weight=0.4, range={2000, 8000},  mode="drift"},
      {param="reverb_mix",weight=0.2, range={0.05, 0.3},   mode="drift"},
      {param="mod_2",     weight=0.3, range={0, 0.5},     mode="jump"},
      {param="mod_5",     weight=0.4, range={0, 0.6},     mode="jump"},
    },
  },
  -- BOOTSY COLLINS: the ONE, deep pocket, space funk, groove master
  -- subtle filter rides, reverb for space, everything smooth
  {
    name = "BOOTSY", desc = "space funk groove",
    personality = 2,
    head = "pill", eyes = "round", mouth = "smile", feat = "halo",
    intensity_range = {0.35, 0.7}, harmony_set = "classical", harmony_chance = 0.03, home_tendency = 0.04,
    default_timbre = 3, default_divisions = {3,2,2,2},
    default_mods = {0.2, 0.4, 0.2, 0.15, 0.2, 0.1},
    style = {
      replace_one = 0.08, velocity_drift = 0.30, rotate = 0.05,
      thicken = 0.05, thin = 0.05, shift = 0.05,
      extend = 0.02, truncate = 0.02, accent = 0.15, ghost = 0.23,
    },
    knobs = {
      {param="t2_cutoff", weight=0.7, range={300, 3000},   mode="drift"},
      {param="t2_accent", weight=0.5, range={0.3, 0.8},    mode="drift"},
      {param="t1_cutoff", weight=0.4, range={1500, 5000},  mode="drift"},
      {param="t1_spread", weight=0.3, range={0.2, 0.6},    mode="drift"},
      {param="reverb_mix",weight=0.6, range={0.2, 0.5},    mode="drift"},
      {param="t3_cutoff", weight=0.3, range={2000, 6000},  mode="drift"},
      {param="t4_cutoff", weight=0.4, range={3000, 8000},  mode="drift"},
      {param="mod_1",     weight=0.2, range={0, 0.4},     mode="drift"},
      {param="mod_2",     weight=0.3, range={0, 0.4},     mode="drift"},
      {param="mod_4",     weight=0.2, range={0, 0.3},     mode="drift"},
    },
  },
  -- HERMETO PASCOAL: complete madman genius, uses everything
  -- rides EVERYTHING: all cutoffs, morph, FM, accent, gates, engine, reverb
  {
    name = "HERMETO", desc = "total genius madman",
    personality = 5,
    head = "circle", eyes = "cross", mouth = "smile", feat = "sparks",
    intensity_range = {0.7, 0.99}, harmony_set = "chaos", harmony_chance = 0.08, home_tendency = 0.005,
    default_timbre = 0, default_divisions = {3,2,2,1},
    default_mods = {0.5, 0.6, 0.5, 0.7, 0.4, 0.5},
    style = {
      replace_one = 0.15, velocity_drift = 0.08, rotate = 0.12,
      thicken = 0.10, thin = 0.10, shift = 0.12,
      extend = 0.10, truncate = 0.08, accent = 0.08, ghost = 0.07,
    },
    knobs = {
      {param="t1_cutoff",    weight=0.7, range={200, 10000}, mode="jump"},
      {param="t2_cutoff",    weight=0.8, range={100, 10000}, mode="jump"},
      {param="t3_cutoff",    weight=0.7, range={300, 12000}, mode="jump"},
      {param="t4_cutoff",    weight=0.6, range={1000, 12000},mode="jump"},
      {param="t1_spread",    weight=0.5, range={0, 1},       mode="jump"},
      {param="t1_brightness",weight=0.5, range={0.1, 1},     mode="jump"},
      {param="t2_accent",    weight=0.8, range={0, 1},       mode="jump"},
      {param="t2_res",       weight=0.6, range={0.2, 0.9},   mode="drift"},
      {param="t3_morph",     weight=0.8, range={0, 1},       mode="jump"},
      {param="t3_fmamt",     weight=0.7, range={0, 0.8},     mode="jump"},
      {param="t3_lfoRate",   weight=0.4, range={0.5, 15},    mode="jump"},
      {param="t4_pwm",       weight=0.5, range={0.1, 0.9},   mode="jump"},
      {param="t4_bits",      weight=0.4, range={4, 16},      mode="jump"},
      {param="t1_gate",      weight=0.4, range={0.2, 1.0},   mode="jump"},
      {param="t2_gate",      weight=0.5, range={0.1, 0.8},   mode="jump"},
      {param="t3_gate",      weight=0.4, range={0.2, 0.9},   mode="drift"},
      {param="t4_gate",      weight=0.4, range={0.05, 0.4},  mode="jump"},
      {param="reverb_mix",   weight=0.5, range={0.05, 0.6},  mode="jump"},
      -- hermeto rides ALL mod routes
      {param="mod_1",        weight=0.5, range={0, 0.9},     mode="jump"},
      {param="mod_2",        weight=0.5, range={0, 0.9},     mode="jump"},
      {param="mod_3",        weight=0.5, range={0, 0.8},     mode="jump"},
      {param="mod_4",        weight=0.6, range={0, 0.7},     mode="jump"},
      {param="mod_5",        weight=0.4, range={0, 0.8},     mode="jump"},
      {param="mod_6",        weight=0.4, range={0, 0.6},     mode="jump"},
    },
  },
  -- DAFT PUNK: the machine. ultra tight 4/4, locked lengths,
  -- ghost notes for groove, pitch variety for interest, no chaos.
  -- the opposite of HERMETO: disciplined, repetitive, hypnotic.
  {
    name = "DAFT PUNK", desc = "tight machine groove",
    personality = 2,
    head = "square", eyes = "line", mouth = "flat", feat = "antenna",
    intensity_range = {0.15, 0.35}, harmony_set = "minimal", harmony_chance = 0.01, home_tendency = 0.10,
    default_timbre = 3, default_divisions = {2,2,2,2},
    default_mods = {0.1, 0.25, 0.15, 0.05, 0.15, 0.05},
    style = {
      -- mostly ghost notes + velocity. very little pattern change.
      replace_one = 0.08, velocity_drift = 0.25, rotate = 0.0,
      thicken = 0.03, thin = 0.02, shift = 0.02,
      extend = 0.0, truncate = 0.0, accent = 0.15, ghost = 0.35,
      crescendo = 0.05, decrescendo = 0.05,
    },
    knobs = {
      -- tight filter movements, nothing wild
      {param="t2_cutoff", weight=0.6, range={400, 4000},   mode="drift"},
      {param="t2_accent", weight=0.5, range={0.4, 0.9},    mode="drift"},
      {param="t2_res",    weight=0.4, range={0.4, 0.8},    mode="drift"},
      {param="t4_cutoff", weight=0.5, range={4000, 10000}, mode="drift"},
      {param="t3_cutoff", weight=0.4, range={2000, 7000},  mode="drift"},
      {param="t1_cutoff", weight=0.3, range={2000, 6000},  mode="drift"},
      {param="t3_morph",  weight=0.3, range={0.2, 0.6},    mode="drift"},
      {param="reverb_mix",weight=0.2, range={0.1, 0.3},    mode="drift"},
      -- subtle mod routing
      {param="mod_2",     weight=0.3, range={0, 0.3},      mode="drift"},
      {param="mod_5",     weight=0.2, range={0, 0.2},      mode="drift"},
    },
    -- special flag: forces all tracks to 16 steps
    lock_16 = true, requantize = true,
  },
  -- KRAFTWERK: the original machine. minimal, precise, robotic.
  -- almost nothing changes. when it does, it's one note. hypnotic.
  {
    name = "KRAFTWERK", desc = "minimal machine",
    personality = 2, lock_16 = true, requantize = true,
    head = "square", eyes = "dot", mouth = "flat", feat = "antenna",
    intensity_range = {0.05, 0.2}, harmony_set = "minimal", harmony_chance = 0.005, home_tendency = 0.12,
    default_timbre = 3, default_divisions = {3,2,2,2},
    default_mods = {0.1, 0.15, 0.1, 0.05, 0.1, 0.05},
    style = {
      replace_one = 0.15, velocity_drift = 0.10, rotate = 0.0,
      thicken = 0.02, thin = 0.05, shift = 0.03,
      extend = 0.0, truncate = 0.0, accent = 0.05, ghost = 0.60,
    },
    knobs = {
      {param="t2_cutoff", weight=0.3, range={300, 2000},   mode="drift"},
      {param="t3_cutoff", weight=0.2, range={1500, 4000},  mode="drift"},
      {param="t4_cutoff", weight=0.2, range={3000, 6000},  mode="drift"},
      {param="reverb_mix",weight=0.1, range={0.05, 0.2},   mode="drift"},
    },
  },
  -- LARRY HEARD: deep house warmth. full patterns, smooth filter sweeps,
  -- ghost notes for groove, bass emphasis, lush pads.
  {
    name = "MR FINGERS", desc = "deep house warmth",
    personality = 2, lock_16 = true, requantize = true,
    head = "circle", eyes = "round", mouth = "smile", feat = "halo",
    intensity_range = {0.25, 0.55}, harmony_set = "classical", harmony_chance = 0.03, home_tendency = 0.05,
    default_timbre = 3, default_divisions = {3,2,2,2},
    default_mods = {0.25, 0.35, 0.3, 0.2, 0.15, 0.1},
    style = {
      replace_one = 0.15, velocity_drift = 0.20, rotate = 0.03,
      thicken = 0.10, thin = 0.03, shift = 0.08,
      extend = 0.0, truncate = 0.0, accent = 0.12, ghost = 0.29,
    },
    knobs = {
      {param="t2_cutoff", weight=0.7, range={400, 5000},   mode="drift"},
      {param="t2_accent", weight=0.5, range={0.3, 0.7},    mode="drift"},
      {param="t1_cutoff", weight=0.5, range={2000, 8000},  mode="drift"},
      {param="t1_spread", weight=0.4, range={0.3, 0.7},    mode="drift"},
      {param="t1_brightness",weight=0.3,range={0.4, 0.8},  mode="drift"},
      {param="t3_cutoff", weight=0.4, range={2000, 7000},  mode="drift"},
      {param="t3_morph",  weight=0.3, range={0.2, 0.5},    mode="drift"},
      {param="reverb_mix",weight=0.4, range={0.15, 0.4},   mode="drift"},
      {param="mod_1",     weight=0.3, range={0, 0.3},      mode="drift"},
      {param="mod_3",     weight=0.2, range={0, 0.3},      mode="drift"},
    },
  },
  -- BURIAL: dark 2-step, ghostly, thin patterns that breathe,
  -- heavy ghost notes, low cutoffs, shuffled feel
  {
    name = "BURIAL", desc = "dark ghost step",
    personality = 4, lock_16 = true, requantize = true,
    head = "diamond", eyes = "dot", mouth = "none", feat = "drip",
    intensity_range = {0.3, 0.65}, harmony_set = "world", harmony_chance = 0.03, home_tendency = 0.03,
    default_timbre = 4, default_divisions = {3,2,2,2},
    default_mods = {0.2, 0.3, 0.3, 0.2, 0.25, 0.15},
    style = {
      replace_one = 0.10, velocity_drift = 0.15, rotate = 0.05,
      thicken = 0.05, thin = 0.12, shift = 0.05,
      extend = 0.0, truncate = 0.0, accent = 0.08, ghost = 0.40,
    },
    knobs = {
      {param="t1_cutoff", weight=0.4, range={800, 3000},   mode="drift"},
      {param="t2_cutoff", weight=0.5, range={200, 2000},   mode="drift"},
      {param="t3_cutoff", weight=0.5, range={500, 3000},   mode="drift"},
      {param="t4_cutoff", weight=0.4, range={2000, 6000},  mode="drift"},
      {param="t1_spread", weight=0.3, range={0.3, 0.8},    mode="drift"},
      {param="reverb_mix",weight=0.6, range={0.25, 0.55},  mode="drift"},
      {param="reverb_room",weight=0.3,range={0.5, 0.9},    mode="drift"},
      {param="t3_morph",  weight=0.3, range={0.1, 0.4},    mode="drift"},
    },
  },
  -- APHEX TWIN: precise IDM. complex but locked. surprising notes,
  -- angular pitch choices, tight gate control, controlled chaos.
  {
    name = "APHEX", desc = "precise IDM",
    personality = 3, lock_16 = true, requantize = true,
    head = "circle", eyes = "round", mouth = "smile", feat = "sparks",
    intensity_range = {0.35, 0.7}, harmony_set = "jazz", harmony_chance = 0.05, home_tendency = 0.025,
    default_timbre = 2, default_divisions = {2,2,2,1},
    default_mods = {0.3, 0.4, 0.5, 0.6, 0.3, 0.3},
    style = {
      replace_one = 0.30, velocity_drift = 0.10, rotate = 0.08,
      thicken = 0.07, thin = 0.07, shift = 0.15,
      extend = 0.0, truncate = 0.0, accent = 0.10, ghost = 0.13,
    },
    knobs = {
      {param="t2_cutoff", weight=0.6, range={200, 8000},   mode="jump"},
      {param="t3_cutoff", weight=0.7, range={500, 10000},  mode="jump"},
      {param="t3_morph",  weight=0.6, range={0, 0.8},      mode="jump"},
      {param="t3_fmamt",  weight=0.5, range={0, 0.6},      mode="jump"},
      {param="t4_cutoff", weight=0.5, range={2000, 12000}, mode="jump"},
      {param="t4_pwm",    weight=0.4, range={0.1, 0.9},    mode="jump"},
      {param="t2_gate",   weight=0.4, range={0.1, 0.6},    mode="jump"},
      {param="t3_gate",   weight=0.4, range={0.15, 0.7},   mode="jump"},
      {param="reverb_mix",weight=0.3, range={0.1, 0.35},   mode="drift"},
      {param="mod_3",     weight=0.3, range={0, 0.5},      mode="jump"},
      {param="mod_4",     weight=0.4, range={0, 0.4},      mode="jump"},
    },
  },
  -- JEFF MILLS: minimal techno. relentless, sparse, hypnotic.
  -- strips everything down, then adds one thing back. repeat.
  {
    name = "JEFF MILLS", desc = "minimal relentless",
    personality = 4, lock_16 = true, requantize = true,
    head = "square", eyes = "line", mouth = "flat", feat = "orbit",
    intensity_range = {0.2, 0.5}, harmony_set = "minimal", harmony_chance = 0.01, home_tendency = 0.07,
    default_timbre = 8, default_divisions = {3,2,2,2},
    default_mods = {0.1, 0.2, 0.15, 0.05, 0.15, 0.05},
    style = {
      replace_one = 0.08, velocity_drift = 0.12, rotate = 0.05,
      thicken = 0.08, thin = 0.20, shift = 0.02,
      extend = 0.0, truncate = 0.0, accent = 0.15, ghost = 0.30,
    },
    knobs = {
      {param="t2_cutoff", weight=0.5, range={200, 3000},   mode="drift"},
      {param="t4_cutoff", weight=0.6, range={3000, 8000},  mode="drift"},
      {param="t2_accent", weight=0.4, range={0.3, 0.7},    mode="drift"},
      {param="t1_cutoff", weight=0.2, range={1000, 4000},  mode="drift"},
      {param="reverb_mix",weight=0.2, range={0.05, 0.25},  mode="drift"},
    },
  },
}

robot.NAMES = {}
for i, p in ipairs(robot.profiles) do robot.NAMES[i] = p.name end

-- ======== ANIMATION STATE ========

local blink_timer = 0
local blink_on = false
local idle_t = 0
local beat_flash = 0

function robot.update(dt)
  idle_t = idle_t + dt
  blink_timer = blink_timer + dt
  if blink_on then
    if blink_timer > 0.1 then blink_on = false; blink_timer = 0 end
  else
    if blink_timer > (2.5 + math.random() * 3) then blink_on = true; blink_timer = 0 end
  end
  beat_flash = beat_flash * 0.82
end

function robot.beat()
  beat_flash = 1
end

-- ======== DRAWING ========

function robot.draw(idx, cx, cy, energy, active)
  local p = robot.profiles[idx]
  if not p then return end

  local e = energy or 0.5
  local bright = active and 15 or 7

  -- beat glow
  if active and beat_flash > 0.15 then
    screen.level(math.floor(beat_flash * 5))
    local gr = 13 + beat_flash * 4
    screen.rect(cx - gr, cy - 4 - gr, gr * 2, gr * 2)
    screen.fill()
  end

  -- HEAD
  screen.level(bright)
  if p.head == "circle" then
    screen.circle(cx, cy - 4, 9 + e); screen.fill()
  elseif p.head == "square" then
    local s = 8 + e
    local jx = active and (math.random() < 0.15 and math.random(-1, 1) or 0) or 0
    screen.rect(cx - s + jx, cy - 4 - s, s * 2, s * 2); screen.fill()
  elseif p.head == "diamond" then
    local s = 9 + e
    screen.move(cx, cy-4-s); screen.line(cx+s, cy-4)
    screen.line(cx, cy-4+s); screen.line(cx-s, cy-4)
    screen.close(); screen.fill()
  elseif p.head == "pill" then
    local w = 11 + e; local h = 7 + e * 0.5
    screen.rect(cx-w, cy-4-h, w*2, h*2); screen.fill()
  end

  -- EYES
  screen.level(0)
  local ey = cy - 6; local el = cx - 4; local er = cx + 4

  if blink_on then
    screen.move(el-2, ey); screen.line(el+2, ey); screen.stroke()
    screen.move(er-2, ey); screen.line(er+2, ey); screen.stroke()
  elseif p.eyes == "round" then
    local r = 1.5 + e * 0.5
    screen.circle(el, ey, r); screen.fill()
    screen.circle(er, ey, r); screen.fill()
  elseif p.eyes == "dot" then
    screen.rect(el-1, ey-1, 2, 2); screen.fill()
    screen.rect(er-1, ey-1, 2, 2); screen.fill()
  elseif p.eyes == "line" then
    local w = 2 + e
    screen.move(el-w, ey); screen.line(el+w, ey); screen.stroke()
    screen.move(er-w, ey); screen.line(er+w, ey); screen.stroke()
  elseif p.eyes == "cross" then
    local s = 1.5 + e * 0.3
    screen.move(el-s, ey-s); screen.line(el+s, ey+s); screen.stroke()
    screen.move(el+s, ey-s); screen.line(el-s, ey+s); screen.stroke()
    screen.move(er-s, ey-s); screen.line(er+s, ey+s); screen.stroke()
    screen.move(er+s, ey-s); screen.line(er-s, ey+s); screen.stroke()
  elseif p.eyes == "arrow" then
    screen.move(el, ey-2); screen.line(el-2, ey+1); screen.line(el+2, ey+1)
    screen.close(); screen.fill()
    screen.move(er, ey-2); screen.line(er-2, ey+1); screen.line(er+2, ey+1)
    screen.close(); screen.fill()
  end

  -- MOUTH
  screen.level(0)
  local my = cy - 1
  if p.mouth == "smile" then
    local w = 2 + e * 1.5
    screen.move(cx-w, my); screen.line(cx, my+1+e); screen.line(cx+w, my); screen.stroke()
  elseif p.mouth == "flat" then
    local w = 3 + e
    screen.move(cx-w, my); screen.line(cx+w, my); screen.stroke()
  elseif p.mouth == "dot" then
    screen.rect(cx-1, my-1, 2, 2); screen.fill()
  elseif p.mouth == "zigzag" then
    local w = 3 + e
    screen.move(cx-w, my); screen.line(cx-w*0.3, my+2)
    screen.line(cx+w*0.3, my-1); screen.line(cx+w, my); screen.stroke()
  end

  -- FEATURE
  screen.level(active and 12 or 4)
  if p.feat == "antenna" then
    local bob = math.sin(idle_t * 2) * 1.5
    local top = cy - 15 - e + bob
    screen.move(cx, cy-13-e); screen.line(cx, top); screen.stroke()
    screen.circle(cx, top-1, 1.5); screen.fill()
  elseif p.feat == "ears" then
    local s = 10 + e
    screen.move(cx-s, cy-6); screen.line(cx-s-3, cy-12); screen.stroke()
    screen.move(cx+s, cy-6); screen.line(cx+s+3, cy-12); screen.stroke()
  elseif p.feat == "sparks" then
    if active then
      for _ = 1, math.floor(2 + e * 4) do
        screen.pixel(cx + math.random(-14, 14), cy-4 + math.random(-14, 10))
        screen.fill()
      end
    end
  elseif p.feat == "halo" then
    local yb = math.sin(idle_t) * 1.5
    screen.circle(cx, cy-16-e+yb, 4); screen.stroke()
  elseif p.feat == "drip" then
    local dy = (idle_t * 6) % 10
    screen.move(cx, cy+5+e); screen.line(cx, cy+5+e+dy); screen.stroke()
    screen.circle(cx, cy+6+e+dy, 1); screen.fill()
  elseif p.feat == "orbit" then
    local r = 12 + e * 3
    for oi = 1, 3 do
      local speed = ({0.7, 1.3, 2.1})[oi]
      local offset = ({0, 2.2, 4.5})[oi]
      local ox = cx + math.cos(idle_t * speed + offset) * r
      local oy = cy - 4 + math.sin(idle_t * speed + offset) * (r * 0.6)
      screen.circle(ox, oy, 1.5 - oi * 0.3); screen.fill()
    end
  end
end

return robot
