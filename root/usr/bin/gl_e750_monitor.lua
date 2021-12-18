#!/usr/bin/lua
local json = require "luci.jsonc"
local nixio = require "nixio"
local nixiofs = require "nixio.fs"

local wdmdev = "/dev/cdc-wdm0"
local xray_pid_file = "/var/run/xray.pid"

local function signal_strength()
    local handle = io.popen("uqmi --timeout 100 -d " .. wdmdev .. " --get-signal-info")
    local result = handle:read("*a")
    handle:close()
    local j = json.parse(result)
    if j == nil or j.type == nil then
        return "Cell: uqmi error"
    else
        return string.format("Cell:%4ddBm %s", j.rssi, j.type:sub(0, 3):upper())
    end
end

local function xray_mem()
    local pidv = ""
    local vmdata = 0
    local vmrss = 0
    for line in io.lines(xray_pid_file) do
        pidv = line
    end
    for line in io.lines(string.format("/proc/%s/status", pidv)) do
        if line:sub(0, 5) == "VmRSS" then
            vmrss = tonumber(line:match("%d+"))
        end
        if line:sub(0, 6) == "VmData" then
            vmdata = tonumber(line:match("%d+"))
        end
    end
    return string.format("VmRSS:  %6dKBVmData: %6dKB", vmrss, vmdata)
end

local function monitor_message()
    return signal_strength() .. xray_mem()
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
    os.execute("uqmi --timeout 100 -d " .. wdmdev .. " --sync")
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
