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
local funcs = require "hyprland-keymap-picker.funcs"
local M = {}
local setting_up_layouts, done_setup_layouts = async.control.channel.counter()
local setting_up_devices, done_setup_devices = async.control.channel.counter()
local autocmd_id = nil -- number?
local default_keymaps_zero_indexed = {} --- {number: number}
local saved_opts = {} --- HyprlandKeymapOpts
--- Main setup function for Hyprland-Keymap
--- @param opts HyprlandKeymapOpts? Setup options for hyprland-keymap-picker.nvim
function M.setup(opts)
    if opts == nil then
        opts = {}
    end
    if opts.default_layout == nil then
        opts.default_layout = 1
    end
    saved_opts.default_layout = opts.default_layout
    saved_opts.gave_custom_layouts = false
    if opts.cache_devices == nil then
        opts.cache_devices = true
    end
    saved_opts.cache_devices = opts.cache_devices
    if opts.cache_layouts == nil then
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
        saved_opts.gave_custom_layouts = true
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
                table(keyboards, { ["main"] = false, ["name"] = v })
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
    autocmd_id = vim.api.nvim_create_augroup("LangPicker", { clear = false })
    vim.api.nvim_create_user_command("HyprlandSetKeymap", function()
        M.set_keymap()
    end, { desc = "Set insert-mode language, and enable changing keymaps on entering and exiting insert mode" })
    vim.api.nvim_create_user_command("HyprlandResetKeymap", function()
        M.reset()
    end, { desc = "Turn off keymap changing when entering insert mode" })
    vim.api.nvim_create_user_command("HyprlandDefaultKeymap", function()
        M.set_default()
    end, { desc = "Change default keymap when exiting insert mode" })
    vim.api.nvim_create_user_command("HyprlandReloadLayouts", function()
        M.reload_layouts()
    end, { desc = "Reload Cached Layouts with new layouts" })
end
--- Return zero-indexed keymap for given input.
---@param keymap integer|string|nil
---@param prompt string
---@return integer
local function get_keymap_id(keymap, prompt)
    local tx, rx = async.control.channel.oneshot()
    async.util.block_on(function()
        done_setup_layouts.recv()
    end)
    if type(keymap) == "number" then
        tx(keymap - 1)
    elseif type(keymap) == "string" then
        for i, layout_name in pairs(saved_opts.layouts) do
            if layout_name == keymap then
                tx(i - 1)
            end
        end
    else
        local converter = {}
        local layout_array = {}
        if saved_opts.gave_custom_layouts then
            for i, v in pairs(saved_opts.layouts) do
                table.insert(converter, i)
                table.insert(layout_array, v)
            end
        else
            for i, v in ipairs(saved_opts.layouts) do
                table.insert(converter, i)
                table.insert(layout_array, v)
            end
        end
        vim.ui.select(layout_array, { prompt = prompt, kind = "idx" }, function(_, idx)
            if idx == nil then
                tx(-1)
            else
                tx(converter[idx] - 1)
            end
        end)
    end
    async.run(function()
        setting_up_layouts:send()
    end)
    return rx
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
    if not saved_opts.cache_devices then
        async.run(function()
            saved_opts.keyboards = funcs.get_keyboards()
            setting_up_devices:send()
        end)
    end
    local keymap_awaitable = get_keymap_id(keymap, "Pick the Insert-Mode Keymap")
    async.run(function()
        done_setup_layouts.recv()
        done_setup_devices.recv()
        local zero_idx_keymap = keymap_awaitable()
        if zero_idx_keymap == -1 then
            return
        end
        vim.api.nvim_clear_autocmds({ group = autocmd_id, buffer = 0 })
        default_keymaps_zero_indexed[vim.api.nvim_get_current_buf()] = saved_opts.default_layout - 1
        vim.api.nvim_create_autocmd({ "InsertEnter" }, {
            group = autocmd_id,
            buffer = 0,
            desc = "Hyprland-Lang-Picker Changing language in InsertMode",
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
            buffer = 0,
            desc = "Hyprland-Lang-Picker Changing language back to default when leaving insert mode",
            callback = function(args)
                local buf_default = default_keymaps_zero_indexed[args.buf]
                async.run(function()
                    funcs.change_layout(buf_default, saved_opts.keyboards)
                end)
                if saved_opts.on_exit then
                    saved_opts.on_exit(saved_opts.layouts[buf_default + 1])
                end
                if saved_opts.on_change then
                    saved_opts.on_change(saved_opts.layouts[buf_default + 1])
                end
            end,
        })
    end)
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
    vim.api.nvim_clear_autocmds({ group = autocmd_id, buffer = 0 })
    default_keymaps_zero_indexed[vim.api.nvim_get_current_buf()] = saved_opts.default_layout - 1
end
--- Temporarily change the keymap when outside of insert mode.
---@param keymap integer | string | nil Value of Keymap to use. If integer, then select from 1-indexed array of layouts. If string, use said layout string. If nil, then it will use vim.ui.select
function M.set_default(keymap)
    local keymap_awaitable = get_keymap_id(keymap, "Set Temporary Other Default")
    async.run(function()
        local possible_keymap = keymap_awaitable()
        if possible_keymap == -1 then
            return
        end
        default_keymaps_zero_indexed[vim.api.nvim_get_current_buf()] = possible_keymap
    end)
end
--- Reload layouts without changing cache_status (This function works if layouts aren't cached, but only makes sense if they are)
function M.reload_layouts()
    async.run(function()
        done_setup_layouts.recv()
        saved_opts.layouts = funcs.get_layouts()
        setting_up_layouts:send()
    end)
end
return M
