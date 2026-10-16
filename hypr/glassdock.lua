-- Glass Dock — Hyprland integration.
--
-- Load from ~/.config/hypr/hyprland.lua (after Omarchy's defaults and your
-- bindings), e.g.:
--
--   local glassdock = os.getenv("HOME") .. "/.config/omarchy/plugins/jesperfiltenborg.glassdock/hypr/glassdock.lua"
--   if io.open(glassdock) then dofile(glassdock) end
--
-- Tweak behaviour by setting these globals before the dofile():
--   glassdock_blur = false          -- leave Hyprland's blur settings alone
--   glassdock_alt_tab = false       -- keep Omarchy's default Alt+Tab

local ipc = "omarchy-shell -q glassdock "

-- Glass: blur what is behind the dock -----------------------------------------
--
-- Omarchy ships with blur disabled globally. Enable it, then opt every window
-- back out so the dock and switcher layers are the only blurred surfaces.

if glassdock_blur ~= false then
  hl.config({
    decoration = {
      blur = {
        enabled = true,
        size = 10,
        passes = 3,
        noise = 0.015,
        contrast = 1.0,
        brightness = 1.0,
        vibrancy = 0.25,
        popups = true,
      },
    },
  })

  hl.window_rule({ name = "glassdock-windows-unblurred", match = { class = ".*" }, no_blur = true })
end

-- ignore_alpha keeps the transparent headroom above the shelf (where magnified
-- icons and popups appear) from being blurred into a grey slab.
hl.layer_rule({ name = "glassdock-glass", match = { namespace = "^glassdock(-.*)?$" }, blur = true, ignore_alpha = 0.12 })
-- The dock animates itself; Hyprland's layer slide would fight it.
hl.layer_rule({ name = "glassdock-no-anim", match = { namespace = "^glassdock(-.*)?$" }, no_anim = true })

-- Alt+Tab -------------------------------------------------------------------------
--
-- Alt+Tab / Alt+Shift+Tab   step through apps (most recently used first)
-- Alt+` / Alt+Shift+`       step through the selected app's windows
-- release Alt               switch
--
-- The Alt-release binds are armed synchronously inside the Alt+Tab handler, so
-- they exist before Alt can come up, and they remove themselves when fired or
-- when the switcher layer closes.

if glassdock_alt_tab ~= false then
  local release_binds = nil

  local function disarm()
    if not release_binds then return end
    for _, b in ipairs(release_binds) do b:unbind() end
    release_binds = nil
  end

  local function commit()
    disarm()
    hl.dispatch(hl.dsp.exec_cmd(ipc .. "commit"))
  end

  local function arm()
    if release_binds then return end
    release_binds = {}
    for _, combo in ipairs({ "ALT + ALT_L", "ALT + ALT_R", "ALT + SHIFT + ALT_L", "ALT + SHIFT + ALT_R" }) do
      table.insert(release_binds, hl.bind(combo, commit, { release = true, description = "Glass Dock: switch" }))
    end
  end

  local function step(method)
    return function()
      arm()
      hl.dispatch(hl.dsp.exec_cmd(ipc .. method))
    end
  end

  -- Omarchy binds Alt+Tab to cycle_next and bring_to_top; replace both.
  hl.unbind("ALT + TAB")
  hl.unbind("ALT + SHIFT + TAB")

  hl.bind("ALT + TAB", step("next"), { description = "Glass Dock: next app" })
  hl.bind("ALT + SHIFT + TAB", step("prev"), { description = "Glass Dock: previous app" })
  hl.bind("ALT + GRAVE", step("nextWindow"), { description = "Glass Dock: next window of app" })
  hl.bind("ALT + SHIFT + GRAVE", step("prevWindow"), { description = "Glass Dock: previous window of app" })

  hl.on("layer.closed", function(layer)
    if layer.namespace == "glassdock-switcher" then disarm() end
  end)
end
