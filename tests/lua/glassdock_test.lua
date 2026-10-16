-- Tests for hypr/glassdock.lua, run with plain Lua 5.4 against a fake `hl`.
-- Simulates key presses by calling the bound functions directly.
--
--   lua tests/lua/glassdock_test.lua

local script = arg and arg[0] or "tests/lua/glassdock_test.lua"
local root = script:match("^(.*)tests/lua/[^/]+$") or "./"
local snippet = root .. "hypr/glassdock.lua"

-- ---- fake Hyprland ----------------------------------------------------------------

local function fake_hl()
  local hl = { binds = {}, unbound = {}, config_calls = {}, window_rules = {}, layer_rules = {},
               dispatched = {}, listeners = {} }

  function hl.bind(keys, dispatcher, opts)
    local handle = { keys = keys, dispatcher = dispatcher, opts = opts or {}, active = true }
    function handle:unbind() self.active = false end
    table.insert(hl.binds, handle)
    return handle
  end
  function hl.unbind(keys) table.insert(hl.unbound, keys) end
  function hl.config(t) table.insert(hl.config_calls, t) end
  function hl.window_rule(t) table.insert(hl.window_rules, t) end
  function hl.layer_rule(t) table.insert(hl.layer_rules, t) end
  function hl.dispatch(d) table.insert(hl.dispatched, d) end
  function hl.on(event, fn) hl.listeners[event] = fn end

  hl.dsp = { exec_cmd = function(cmd) return { exec = cmd } end }
  return hl
end

local function load(opts)
  _G.hl = fake_hl()
  _G.glassdock_blur = opts and opts.blur
  _G.glassdock_alt_tab = opts and opts.alt_tab
  dofile(snippet)
  return _G.hl
end

local function active_bind(hl, keys)
  for i = #hl.binds, 1, -1 do
    local b = hl.binds[i]
    if b.active and b.keys == keys then return b end
  end
end

local function count_active(hl, pred)
  local n = 0
  for _, b in ipairs(hl.binds) do if b.active and pred(b) then n = n + 1 end end
  return n
end

local function release_binds(hl)
  return count_active(hl, function(b) return b.opts.release end)
end

local function last_exec(hl)
  local d = hl.dispatched[#hl.dispatched]
  return d and d.exec
end

-- ---- tiny test harness -------------------------------------------------------------

local passed, failed = 0, 0
local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  ok   " .. name)
  else
    failed = failed + 1
    print("  FAIL " .. name .. "\n       " .. tostring(err))
  end
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
  end
end

-- ---- tests -------------------------------------------------------------------------

print("hypr/glassdock.lua")

test("enables blur and opts every window out of it", function()
  local hl = load()
  eq(hl.config_calls[1].decoration.blur.enabled, true, "blur.enabled")
  eq(hl.window_rules[1].match.class, ".*", "window rule class")
  eq(hl.window_rules[1].no_blur, true, "no_blur")
end)

test("layer rules match the dock and every glassdock-* layer, fully", function()
  local hl = load()
  local pattern = hl.layer_rules[1].match.namespace
  -- Hyprland full-matches layer regexes; emulate with anchors via Lua patterns.
  eq(pattern, "^glassdock(-.*)?$", "namespace regex")
  eq(hl.layer_rules[1].blur, true, "blur")
  assert(hl.layer_rules[1].ignore_alpha > 0 and hl.layer_rules[1].ignore_alpha < 0.15,
    "ignore_alpha must stay below the minimum glass tint (0.15)")
end)

test("replaces Omarchy's Alt+Tab binds", function()
  local hl = load()
  local unbound = table.concat(hl.unbound, ",")
  assert(unbound:find("ALT + TAB", 1, true), "ALT + TAB not unbound")
  assert(unbound:find("ALT + SHIFT + TAB", 1, true), "ALT + SHIFT + TAB not unbound")
  for _, keys in ipairs({ "ALT + TAB", "ALT + SHIFT + TAB", "ALT + GRAVE", "ALT + SHIFT + GRAVE" }) do
    assert(active_bind(hl, keys), keys .. " not bound")
  end
end)

test("Alt+Tab sends next, and arms the Alt-release binds first", function()
  local hl = load()
  eq(release_binds(hl), 0, "release binds before Alt+Tab")
  active_bind(hl, "ALT + TAB").dispatcher()
  eq(last_exec(hl), "omarchy-shell -q glassdock next", "command")
  eq(release_binds(hl), 4, "release binds after Alt+Tab")
end)

test("each step key sends its own command", function()
  local hl = load()
  local expected = {
    ["ALT + SHIFT + TAB"] = "prev",
    ["ALT + GRAVE"] = "nextWindow",
    ["ALT + SHIFT + GRAVE"] = "prevWindow",
  }
  for keys, method in pairs(expected) do
    active_bind(hl, keys).dispatcher()
    eq(last_exec(hl), "omarchy-shell -q glassdock " .. method, keys)
  end
end)

test("repeated Alt+Tab does not stack release binds", function()
  local hl = load()
  for _ = 1, 3 do active_bind(hl, "ALT + TAB").dispatcher() end
  eq(release_binds(hl), 4, "release binds")
end)

test("releasing Alt commits and disarms", function()
  local hl = load()
  active_bind(hl, "ALT + TAB").dispatcher()
  active_bind(hl, "ALT + ALT_L").dispatcher()
  eq(last_exec(hl), "omarchy-shell -q glassdock commit", "command")
  eq(release_binds(hl), 0, "release binds after commit")
end)

test("release binds cover both Alt keys, with and without Shift", function()
  local hl = load()
  active_bind(hl, "ALT + TAB").dispatcher()
  for _, keys in ipairs({ "ALT + ALT_L", "ALT + ALT_R", "ALT + SHIFT + ALT_L", "ALT + SHIFT + ALT_R" }) do
    local b = active_bind(hl, keys)
    assert(b and b.opts.release, keys .. " release bind missing")
  end
end)

test("closing the switcher layer disarms (Esc or click)", function()
  local hl = load()
  active_bind(hl, "ALT + TAB").dispatcher()
  hl.listeners["layer.closed"]({ namespace = "glassdock" })
  eq(release_binds(hl), 4, "unrelated layer must not disarm")
  hl.listeners["layer.closed"]({ namespace = "glassdock-switcher" })
  eq(release_binds(hl), 0, "release binds")
end)

test("glassdock_blur = false leaves blur settings alone", function()
  local hl = load({ blur = false })
  eq(#hl.config_calls, 0, "config calls")
  eq(#hl.window_rules, 0, "window rules")
  eq(#hl.layer_rules, 2, "layer rules still applied")
end)

test("glassdock_alt_tab = false keeps Omarchy's Alt+Tab", function()
  local hl = load({ alt_tab = false })
  eq(#hl.unbound, 0, "unbinds")
  eq(active_bind(hl, "ALT + TAB"), nil, "ALT + TAB bind")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
