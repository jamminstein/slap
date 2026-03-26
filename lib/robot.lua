-- robot.lua
-- pixel art robot avatars for slap
-- 5 named profiles, each with unique visual style
-- expressions driven by energy, mood, and beat

local robot = {}

-- ======== PROFILES ========
-- each profile: visual style + which personality drives the song engine

robot.profiles = {
  {name = "OTTO",  desc = "all-rounder",     personality = 1, head = "circle",  eyes = "round",  mouth = "smile",  feat = "antenna"},
  {name = "VERA",  desc = "melodic dreamer",  personality = 3, head = "pill",    eyes = "line",   mouth = "dot",    feat = "ears"},
  {name = "SPIKE", desc = "rhythm destroyer", personality = 4, head = "square",  eyes = "cross",  mouth = "zigzag", feat = "sparks"},
  {name = "MONK",  desc = "ambient drifter",  personality = 1, head = "circle",  eyes = "dot",    mouth = "none",   feat = "halo"},
  {name = "NORI",  desc = "acid explorer",    personality = 2, head = "diamond", eyes = "arrow",  mouth = "flat",   feat = "drip"},
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

  -- blink
  blink_timer = blink_timer + dt
  if blink_on then
    if blink_timer > 0.1 then blink_on = false; blink_timer = 0 end
  else
    if blink_timer > (2.5 + math.random() * 3) then blink_on = true; blink_timer = 0 end
  end

  -- beat decay
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

  -- === HEAD ===
  screen.level(bright)
  if p.head == "circle" then
    screen.circle(cx, cy - 4, 9 + e)
    screen.fill()
  elseif p.head == "square" then
    local s = 8 + e
    local jx = active and (math.random() < 0.15 and math.random(-1, 1) or 0) or 0
    screen.rect(cx - s + jx, cy - 4 - s, s * 2, s * 2)
    screen.fill()
  elseif p.head == "diamond" then
    local s = 9 + e
    screen.move(cx, cy - 4 - s)
    screen.line(cx + s, cy - 4)
    screen.line(cx, cy - 4 + s)
    screen.line(cx - s, cy - 4)
    screen.close()
    screen.fill()
  elseif p.head == "pill" then
    local w = 11 + e
    local h = 7 + e * 0.5
    screen.rect(cx - w, cy - 4 - h, w * 2, h * 2)
    screen.fill()
  end

  -- === EYES === (dark on bright head)
  screen.level(0)
  local ey = cy - 6
  local el = cx - 4
  local er = cx + 4

  if blink_on then
    -- blink: thin lines
    screen.move(el - 2, ey); screen.line(el + 2, ey); screen.stroke()
    screen.move(er - 2, ey); screen.line(er + 2, ey); screen.stroke()
  elseif p.eyes == "round" then
    local r = 1.5 + e * 0.5
    screen.circle(el, ey, r); screen.fill()
    screen.circle(er, ey, r); screen.fill()
  elseif p.eyes == "dot" then
    screen.rect(el - 1, ey - 1, 2, 2); screen.fill()
    screen.rect(er - 1, ey - 1, 2, 2); screen.fill()
  elseif p.eyes == "line" then
    local w = 2 + e
    screen.move(el - w, ey); screen.line(el + w, ey); screen.stroke()
    screen.move(er - w, ey); screen.line(er + w, ey); screen.stroke()
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

  -- === MOUTH ===
  screen.level(0)
  local my = cy - 1

  if p.mouth == "smile" then
    local w = 2 + e * 1.5
    screen.move(cx - w, my)
    screen.line(cx, my + 1 + e)
    screen.line(cx + w, my)
    screen.stroke()
  elseif p.mouth == "flat" then
    local w = 3 + e
    screen.move(cx - w, my); screen.line(cx + w, my); screen.stroke()
  elseif p.mouth == "dot" then
    screen.rect(cx - 1, my - 1, 2, 2); screen.fill()
  elseif p.mouth == "zigzag" then
    local w = 3 + e
    screen.move(cx - w, my)
    screen.line(cx - w*0.3, my + 2)
    screen.line(cx + w*0.3, my - 1)
    screen.line(cx + w, my)
    screen.stroke()
  end
  -- "none" = MONK, no mouth

  -- === FEATURE ===
  screen.level(active and 12 or 4)

  if p.feat == "antenna" then
    local bob = math.sin(idle_t * 2) * 1.5
    local top = cy - 15 - e + bob
    screen.move(cx, cy - 13 - e); screen.line(cx, top); screen.stroke()
    screen.circle(cx, top - 1, 1.5); screen.fill()
  elseif p.feat == "ears" then
    local s = 10 + e
    screen.move(cx - s, cy - 6); screen.line(cx - s - 3, cy - 12); screen.stroke()
    screen.move(cx + s, cy - 6); screen.line(cx + s + 3, cy - 12); screen.stroke()
  elseif p.feat == "sparks" then
    if active then
      for _ = 1, math.floor(2 + e * 3) do
        screen.pixel(cx + math.random(-14, 14), cy - 4 + math.random(-14, 10))
        screen.fill()
      end
    end
  elseif p.feat == "halo" then
    local yb = math.sin(idle_t) * 1.5
    screen.circle(cx, cy - 16 - e + yb, 4); screen.stroke()
  elseif p.feat == "drip" then
    local dy = (idle_t * 6) % 10
    screen.move(cx, cy + 5 + e)
    screen.line(cx, cy + 5 + e + dy)
    screen.stroke()
    screen.circle(cx, cy + 6 + e + dy, 1); screen.fill()
  end
end

return robot
