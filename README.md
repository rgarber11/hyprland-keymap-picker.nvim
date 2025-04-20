# Hyprland-Keymap-Picker.nvim

Automatically change layouts when switching to and from insert mode in Hyprland.

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

## API:

### Setup

```lua
require("hyprland-keymap-picker").setup({
    default_layout = 1, -- Default Layout for non-insert modes (1-indexed) (Default: 1)
    cache_devices = false, -- Call hyprctl devices every change, or cache keyboards (Default: false)
    cache_layouts = true, -- Check if there are new layouts, or only ask once (Note: This significantly slows things down) (Default: false)
    layouts = { -- Custom set layouts, rather than loading hyprland config. Note that the ordering relative to the config stil matters (not zero indexed here). (Default: Hyprland Config)
        [1] = "English (US)",
        [3] = "Russian (phonetic)",
    },
    keyboards = { -- Custom set keyboards, rather than calling "hyprctl devices". Note that the first keyboard is assumed to be the main board.
        "at-translated-set-2-keyboard",
        "other-keyboard"
    }
    on_change = function(new_keymap) -- callback for when the language is changed. (Default: nil)
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
    rules_file = "/usr/share/X11/xkb/rules/evdev.lst" -- Location of xkbmap rules file (Default: /usr/share/X11/xkb/rules/evdev.lst)
    end,
})
```

### Lua Functions

```lua
--- Set insert-mode keymap programmatically
--- @param keymap int | string | nil 1-indexed hyprland keymap id or "name" of keymap (as in hyprctl devices). If nil, then a selection menu will be used.
require("hyprland-keymap-picker").set_keymap(keymap)
--- Resets insert-mode keymap functionality.
require("hyprland-keymap-picker").reset()
--- Set normal-mode keymap programmatically (Note: these do not persist nvim instances. For that, change setup call)
--- @param keymap int | string | nil 1-indexed hyprland keymap id or "name" of keymap (as in hyprctl devices). If nil then a selection menu will be used
require("hyprland-keymap-picker").set_default(keymap)
--- Reload layouts without changing cache_status (This function works if layouts aren't cached, but only makes sense if they are)
require("hyprland-keymap-picker").reload_layouts()
--- Diagnostic function to gain access to plugin-wide saved settings.
require("hyprland-keymap-picker").access_opts()
```

### Commands

| Command                 | Description                                                                                                |
| ----------------------- | ---------------------------------------------------------------------------------------------------------- |
| `HyprlandSetKeymap`     | Sets the insert-mode language via a `vim.ui.select` toolbox.                                               |
| `HyprlandResetKeymap`   | Turns off insert-mode keymap changing                                                                      |
| `HyprlandDefaultKeymap` | Temporarily change normal and visual-mode keymap via a `vim.ui.select` toolbox. Selection does not persist |
| `HyprlandReloadLayouts` | Reload cached layouts at runtime, using hyprctl                                                            |

## TODO

1. I read xkbmap layout descriptions from `/usr/share/X11/xkb/rules/evdev.lst`. Is this valid on all distros? I've exposed this as a setting, but is this file being the default wise, since on my setup `base.lst` seems to be identical? How does this work on e.g. NixOS? Do I write a C extension and use [libxkbcommon](https://github.com/xkbcommon/libxkbcommon)? What is the build story for Neovim C Plugins?
2. Additional testing. We just have a basic `:checkhealth`.
3. Normal-mode commands that take a letter (e.g r, f, t)currently are clunky. Is there a way to fix this, or no?
