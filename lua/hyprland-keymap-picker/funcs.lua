local async = require "plenary.async"
local Job = require "plenary.job"
local hyprctl = require "hyprland-keymap-picker.hyprctl"
local M = {}
--- @class Keyboard
--- @field address string
--- @field name string
--- @field rules string
--- @field model string
--- @field layout string
--- @field variant string
--- @field options string
--- @field active_keymap string
--- @field main boolean
--- @class Layouts
--- @field [string] string Associative field between layout name and layout description
local saved_layouts = nil
--- @class Variants
--- @field [string] {[string]: string} Associative field between "layoutname|variantname" and variant description
local saved_variants = nil
--- Synchronous call to switch to default keymap Note: 'switchxkblayout all' only works for the default keymap on my machine
function M.to_default()
    async.util.block_on(function()
        hyprctl "switchxkblayout all 0"
    end)
end
--- @async
--- Asynchronously return all keyboards. Errors if none found
--- @return Keyboard[] keyboards All Keyboards defined by Hyprland
function M.get_keyboards()
    local devices = hyprctl "j/devices"
    assert(devices["keyboards"], "No keyboards found")
    return devices["keyboards"]
end
--- @async
--- Async Function Which Returns Keyboard Layout
---@param keyboards Keyboard[]? Array of Keyboards to be tested. Otherwise array of keyboards to be changed
---@return string name Name of Current Layout
function M.get_current_layout(keyboards)
    if keyboards == nil then
        keyboards = M.get_keyboards()
    end
    for _, k in ipairs(keyboards) do
        if k.main then
            return k["active_keymap"]
        end
    end
    for _, k in ipairs(keyboards) do
        if k.name:find "keyboard" then
            return k["active_keymap"]
        end
    end
    return keyboards[1]["active_keymap"]
end
--- @async
--- Changes Layout To a Given Layout. Does multiple hyprctl calls as 'switchxkblayout all' is broken on my machine.
--- @param layout integer? Number of Layout in ordering in hyprland config file. (0-indexed)
---@param keyboards Keyboard[]? Array of Keyboards to be tested. Otherwise array of keyboards to be changed
function M.change_layout(layout, keyboards)
    layout = layout or 0
    if keyboards == nil then
        keyboards = M.get_keyboards()
    end
    local main = nil
    for _, k in ipairs(keyboards) do
        if not k.main then
            hyprctl("switchxkblayout " .. k["name"] .. " " .. layout)
        else
            main = k["name"]
        end
    end
    if main ~= nil then
        hyprctl("switchxkblayout " .. main .. " " .. layout)
    end
end
---@enum parse_states
local parse_states = {
    pre_layout = 1,
    layout = 2,
    variants = 3,
    done = 4,
}
--- Returns Human-readable name for given XKB Layout/Variant combination.
---@param layout string Xkb Layout
---@param variant string? Variant for given xkblayout
---@return string description X11 description given in evdev.lst for the given xkbmap.
local function get_layout_description(layout, variant)
    if saved_layouts == nil then
        saved_layouts = {}
        saved_variants = {}
        local state = parse_states.pre_layout
        local xkb_rules = io.open("/usr/share/X11/xkb/rules/evdev.lst", "r")
        if xkb_rules == nil then
            return ""
        end
        for line in xkb_rules:lines() do
            if state == parse_states.pre_layout then
                if string.find(line, "! layout") then
                    state = parse_states.layout
                end
            elseif state == parse_states.layout then
                if string.find(line, "! variant") then
                    state = parse_states.variants
                elseif string.find(line, "^%s*$") then
                else
                    local layout_name, layout_desc = string.match(line, "^%s*(%l+)%s+(.+)$")
                    saved_layouts[layout_name] = layout_desc
                end
            elseif state == parse_states.variants then
                if string.find(line, "! option") then
                    state = parse_states.done
                elseif string.find(line, "^%s*$") then
                else
                    local variant_name, layout_name, variant_desc = string.match(line, "^%s*(%S+)%s+(%l+):%s+(.+)$")
                    if saved_variants[layout_name] == nil then
                        saved_variants[layout_name] = {}
                    end
                    saved_variants[layout_name][variant_name] = variant_desc
                end
            else
                break
            end
        end
        xkb_rules:close()
    end
    if variant == nil or variant == "" then
        return saved_layouts[layout]
    else
        return saved_variants[layout][variant]
    end
end
--- @async
--- Get Human Readable descriptions for all Hyprland Keyboard Layouts.
---@return string[] layouts
function M.get_layouts()
    local layoutStr = hyprctl("j/getoption input:kb_layout")["str"]
    local variantJSON = hyprctl "j/getoption input:kb_variant"
    local variantStr = ""
    if variantJSON.set then
        variantStr = variantJSON.str
    end
    local layouts = {}
    local variants = {}
    for str in string.gmatch(layoutStr, "([^,]+)") do
        table.insert(layouts, str)
    end
    for str in string.gmatch(variantStr, "([^,]*)") do
        table.insert(variants, str)
    end
    local descriptions = {}
    for i, layout in ipairs(layouts) do
        if layout ~= "" then
            table.insert(descriptions, get_layout_description(layout, variants[i]))
        end
    end
    return descriptions
end
return M
