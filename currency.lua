-- Currency tracking module for JSE addon
local currency = {}

-- Required modules
local packets = require('packets')
require('logger')

-- Packets for currency values
local cur1packet = {} -- For packet 0x113
local cur2packet = {} -- For packet 0x118
local curpackettype = 0

-- Currency name to packet field mapping (separated by packet)
local currency_mapping = {
    -- Packet 0x118 fields (Currencies 2 menu)
    [0x118] = {
        ["Gallimaufry"] = "Gallimaufry",
        ["Apollyon Units"] = "Apollyon Units",
        ["Temenos Units"] = "Temenos Units"
    },
    -- Packet 0x113 fields (Currencies 1 menu)
    [0x113] = {
        ["Rem's Tale Chapters 1 Stored"] = "Rems Tale Chapter 1",
        ["Rem's Tale Chapters 2 Stored"] = "Rems Tale Chapter 2",
        ["Rem's Tale Chapters 3 Stored"] = "Rems Tale Chapter 3",
        ["Rem's Tale Chapters 4 Stored"] = "Rems Tale Chapter 4",
        ["Rem's Tale Chapters 5 Stored"] = "Rems Tale Chapter 5",
        ["Rem's Tale Chapters 6 Stored"] = "Rems Tale Chapter 6",
        ["Rem's Tale Chapters 7 Stored"] = "Rems Tale Chapter 7",
        ["Rem's Tale Chapters 8 Stored"] = "Rems Tale Chapter 8",
        ["Rem's Tale Chapters 9 Stored"] = "Rems Tale Chapter 9",
        ["Rem's Tale Chapters 10 Stored"] = "Rems Tale Chapter 10"
    }
}

-- List of currencies we care about for JSE upgrades
local tracked_currencies = {
    "Rem's Tale Chapters 1 Stored",
    "Rem's Tale Chapters 2 Stored",
    "Rem's Tale Chapters 3 Stored",
    "Rem's Tale Chapters 4 Stored",
    "Rem's Tale Chapters 5 Stored",
    "Rem's Tale Chapters 6 Stored",
    "Rem's Tale Chapters 7 Stored",
    "Rem's Tale Chapters 8 Stored",
    "Rem's Tale Chapters 9 Stored",
    "Rem's Tale Chapters 10 Stored",
    "Apollyon Units",
    "Temenos Units",
    "Gallimaufry"
}

-- Initialize the currency values
local currency_values = {}
for _, curr in ipairs(tracked_currencies) do
    currency_values[curr] = 0
end

-- Function to update currency values from a specific packet
local function update_currency_values_from_packet(packet_id, packet_data)
    if currency_mapping[packet_id] then
        for curr, packet_field in pairs(currency_mapping[packet_id]) do
            local value = packet_data[packet_field]
            if value then
                currency_values[curr] = tonumber(value) or 0
            end
        end
    end
end

-- Register packet handlers
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
    if id == 0x118 then
        cur2packet = packets.parse('incoming', original)
        curpackettype = 2
        update_currency_values_from_packet(0x118, cur2packet)
    elseif id == 0x113 then
        cur1packet = packets.parse('incoming', original)
        curpackettype = 1
        update_currency_values_from_packet(0x113, cur1packet)
    end
end)

-- Function to request currency updates
function currency.request_update()
    -- Send packet 0x10F for basic currency info
    local packet = packets.new('outgoing', 0x10F)
    packets.inject(packet)

    -- Send packet 0x115 for Currencies 2 menu
    coroutine.schedule(function()
        local packet = packets.new('outgoing', 0x115)
        packets.inject(packet)
    end, 1)
end

-- Function to get a specific currency value
function currency.get_value(currency_name)
    return currency_values[currency_name] or 0
end

-- Function to get all tracked currency values
function currency.get_all_values()
    return currency_values
end

-- Function to display all currency values
function currency.display_values()
    log('Current Currency Values:')
    log('----------------------')
    
    -- Display Rem's Tales
    log("Rem's Tales:")
    for i = 1, 10 do
        local curr = "Rem's Tale Chapters " .. i .. " Stored"
        local value = currency_values[curr] or 0
        log('  ' .. curr .. ': ' .. tostring(value):color(200))
    end
    
    -- Display Units
    log('\nLimbus:')
    local apollyon = currency_values['Apollyon Units'] or 0
    local temenos = currency_values['Temenos Units'] or 0
    log('  Apollyon Units: ' .. tostring(apollyon):color(200))
    log('  Temenos Units: ' .. tostring(temenos):color(200))
    
    -- Display Other
    log('\nSortie:')
    local gallimaufry = currency_values['Gallimaufry'] or 0
    log('  Gallimaufry: ' .. tostring(gallimaufry):color(200))
end

-- Function to get the raw packet data for debugging
function currency.get_debug_packet()
    return cur2packet
end

-- Initialize currency values on load
currency.request_update()

return currency 