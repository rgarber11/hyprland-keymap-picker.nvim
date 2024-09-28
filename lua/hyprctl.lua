local async = require "plenary.async"
-- This is a little silly, but in future projects, this will be helpful
--- Hyprctl wrapper for lua. Will error on XDG_RUNTIME_DIR or HYPRLAND_INSTANCE_SIGNATURE not being set. This is an async function made with plenary.async, and must be run qs such.
--- @param cmd string # Command For Hyprctl to run
--- @return string | table # Commands with the j option will return a lua table. Otherwise will return json
local function hyprctl(cmd)
    local tx, rx = async.control.channel.oneshot()
    local returnJSON = false
    local opts = cmd:find "/"
    if opts ~= nil and cmd:sub(1, opts):find "j" ~= nil then
        returnJSON = true
    end
    local runtime_dir = assert(os.getenv "XDG_RUNTIME_DIR", "XDG_RUNTIME_DIR is not set.")
    local hypr_instance = assert(os.getenv "HYPRLAND_INSTANCE_SIGNATURE", "HYPRLAND_INSTANCE_SIGNATURE is not set")
    local socket_path = runtime_dir .. "/hypr/" .. hypr_instance .. "/.socket.sock"
    local socket = vim.uv.new_pipe(false)
    local buffer = require("string.buffer").new()
    local err = async.uv.pipe_connect(socket, vim.fn.resolve(socket_path))
    assert(not err, err)
    async.uv.write(socket, cmd)
    vim.uv.read_start(socket, function(err1, chunk)
        assert(not err1, err1)
        if chunk then
            buffer = buffer:put(chunk)
        else
            vim.uv.close(socket, function()
                tx(buffer:tostring())
            end)
        end
    end)
    local ret = rx()
    if returnJSON then
        return vim.json.decode(ret)
    end
    return ret
end
return hyprctl
