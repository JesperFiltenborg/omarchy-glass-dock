-- luacheck config. Hyprland's Lua API is the `hl` global; Omarchy adds `o`.
std = "lua54"
max_line_length = 120

files["hypr/glassdock.lua"] = {
  read_globals = { "hl", "o", "glassdock_blur", "glassdock_alt_tab" },
}

files["tests/lua/"] = {
  -- The tests install a fake `hl` and set the opt-out flags as globals.
  globals = { "hl", "glassdock_blur", "glassdock_alt_tab" },
}
