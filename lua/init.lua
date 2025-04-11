--- @class HyprlandKeymapOpts
--- @field default_layout integer? 1-indexed default layout. (Ordering based on Hyprland config) (Default: 1)
--- @field cache_devices boolean? If a keyboard array isn't given, should devices be checked every change. (Default: true)
--- @field cache_layouts boolean? Get layout descriptions once during setup, or before every call (Default: true)
--- @field layouts string[]? Set layouts without calling into Hyprland config. Note that the layout index be a 1-indexed version of the Hyprland Config index.
--- @field keyboards string[]? Set keyboards to be changed on use. The first keyboard is assumed to be the default keyboard.
--- @field on_change fun(new_keymap: string)? Function to be called on keymap change.
--- @field on_enter fun(new_keymap: string)? Function to be called on entering insert mode.
--- @field on_exit fun(new_keymap: string)? Function to be called on exiting insert mode.
local async = require "plenary.async"
local funcs = require "funcs"
local M = {}
local setting_up_layouts, done_setup_layouts = async.control.channel.counter()
local setting_up_devices, done_setup_devices = async.control.channel.counter()
local autocmd_id = nil
local changed_default_zero_indexed = nil
local saved_opts = {} --- HyprlandKeymapOpts
--- Main setup function for Hyprland-Keymap
--- @param opts HyprlandKeymapOpts? Setup options for hyprland-keymap-picker.nvim
function M.setup(opts)
    if opts == nil then
        opts = {}
    end
    if opts.default_layout ~= nil then
        opts.default_layout = 1
    end
    saved_opts.default_layout = opts.default_layout
    if opts.cache_devices ~= nil then
        opts.cache_devices = true
    end
    saved_opts.cache_devices = opts.cache_devices
    if opts.cache_layouts ~= nil then
        opts.cache_layouts = true
    end
    saved_opts.cache_devices = opts.cache_layouts
    if opts.on_change ~= nil then
        saved_opts.on_change = opts.on_change
    end
    if opts.on_enter ~= nil then
        saved_opts.on_enter = opts.on_enter
    end
    if opts.on_exit ~= nil then
        saved_opts.on_exit = opts.on_exit
    end
    if opts.layouts ~= nil then
        saved_opts.layouts = opts.layouts
        saved_opts.cache_layouts = true -- If you list layouts, that might as well be caching
        async.run(function()
            setting_up_layouts:send()
        end)
    elseif opts.cache_layouts then
        async.run(function()
            saved_opts.layouts = funcs.get_layouts()
            setting_up_layouts:send()
        end)
    end
    if opts.keyboards ~= nil then
        local keyboards = {}
        table.insert(keyboards, { ["main"] = true, ["name"] = opts.keyboards[1] })
        for i, v in ipairs(opts.keyboards) do
            if i ~= 1 then
                table(keyboards, { ["main"] = false, ["name"] = opts.keyboards[i] })
            end
        end
        saved_opts.cache_devices = true
        saved_opts.keyboards = keyboards
        async.run(function()
            setting_up_devices:send()
        end)
    elseif opts.cache_devices then
        async.run(function()
            saved_opts.keyboards = funcs.get_keyboards()
            setting_up_devices:send()
        end)
    end
    vim.api.nvim_create_user_command("HyprlandSetKeymap", function()
        M.set_default()
    end, { desc = "Set insert-mode language" })
    vim.api.nvim_create_user_command("HyprlandResetKeymap", function()
        M.reset()
    end, { desc = "Set insert-mode language" })
    vim.api.nvim_create_user_command("HyprlandDefaultKeymap", function()
        M.set_default()
    end, { desc = "Set insert-mode language" })
end
--- Return zero-indexed keymap for given input.
---@param keymap integer|string|nil
---@param prompt string
---@return integer
local function get_keymap_id(keymap, prompt)
    local zero_idx_keymap = -1
    if type(keymap) == "number" then
        zero_idx_keymap = keymap - 1
    elseif type(keymap) == "string" then
        for i, layout_name in ipairs(saved_opts.layouts) do
            if layout_name == keymap then
                zero_idx_keymap = i - 1
            end
        end
    else
        vim.ui.select(saved_opts.layouts, { prompt = prompt, kind = "idx" }, function(_, idx)
            zero_idx_keymap = idx - 1
        end)
    end
    return zero_idx_keymap
end
--- Set insert mode keymap
---@param keymap integer | string | nil Value of Keymap to use. If integer, then select from 1-indexed array of layouts. If string, use said layout string. If nil, then it will use vim.ui.select
function M.set_keymap(keymap)
    if not saved_opts.cache_layouts then
        async.run(function()
            saved_opts.layouts = funcs.get_layouts()
            setting_up_layouts:send()
        end)
    end
    done_setup_layouts.recv()
    if not saved_opts.cache_devices then
        async.run(function()
            saved_opts.keyboards = funcs.get_keyboards()
            setting_up_devices:send()
        end)
    end
    done_setup_devices.recv()
    local zero_idx_keymap = get_keymap_id(keymap, "Pick the Insert-Mode Keymap")
    if type(keymap) == "number" then
        zero_idx_keymap = keymap - 1
    elseif type(keymap) == "string" then
        for i, layout_name in ipairs(saved_opts.layouts) do
            if layout_name == keymap then
                zero_idx_keymap = i - 1
            end
        end
    else
        vim.ui.select(saved_opts.layouts, { prompt = "Pick the Insert-Mode Keymap", kind = "idx" }, function(_, idx)
            zero_idx_keymap = idx - 1
        end)
    end
    autocmd_id = vim.api.nvim_create_augroup("LangPicker", {})
    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
        group = autocmd_id,
        desc = "Hyprland-Lang-Picker Changing language in InsertMode",
        pattern = "*",
        callback = function(_)
            if saved_opts.on_enter then
                saved_opts.on_enter(saved_opts.layouts[zero_idx_keymap + 1])
            end
            if saved_opts.on_change then
                saved_opts.on_change(saved_opts.layouts[zero_idx_keymap + 1])
            end
            async.run(function()
                funcs.change_layout(zero_idx_keymap, saved_opts.keyboards)
            end)
        end,
    })
    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
        group = autocmd_id,
        desc = "Hyprland-Lang-Picker Changing language back to default when leaving insert mode",
        pattern = "*",
        callback = function(_)
            if saved_opts.on_exit then
                saved_opts.on_exit(saved_opts.layouts[changed_default_zero_indexed + 1])
            end
            if saved_opts.on_change then
                saved_opts.on_change(saved_opts.layouts[changed_default_zero_indexed + 1])
            end
            if changed_default_zero_indexed ~= nil then
                async.run(function()
                    funcs.change_layout(changed_default_zero_indexed, saved_opts.keyboards)
                end)
            elseif saved_opts.default_layout == 1 then
                async.run(function()
                    funcs.to_default()
                end)
            else
                async.run(function()
                    funcs.change_layout(saved_opts.default_layout - 1, saved_opts.keyboards)
                end)
            end
        end,
    })
    if saved_opts.cache_layouts then
        async.run(function()
            setting_up_layouts:send()
        end)
    end
    if saved_opts.cache_devices then
        async.run(function()
            setting_up_devices:send()
        end)
    end
end
--- Turn of insert-mode keymap changes
function M.reset()
    assert(autocmd_id, "Autocommands not set")
    vim.api.nvim_del_augroup_by_id(autocmd_id)
    autocmd_id = nil
    changed_default_zero_indexed = nil
end
--- Temporarily change the keymap when outside of insert mode.
---@param keymap integer | string | nil Value of Keymap to use. If integer, then select from 1-indexed array of layouts. If string, use said layout string. If nil, then it will use vim.ui.select
function M.set_default(keymap)
    changed_default_zero_indexed = get_keymap_id(keymap, "Set Temporary Other Default")
end
return M
