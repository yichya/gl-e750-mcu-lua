#!/usr/bin/lua
local json = require "luci.jsonc"
local nixio = require "nixio"
local nixiofs = require "nixio.fs"

local wdmdev = "/dev/cdc-wdm0"

local function signal_strength()
    local handle = io.popen("uqmi --timeout 100 -d " .. wdmdev .. " --get-signal-info")
    local result = handle:read("*a")
    handle:close()
    local j = json.parse(result)
    if j == nil or j.type == nil then
        return "Cell: uqmi error"
    else
        return string.format("Cell:%4ddBm %s", j.rssi, string.upper(j.type))
    end
end

local function monitor_message()
    return signal_strength()
end

local function send_message(msg)
    if msg == nil then
        return
    end
    local t = json.stringify({msg = msg}, true)
    local f = io.open("/dev/ttyS0", "w")
    io.output(f)
    io.write(t)
    io.close(f)
end

local function sync()
    local handle = io.popen("uqmi -d " .. wdmdev .. " --sync")
    handle:read("*a")
    handle:close()
end

while (true) do
    sync()
    if nixiofs.stat("/tmp/monitor_running") == nil then
        send_message("                 Monitor exited")
        return
    else
        send_message(monitor_message())
        nixio.nanosleep(1)
    end
end
