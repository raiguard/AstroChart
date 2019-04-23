debug = false
data = {}

function Initialize()

    dofile(SKIN:MakePathAbsolute('@Resources\\Scripts\\SunCalc.lua'))

    return 'Success!'

end

-- generates all of the data and translates it into a format usable by the skin.
-- invoke through a !CommandMeasure bang.
-- all time-related outputs are given as Windows FILETIME values.
-- all angle-related outputs are given in radians.
function GenerateData(timestamp, latitude, longitude, tzOffset)

    -- setup timestamps
    local timestamp, mDate, zDate, ysDate, tmDate = SetupTimestamps(timestamp, tzOffset)
    -- RmLog('timestamp: ' .. timestamp)
    -- RmLog('mDate: ' .. mDate .. ' zDate: ' .. zDate .. ' ysDate: ' .. ysDate .. ' tmDate: ' .. tmDate)

    -- retrieve data tables from SunCalc script
    data.sunTimes = SunCalc.getTimes(mDate, latitude, longitude)
    data.moonTimes = SunCalc.getMoonTimes(zDate, latitude, longitude)
    data.sunPosition = SunCalc.getPosition(mDate, latitude, longitude)
    data.moonPosition = SunCalc.getMoonPosition(mDate, latitude, longitude)
    data.moonIllumination = SunCalc.getMoonIllumination(mDate, latitude, longitude)

    -- fix moonrise / moonset times if necessary
    if data.moonTimes.rise ~= nil and (data.moonTimes.set == nil or data.moonTimes.set < data.moonTimes.rise and mDate > data.moonTimes.set) then
        -- set moonset to that of the next day
        data.moonTimes.set = SunCalc.getMoonTimes(tmDate, latitude, longitude)['set']
    elseif data.moonTimes.rise == nil or (data.moonTimes.set < data.moonTimes.rise and mDate < data.moonTimes.set) then
        -- set moonrise to that of the previous day
        data.moonTimes.rise = SunCalc.getMoonTimes(ysDate, latitude, longitude)['rise']
    end

    -- convert timestamps back to FILETIME
    data.sunTimes = ConvertTime(data.sunTimes, 'Windows', true, tzOffset)
    data.moonTimes = ConvertTime(data.moonTimes, 'Windows', true, tzOffset)
    data.timestamps = ConvertTime({ timestamp = timestamp, mDate = mDate, zDate = zDate, ysDate = ysDate, tmDate = tmDate }, 'Windows', true, tzOffset)
    -- data.timestamps.timestamp = ConvertTime(timestamp

    -- add moon phase name info
    data.moonIllumination.phaseName = GetMoonPhaseName(data.moonIllumination.phase)

    -- debug logging
    RmLog(data, 'data')

    -- generate paths
    GeneratePaths(mDate, latitude, longitude)

    SKIN:Bang('!EnableMeasureGroup', 'SunCalc')
    SKIN:Bang('!UpdateMeasureGroup', 'SunCalc')
    SKIN:Bang('!UpdateMeterGroup', 'SunCalc')
    SKIN:Bang('!Redraw')

end

function GeneratePaths(mDate, lat, long)

    local meter = SELF:GetOption('PathMeter')
    local chart_width = SELF:GetOption('ChartWidth')
    local chart_height = SELF:GetOption('ChartHeight')
    local time_start = mDate - (12 * 60 * 60 * 1000)
    local time_div = (24 * 60 * 60 * 1000) / chart_width

    RmLog({ mDate, meter, chart_width, chart_height, time_start, time_div }, 'pathMeterInfo')

    local sun_points = {}
    local moon_points = {}

    for i=1,chart_width do
        sun_points[i] = i .. ',' .. ((chart_height / 2) - (SunCalc.getPosition(time_start + (time_div * (i - 1)), lat, long).altitude / (math.pi / 2)) * (chart_height / 2))
        moon_points[i] = i .. ',' .. ((chart_height / 2) - (SunCalc.getMoonPosition(time_start + (time_div * (i - 1)), lat, long).altitude / (math.pi / 2)) * (chart_height / 2))
    end

    SKIN:Bang('!SetOption', meter, 'SunPath', '0,(#chartHeight# / 2) | LineTo ' .. table.concat(sun_points, ' | LineTo ') .. '| LineTo #chartWidth#,(#chartHeight# / 2) | ClosePath 1')
    SKIN:Bang('!SetOption', meter, 'MoonPath', '0,(#chartHeight# / 2) | LineTo ' .. table.concat(moon_points, ' | LineTo ') .. '| LineTo #chartWidth#,(#chartHeight# / 2) | ClosePath 1')

    RmLog(sun_points, 'sun_points')

end

-- ------------------------------
-- UTILITIES

-- retrieves data from the data table using inline LUA in the skin
function GetData(key, value) return data[key] and data[key][value] or 0 end

-- sets up and returns several useful timestamps
function SetupTimestamps(timestamp)

    local localTz = (GetTimeOffset() / 3600)
    -- convert Windows timestamp (0 = 1/1/1601) to Unix/Lua timestamp (0 = 1/1/1970)
    timestamp = ConvertTime(timestamp, 'Unix', false, localTz * -1)
    tDate = os.date("!*t", timestamp)
    RmLog(tDate, 'tDate')
    mDate = tonumber(tostring(timestamp) .. '000')   
    zDate = tonumber(tostring(os.time{ year = tDate.year, month = tDate.month, day = tDate.day, hour = 0, min = 0, sec = 0 }) .. '000')
    ysDate = zDate - 86400000  
    tmDate =  zDate + 86400000
    -- RmLog('mDate: ' .. mDate .. ' zDate: ' .. zDate .. ' ysDate: ' .. ysDate .. ' tmDate: ' .. tmDate)

    return timestamp, -- current unix epoch timestamp value
           mDate,     -- 'millisecond date' (timestamp with three extra zeroes)
           zDate,     -- timestamp at current day, 0:00:00 (12:00 AM)
           ysDate,    -- timestamp at yesterday, 0:00:00 (12:00 AM)
           tmDate     -- timestamp at tomorrow, 0:00:00 (12:00 AM)

end

-- converts between windows and unix epoch timestamps, with an optional timezone offset
function ConvertTime(n, to, mode, tzOffset)

    if tzOffset == nil then tzOffset = 0 end

	local Formats = {
		Unix    = -1,
		Windows = 1
    }

    if type(n) == 'table' then
        for k,t in pairs(n) do
            n[k] = ConvertTime(t, to, mode, tzOffset)
        end
        return n
    end
    
    return Formats[to] and (mode and tonumber(tostring(n):sub(1,10)) or n) + (11644473600 * Formats[to]) + (tzOffset * 3600) or nil

end

function GetTimeOffset() return (os.time() - os.time(os.date('!*t')) + (os.date('*t')['isdst'] and 3600 or 0)) end

moonPhases = {
    { 0.00, 0.03, 'New Moon'        },
    { 0.03, 0.23, 'Waxing Crescent' },
    { 0.23, 0.27, 'First Quarter'   },
    { 0.27, 0.48, 'Waxing Gibbous'  },
    { 0.48, 0.52, 'Full Moon'       },
    { 0.52, 0.73, 'Waning Gibbous'  },
    { 0.73, 0.77, 'Last Quarter'    },
    { 0.77, 0.98, 'Waning Crescent' },
    { 0.98, 1.01, 'New Moon'        }
}

function GetMoonPhaseName(phase)

    for i,v in pairs(moonPhases) do
        if phase >= v[1] and phase < v[2] then return v[3] end
    end

    return 'WTF?'

end

-- writes the given string or table to the rainmeter log
function RmLog(...)

    if debug == nil then debug = false end
    if printIndent == nil then printIndent = '' end
      
    if type(arg[1]) == 'table' then
        if arg[3] == nil then arg[3] = 'Debug' end
        if arg[3] == 'Debug' and debug == false then return end

        RmLog(printIndent .. arg[2] .. ' = {')
        local pI = printIndent
        printIndent = printIndent .. '    '
        for k,v in pairs(arg[1]) do
            if type(v) == 'table' then
                RmLog(v, k, arg[3])
            else
                RmLog(printIndent .. tostring(k) .. ' = ' .. tostring(v), arg[3])
            end
        end
        printIndent = pI
        RmLog(printIndent .. '}', arg[3])
    else
        if arg[2] == nil then arg[2] = 'Debug' end
        if arg[2] == 'Debug' and debug == false then return end
        SKIN:Bang("!Log", arg[1], arg[2])
    end
      
end