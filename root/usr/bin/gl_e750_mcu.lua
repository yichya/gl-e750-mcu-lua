#!/usr/bin/lua

local ubus = require "ubus"
local json = require "luci.jsonc"
local nixio = require "nixio"

local conn = ubus.connect()
if not conn then error("Failed to connect to ubus") end

local function parse_radio_2g(radio)
    local up = "0"
    if radio.up then up = "1" end
    for i, p in ipairs(radio.interfaces) do
        if p.config.mode == "ap" then
            return {up = up, ssid = p.config.ssid, key = p.config.key}
        end
    end
    return {}
end

local function parse_radio_5g(radio)
    local up = "0"
    if radio.up then up = "1" end
    for i, p in ipairs(radio.interfaces) do
        if p.config.mode == "ap" then
            return {up_5g = up, ssid_5g = p.config.ssid, key_5g = p.config.key}
        end
    end
    return {}
end

local function wireless_info()
    local radio2g = {}
    local radio5g = {}
    local info = conn:call("network.wireless", "status", {})
    for rn, rt in pairs(info) do
        local is_5g = false
        if rt.config.hwmode == '11a' then
            radio5g = parse_radio_5g(rt)
        else
            radio2g = parse_radio_2g(rt)
        end
    end
    local t = {}
    for k, v in pairs(radio2g) do t[k] = v end
    for k, v in pairs(radio5g) do t[k] = v end
    return t
end

local function human_readable_size(size)
    if size > 1000000000 then
        return string.format("%.1fGB", size / 1000000000)
    end
    if size > 1000000 then return string.format("%.1fMB", size / 1000000) end
    return string.format("%.1fKB", size / 1000)
end

local function data_usage(wwan_info)
    if wwan_info == nil then return "Connecting" end
    local tx = wwan_info.statistics.tx_bytes
    local rx = wwan_info.statistics.rx_bytes
    return human_readable_size(tx) .. "|" .. human_readable_size(rx)
end

local function network_info()
    local info = conn:call("network.device", "status", {})
    return {
        -- fill some more useful information
        carrier = data_usage(info["wwan0"]),

        -- todo: check actual gateway device
        method_nw = "modem",

        -- todo: communicate with uqmi for actual carrier info
        modem_up = "1",
        signal = "4",
        modem_mode = "4G+",

        -- todo: calculate actual device count
        clients = "1",

        -- todo: customizable or several preset information
        system = "boot",
        lan_ip = "Outbound: JP",
        work_mode = "Direct CN"
    }
end

local function vpn_info()
    return {
        -- todo: customizable or several preset information
        vpn_status = "connected",
        vpn_type = "",
        vpn_server = "192.168.123.8"
    }
end

local function build_request()
    local t = {clock = os.date("%H:%M")}
    for k, v in pairs(vpn_info()) do t[k] = v end
    for k, v in pairs(network_info()) do t[k] = v end
    for k, v in pairs(wireless_info()) do t[k] = v end
    return t
end

local function send_command()
    local t = json.stringify(build_request(), true)
    local f = io.open("/dev/ttyS0", "w")
    io.output(f)
    io.write(t)
    io.close(f)
end

while (true) do
    -- todo: parse output, filter incomplete information and write syslog
    send_command()
    nixio.nanosleep(20)
end
