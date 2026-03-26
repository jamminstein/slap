-- bezier_mod.lua
-- organic modulation: 3 bezier curves + complex LFO
-- cross-modulation between curves for evolving textures

local bezier_mod = {}

local function cubic_bezier(p0, p1, p2, p3, t)
  local u = 1 - t
  return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
end

local function rand_point(tension)
  return (math.random() * 2 - 1) * tension
end

local function new_generator(speed, tension, range_lo, range_hi)
  local gen = {
    p0 = 0, p1 = rand_point(tension),
    p2 = rand_point(tension), p3 = rand_point(tension),
    t = 0, speed = speed, base_speed = speed,
    tension = tension, base_tension = tension,
    value = 0,
    range_lo = range_lo or -1, range_hi = range_hi or 1,
    xmod_speed = 0, xmod_tension = 0, xmod_range = 0,
    history = {}, hist_idx = 1, hist_size = 64,
  }
  for i = 1, gen.hist_size do gen.history[i] = 0 end
  return gen
end

local function update_generator(gen, dt, mod_value)
  local effective_speed = gen.base_speed
  if gen.xmod_speed > 0 and mod_value then
    effective_speed = effective_speed * (1 + mod_value * gen.xmod_speed * 2)
    effective_speed = math.max(0.01, effective_speed)
  end
  gen.speed = effective_speed

  local effective_tension = gen.base_tension
  if gen.xmod_tension > 0 and mod_value then
    effective_tension = effective_tension + mod_value * gen.xmod_tension * 0.5
    effective_tension = math.max(0.1, math.min(1.5, effective_tension))
  end
  gen.tension = effective_tension

  gen.t = gen.t + gen.speed * dt

  while gen.t >= 1 do
    gen.t = gen.t - 1
    gen.p0 = gen.p3
    gen.p1 = gen.p0 + rand_point(gen.tension)
    gen.p2 = rand_point(gen.tension)
    gen.p3 = rand_point(gen.tension)
    gen.p3 = math.max(-1, math.min(1, gen.p3))
  end

  local raw = cubic_bezier(gen.p0, gen.p1, gen.p2, gen.p3, gen.t)
  raw = math.max(-1, math.min(1, raw))

  local lo = gen.range_lo
  local hi = gen.range_hi
  if gen.xmod_range > 0 and mod_value then
    local spread = (hi - lo) * gen.xmod_range * mod_value * 0.3
    lo = lo - spread
    hi = hi + spread
  end

  local normalized = (raw + 1) * 0.5
  gen.value = lo + normalized * (hi - lo)

  gen.history[gen.hist_idx] = raw
  gen.hist_idx = gen.hist_idx + 1
  if gen.hist_idx > gen.hist_size then gen.hist_idx = 1 end
end

local function new_lfo(freq1, freq2)
  local lfo = {
    freq1 = freq1 or 0.3, freq2 = freq2 or 0.47,
    phase1 = 0, phase2 = 0,
    value_x = 0, value_y = 0, value = 0,
    range_lo = -1, range_hi = 1,
    history = {}, hist_idx = 1, hist_size = 64,
  }
  for i = 1, lfo.hist_size do lfo.history[i] = 0 end
  return lfo
end

local function update_lfo(lfo, dt)
  lfo.phase1 = lfo.phase1 + lfo.freq1 * dt * math.pi * 2
  lfo.phase2 = lfo.phase2 + lfo.freq2 * dt * math.pi * 2
  if lfo.phase1 > math.pi * 100 then lfo.phase1 = lfo.phase1 - math.pi * 100 end
  if lfo.phase2 > math.pi * 100 then lfo.phase2 = lfo.phase2 - math.pi * 100 end

  lfo.value_x = math.sin(lfo.phase1)
  lfo.value_y = math.sin(lfo.phase2)
  local raw = (lfo.value_x + lfo.value_y) * 0.5
  local normalized = (raw + 1) * 0.5
  lfo.value = lfo.range_lo + normalized * (lfo.range_hi - lfo.range_lo)

  lfo.history[lfo.hist_idx] = raw
  lfo.hist_idx = lfo.hist_idx + 1
  if lfo.hist_idx > lfo.hist_size then lfo.hist_idx = 1 end
end

-- PUBLIC API

bezier_mod.generators = {}

function bezier_mod.init()
  bezier_mod.generators = {
    curve1 = new_generator(0.1, 0.6, -1, 1),    -- slow, gentle
    curve2 = new_generator(0.25, 0.5, -1, 1),   -- medium
    curve3 = new_generator(0.5, 0.4, -1, 1),    -- faster
    curve4 = new_generator(0.06, 0.7, -1, 1),   -- very slow, smooth
    curve5 = new_generator(0.8, 0.3, -1, 1),    -- fast, subtle
    lfo = new_lfo(0.2, 0.37),
  }
  -- gentle cross-modulation
  bezier_mod.generators.curve1.xmod_speed = 0.1
  bezier_mod.generators.curve2.xmod_speed = 0.1
  bezier_mod.generators.curve3.xmod_speed = 0.08
  bezier_mod.generators.curve4.xmod_tension = 0.1
  bezier_mod.generators.curve5.xmod_range = 0.08
end

function bezier_mod.update(dt)
  local raw_vals = {}
  for name, gen in pairs(bezier_mod.generators) do
    if name == "lfo" then
      raw_vals[name] = (gen.value_x + gen.value_y) * 0.5
    else
      raw_vals[name] = cubic_bezier(gen.p0, gen.p1, gen.p2, gen.p3, gen.t)
    end
  end

  local xmod_sources = {
    curve1 = raw_vals.curve3,
    curve2 = raw_vals.curve1,
    curve3 = raw_vals.curve5,
    curve4 = raw_vals.curve2,
    curve5 = raw_vals.curve4,
  }

  for name, gen in pairs(bezier_mod.generators) do
    if name == "lfo" then
      update_lfo(gen, dt)
    else
      update_generator(gen, dt, xmod_sources[name])
    end
  end
end

function bezier_mod.get(name)
  local gen = bezier_mod.generators[name]
  return gen and gen.value or 0
end

function bezier_mod.get_raw(name)
  local gen = bezier_mod.generators[name]
  if gen and name ~= "lfo" then
    return cubic_bezier(gen.p0, gen.p1, gen.p2, gen.p3, gen.t)
  elseif gen then
    return (gen.value_x + gen.value_y) * 0.5
  end
  return 0
end

function bezier_mod.get_history(name)
  local gen = bezier_mod.generators[name]
  if gen then return gen.history, gen.hist_idx end
  return {}, 1
end

function bezier_mod.set_speed(name, speed)
  local gen = bezier_mod.generators[name]
  if gen then
    if name == "lfo" then
      gen.freq1 = speed
      gen.freq2 = speed * 1.57
    else
      gen.speed = speed
      gen.base_speed = speed
    end
  end
end

function bezier_mod.set_tension(tension)
  for name, gen in pairs(bezier_mod.generators) do
    if name ~= "lfo" then
      gen.tension = tension
      gen.base_tension = tension
    end
  end
end

function bezier_mod.set_xmod(name, param, amount)
  local gen = bezier_mod.generators[name]
  if gen and name ~= "lfo" then
    if param == "speed" then gen.xmod_speed = amount
    elseif param == "tension" then gen.xmod_tension = amount
    elseif param == "range" then gen.xmod_range = amount
    end
  end
end

function bezier_mod.randomize()
  for name, gen in pairs(bezier_mod.generators) do
    if name ~= "lfo" then
      gen.p0 = rand_point(gen.tension)
      gen.p1 = rand_point(gen.tension)
      gen.p2 = rand_point(gen.tension)
      gen.p3 = rand_point(gen.tension)
      gen.t = 0
    end
  end
end

return bezier_mod
