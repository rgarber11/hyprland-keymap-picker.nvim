local public_api = require "hyprland-keymap-picker"
local M = {}
M.check = function()
    vim.health.start "Hyprland-Keymap-Picker.nvim Report"
    -- make sure setup function parameters are ok
    local saved_opts = public_api.access_opts()
    if saved_opts.default_layout ~= nil then
        vim.health.ok "Setup has been run"
    else
        vim.health.error "Setup is incorrect"
        return
    end
    if saved_opts.default_layout == 0 then
        vim.health.error "Default Layout is 0. As Lua is zero-indexed, your first keymap should be labeled 1"
    end
    if io.open(saved_opts.rules_file) then
        vim.health.ok "xkbmap layout description file accessible"
    else
        vim.health.error "xkbmap layout descriptions inacessible. Change rules_file?"
    end
    if os.getenv "XDG_RUNTIME_DIR" ~= nil and os.getenv "HYPRLAND_INSTANCE_SIGNATURE" ~= nil then
        vim.health.ok "Hyprland seems to be running on this machine"
    else
        vim.health.error "Hyprland doesn't seem to be running on this machine"
    end
end
return M
