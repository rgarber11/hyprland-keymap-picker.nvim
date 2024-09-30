# Hyprland-Keymap-Picker.nvim

WIP Plugin to automatically change layouts when switching to and from insert mode in Hyprland.

## Current Installation

### Lazy.nvim

```lua
{
    "rgarber11/hyprland-keymap-picker.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
        if os.getenv "HYPRLAND_INSTANCE_SIGNATURE" then
            require("hyprland-keymap-picker").setup({ ... })
        end
    end,
}
```

## Proposed API:

### Setup

```lua
require("hyprland-keymap-picker").setup({
    default_layout = 0, -- Default Layout in Hyprland Will Be default (Default: 0)
    cache_devices = false, -- Call hyprctl devices every change, or cache keyboards (Default: false)
    cache_layouts = true, -- Check if there are new layouts, or only ask once (Note: This significantly slows things down) (Default: false)
    layouts = { -- Custom set layouts, rather than loading hyprland config. Note that the ordering relative to the config stil matters (not zero indexed here). (Default: Hyprland Config)
        [1] = "English (US)",
        [3] = "Russian (phonetic)",
    },
    on_change = function(new_lang) -- callback for when the language is changed. (Default: nil)
        local Job = require "plenary.job"
        Job:new({ -- Let external tools know the language has changed
            command = "pkill",
            args = {
                "-f",
                "-34",
                "nwg-panel",
            },
        }):start()
    on_enter = nil, -- callback for entering insert mode (Default: nil)
    on_exit = nil, -- callback for exiting insert mode (Default: nil)
    end,
})
--- Set insert-mode keymap programmatically
--- @param keymap int | string 1-indexed hyprland keymap id or "name" of keymap (as in hyprctl devices)
require("hyprland-keymap-picker").set_keymap(keymap)
--- Resets insert-mode keymap functionality.
require("hyprland-keymap-picker").reset()
--- Set normal-mode keymap programmatically (Note: these do not persist nvim instances. For that, change setup call)
--- @param keymap int | string 1-indexed hyprland keymap id or "name" of keymap (as in hyprctl devices)
require("hyprland-keymap-picker").set_default(keymap)


```

### Commands

| Command                | Description                                                                                                |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- |
| `HyprlandSetKeyMap`    | Sets the insert-mode language via a `vim.ui.select` toolbox.                                               |
| `HyprlandKeyMapReset`  | Turns off insert-mode keymap changing                                                                      |
| `HyprladDefaultKeymap` | Temporarily change normal and visual-mode keymap via a `vim.ui.select` toolbox. Selection does not persist |

## TODO

1. Actually create the top-level module/interface
2. Performance tuning. Should the `setup({})` call be blocking or non-blocking?
3. Testing suite + general setup to be more in-line with other Neovim plugins.