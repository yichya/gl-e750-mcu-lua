#!/usr/bin/lua

local ubus = require "ubus"
local json = require "luci.jsonc"
local nixio = require "nixio"
local cURL = require "cURL"

local conn = ubus.connect()
if not conn then error("Failed to connect to ubus") end

local get_sys_stats_req = string.char(0, 0, 0, 0, 0)

local function xray_goroutines()
    local count = 0
    local index = 7
    local c = cURL.easy {
        url = "http://127.0.0.1:8080/v2ray.core.app.stats.command.StatsService/GetSysStats",
        post = true,
        httpheader = {"Content-Type: application/grpc", "TE: trailers"},
        postfields = get_sys_stats_req,
        http_version = cURL.HTTP_VERSION_2_PRIOR_KNOWLEDGE,
    }
    c:perform({
        writefunction = function(r)
            -- https://developers.google.com/protocol-buffers/docs/encoding#varints
            repeat
                local curchar = string.byte(r:sub(index, index))
                count = count + nixio.bit.lshift(nixio.bit.band(curchar, 127), 7 * (index - 7))
                index = index + 1
            until nixio.bit.band(curchar, 128) == 0
        end
    }):close()
    return count
end

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

local function wireless_clients()
    local wlan0info = conn:call("iwinfo", "assoclist", {device = "wlan0"})
    if wlan0info == nil then
        wlan0info = {
            results = {}
        }
    end
    local wlan1info = conn:call("iwinfo", "assoclist", {device = "wlan1"})
    if wlan1info == nil then
        wlan1info = {
            results = {}
        }
    end
    return table.getn(wlan0info.results) + table.getn(wlan1info.results)
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
    local t = {
        clients = string.format("%d", wireless_clients())
    }
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
    if wwan_info == nil then
        return "Initializing"
    end
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
        modem_up = "0",
        signal = "0",
        modem_mode = " ",

        -- todo: customizable or several preset information
        work_mode = "Geo CN<>JP"
    }
end

local function load_average()
    local info = conn:call("system", "info", {})
    local load1min = info.load[1] / 65535
    local load5min = info.load[2] / 65535
    local load15min = info.load[3] / 65535
    return {
        lan_ip = string.format("%.2f, %.2f, %.2f", load1min, load5min, load15min)
    }
end

local function vpn_info()
    local ok, xray_pprof_resp = pcall(xray_goroutines)
    if ok then
        return {
            vpn_status = "connected",
            vpn_type = "NumGos:",
            vpn_server = string.format("%d", xray_pprof_resp)
        }
    else
        return {
            vpn_status = "connecting",
            vpn_type = "Xray",
            vpn_server = "Loading"
        }
    end
end

local function build_request()
    local t = {
        system = "boot",
        clock = os.date("%H:%M")
    }
    for k, v in pairs(vpn_info()) do t[k] = v end
    for k, v in pairs(network_info()) do t[k] = v end
    for k, v in pairs(wireless_info()) do t[k] = v end
    for k, v in pairs(load_average()) do t[k] = v end
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
