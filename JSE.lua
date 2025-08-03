--[[
Copyright © 2025, Nalfey of Asura
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of JSE nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Nalfey BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name    = 'JSE'
_addon.author  = 'Nalfey'
_addon.version = '1.11'
_addon.commands = {'jse'}

require('chat')
require('lists')
require('logger')
require('sets')
require('tables')
require('strings')
require('pack')

-- Load tracking module for window functionality
tracking = require('tracking')

file = require('files')
slips = require('slips')
res = require('resources')
job_equipment = require('job_equipment')
currency = require('currency')
inventory = require('inventory')

zone_search = windower.ffxi.get_info().logged_in
first_pass = true
item_names = T{}
key_item_names = T{}
global_storages = T{}

-- JSE-specific storage slip ordering
local storage_slips_order = slips.storages:map(function(id)
    return 'slip ' .. res.items[id].english:lower():match('^storage slip (.*)$')
end)
merged_storages_orders = inventory.storages_order + storage_slips_order + L{'key items'}

function update()
    if not windower.ffxi.get_info().logged_in then
        error('You have to be logged in to use this addon.')
        return false
    end

    if zone_search == false then
        notice('JSE has not detected a fully loaded inventory yet.')
        return false
    end

    local player_name = windower.ffxi.get_player().name
    local local_storage = inventory.get_local_storage()
    if not local_storage then
        return false
    end

    global_storages[player_name] = local_storage
    return inventory.update()
end

function update_global_storage()
    global_storages = inventory.update_global_storage()
end

windower.register_event('incoming chunk', function(id,original,modified,injected,blocked)
    local seq = original:unpack('H',3)
    if (next_sequence and seq == next_sequence) and zone_search then
        inventory.update()
        next_sequence = nil
    end

    if id == 0x00B then 
        zone_search = false
    elseif id == 0x00A then 
        zone_search = false
    elseif id == 0x01D and not zone_search then
        zone_search = true
        next_sequence = (seq+22)%0x10000 
    elseif (id == 0x1E or id == 0x1F or id == 0x20) and zone_search then
        next_sequence = (seq+22)%0x10000
    end
end)

windower.register_event('ipc message', function(str)
    if str == 'jse update' then
        inventory.update()
    end
end)

handle_command = function(...)
    local params = L{...}
    if not params[1] or not params[2] then
        log('Usage:')
        log('  //jse [af|relic|empy] JOB - Check equipment and upgrade materials for a specific job')
        log('  //jseall [af|relic|empy] JOB - Check equipment across all characters')
        log('  //jsehelp - Display this help message')
        return
    end
    local armor_type = params[1]:lower()
    local job = params[2]:upper()
    
    if armor_type == 'af' then
        find_cards(job, 'ARTIFACT')
    elseif armor_type == 'relic' then
        find_cards(job, 'RELIC')
    elseif armor_type == 'empy' then
        find_cards(job, 'EMPYREAN')
    else
        log('Invalid armor type. Use: af, relic, or empy')
        return
    end
end

windower.register_event('unhandled command', function(command, ...)
    local args = T{...}
    if command:lower() == 'jsehelp' then
        log('JSE Addon Commands:')
        log('Artifact Commands:')
        log('  //jse af JOB - Check artifact equipment and upgrade materials for a specific job')
        log('  //jseall af JOB - Check artifact equipment across all characters')
        log('  //jsetrack af JOB - Check artifact equipment and display in tracking window')
        log('Relic Commands:')
        log('  //jse relic JOB - Check relic equipment and upgrade materials for a specific job')
        log('  //jsetrack relic JOB - Check relic equipment and display in tracking window')
        log('Empyrean Commands:')
        log('  //jse empy JOB - Check empyrean equipment and upgrade materials for a specific job')
        log('  //jsetrack empy JOB - Check empyrean equipment and display in tracking window')
        log('Currency Commands:')
        log('  //jsecurrency - Display tracked currencies and their values')
        log('  //jsecurrencydebug - Display debug information about currency values')
        log('Window Commands:')
        log('  //jsetrack hide - Hide the tracking window')
        log('  //jsetrack show - Show the tracking window')
        log('  //jsehelp - Display this help message')
        return
    elseif command:lower() == 'jsetrack' then
        if not args[1] then
            log('Usage: //jsetrack [af|relic|empy] JOB')
            log('       //jsetrack [hide|show]')
            return
        end
        
        if args[1]:lower() == 'hide' then
            tracking.hide_window()
            return
        elseif args[1]:lower() == 'show' then
            tracking.show_window()
            return
        end
        
        if not args[2] then
            log('Usage: //jsetrack [af|relic|empy] JOB')
            return
        end
        
        local armor_type = args[1]:lower()
        local job = args[2]:upper()
        
        if armor_type == 'af' then
            tracking.start_tracking()
            find_cards(job, 'ARTIFACT')
            tracking.stop_tracking()
        elseif armor_type == 'relic' then
            tracking.start_tracking()
            find_cards(job, 'RELIC')
            tracking.stop_tracking()
        elseif armor_type == 'empy' then
            tracking.start_tracking()
            find_cards(job, 'EMPYREAN')
            tracking.stop_tracking()
        else
            log('Invalid armor type. Use: af, relic, or empy')
            return
        end
    elseif command:lower() == 'jsecurrency' then
        -- Request an update of currency values before displaying
        currency.request_update()
        -- Display the currency values
        currency.display_values()
        return
    elseif command:lower() == 'jsecurrencydebug' then
        -- Request an update of currency values before displaying debug info
        currency.request_update()
        -- Get and display the raw packet data
        local packet_data = currency.get_debug_packet()
        log('Packet 0x118 Debug Information:')
        log('----------------------------')
        -- Display all fields in the packet
        for field, value in pairs(packet_data) do
            if type(value) ~= 'function' then  -- Skip function fields
                log(field .. ': ' .. tostring(value))
            end
        end
        return
    elseif command:lower() == 'jse' then
        if not args[1] or not args[2] then
            log('Usage: //jse [af|relic|empy] JOB')
            return
        end
        local armor_type = args[1]:lower()
        local job = args[2]:upper()
        
        if armor_type == 'af' then
            find_cards(job, 'ARTIFACT')
        elseif armor_type == 'relic' then
            find_cards(job, 'RELIC')
        elseif armor_type == 'empy' then
            find_cards(job, 'EMPYREAN')
        else
            log('Invalid armor type. Use: af, relic, or empy')
            return
        end
    elseif command:lower() == 'jseall' then
        if not args[1] or not args[2] then
            log('Usage: //jseall [af|relic|empy] JOB')
            return
        end
        local armor_type = args[1]:lower()
        local job = args[2]:upper()
        
        if armor_type == 'af' then
            find_cards_all(job, 'ARTIFACT')
        elseif armor_type == 'relic' then
            find_cards_all(job, 'RELIC')
        elseif armor_type == 'empy' then
            find_cards_all(job, 'EMPYREAN')
        else
            log('Invalid armor type. Use: af, relic, or empy')
        end
    end
end)

windower.register_event('addon command', handle_command)

function find_cards(job, armor_type)
    if not job_equipment[job] or not job_equipment[job][armor_type] then
        log('No ' .. armor_type:lower() .. ' equipment data found for job: ' .. job)
        return
    end

    -- Ensure we're logged in and storage is up to date
    if not windower.ffxi.get_info().logged_in then
        error('You have to be logged in to use this command.')
        return
    end

    if not update() then
        error('Failed to update storage information.')
        return
    end

    -- Request an update of currency values and wait briefly for the response
    currency.request_update()
    coroutine.sleep(1)

    local total_cards = 0
    local has_upgrades = false
    local card_name = 'P. ' .. job .. ' Card'
    local player_name = windower.ffxi.get_player().name
    
    log('Checking ' .. job .. ' equipment...')
    
    -- Get fresh storage data
    local local_storage = inventory.get_local_storage()
    
    -- Only count cards for ARTIFACT equipment
    local existing_cards = 0
    if armor_type == 'ARTIFACT' then
        for storage_name, items in pairs(local_storage) do
            if storage_name ~= 'gil' and storage_name ~= 'key items' then
                for item_id, quantity in pairs(items) do
                    local item = res.items[tonumber(item_id)]
                    if item and item.name == card_name then
                        existing_cards = existing_cards + quantity
                    end
                end
            end
        end
    end

    -- Helper function to map material names to currency names
    local function map_currency_name(material_name)
        -- Handle Rem's Tales chapter name mapping
        local chapter = material_name:match("^Rem's Tale Ch%.(%d+)$")
        if chapter then
            local mapped_name = "Rem's Tale Chapters " .. chapter .. " Stored"
            return mapped_name
        end
        -- Handle other currency mappings
        local currency_mappings = {
            ["Gallimaufry"] = "Gallimaufry",
            ["Apollyon Units"] = "Apollyon Units",
            ["Temenos Units"] = "Temenos Units"
        }
        return currency_mappings[material_name] or material_name
    end

    -- Helper function to get currency count
    local function get_currency_count(material_name)
        -- Map the material name to its currency name
        local currency_name = map_currency_name(material_name)
        
        -- Check if this is a tracked currency
        if currency_name:match("^Rem's Tale Chapters %d+ Stored$") or
           currency_name:match("Units$") or
           currency_name == "Gallimaufry" then
            local value = currency.get_value(currency_name)
            return value or 0
        end
        
        -- If not a currency, check all storage locations
        local count = 0
        for storage_name, items in pairs(local_storage) do
            if storage_name ~= 'gil' and storage_name ~= 'key items' then
                for item_id, quantity in pairs(items) do
                    local item = res.items[tonumber(item_id)]
                    if item and item.name == material_name then
                        count = count + quantity
                    end
                end
            end
        end
        return count
    end

    -- Helper function to display materials
    local function display_materials(mats)
        if not mats then return end
        local mat_strings = {}
        for _, mat in ipairs(mats) do
            local count = get_currency_count(mat.name)
            local color = count >= mat.count and 200 or 167
            local count_str = count >= mat.count 
                and tostring(count):color(200)
                or tostring(count)
            table.insert(mat_strings, mat.name .. ': ' .. count_str .. '/' .. tostring(mat.count):color(color))
        end
        if #mat_strings > 0 then
            log('  Required materials: ' .. table.concat(mat_strings, ', '))
        end
    end
    
    -- Check the specified armor type
    for index, equip_data in ipairs(job_equipment[job][armor_type]) do
        local equip_names = equip_data[1]
        local cards_needed = equip_data[2]
        local materials = equip_data[3]
        local base_name = equip_names[1]
        local found_plus4 = false
        local found_plus3 = false
        local found_plus2 = false
        local found_plus1 = false
        local found_nq = false
        
        for storage_name, items in pairs(local_storage) do
            if storage_name ~= 'gil' and storage_name ~= 'key items' then
                for item_id, quantity in pairs(items) do
                    local item = res.items[tonumber(item_id)]
                    if item and item.name then
                        for _, name in ipairs(equip_names) do
                            if name then
                                local plus1_name = name .. ' +1'
                                local plus2_name = name .. ' +2'
                                local plus3_name = name .. ' +3'
                                local plus4_name = name .. ' +4'
                                
                                if item.name == plus4_name then
                                    found_plus4 = true
                                    log(base_name:color(255) .. ': ' .. 'Already +4':color(158))
                                    break
                                elseif item.name == plus3_name then
                                    found_plus3 = true
                                elseif item.name == plus2_name then
                                    found_plus2 = true
                                elseif item.name == plus1_name then
                                    found_plus1 = true
                                elseif item.name == name then
                                    found_nq = true
                                end
                            end
                        end
                    end
                    if found_plus4 then break end
                end
            end
            if found_plus4 then break end
        end
        
        if not found_plus4 then
            has_upgrades = true
            if found_plus3 then
                if materials and materials["+4"] then
                    for _, mat in ipairs(materials["+4"]) do
                        if mat.name:match("Units$") then
                            log((base_name .. ' +3'):color(255) .. ': Can upgrade to ' .. '+4':color(158))
                            display_materials(materials["+4"])
                            break
                        end
                    end
                else
                    log((base_name .. ' +3'):color(255))
                end
            elseif found_plus2 then
                if armor_type == 'ARTIFACT' then
                    local plus2_cards
                    if index == 1 then plus2_cards = 12
                    elseif index == 2 then plus2_cards = 15
                    elseif index == 3 then plus2_cards = 9
                    elseif index == 4 then plus2_cards = 12
                    elseif index == 5 then plus2_cards = 9 end
                    total_cards = total_cards + plus2_cards
                    log((base_name .. ' +2'):color(255) .. ': Can upgrade to ' .. '+3':color(158))
                    if materials and materials["+3"] then
                        display_materials(materials["+3"])
                    end
                else
                    log((base_name .. ' +2'):color(255) .. ': Can upgrade to ' .. '+3':color(158))
                    if materials and materials["+3"] then
                        display_materials(materials["+3"])
                    end
                end
            elseif found_plus1 then
                if armor_type == 'ARTIFACT' then
                    total_cards = total_cards + cards_needed
                    log((base_name .. ' +1'):color(255) .. ': Can upgrade to ' .. '+2':color(158))
                    if materials and materials["+2"] then
                        display_materials(materials["+2"])
                    end
                else
                    log((base_name .. ' +1'):color(255) .. ': Can upgrade to ' .. '+2':color(158))
                    if materials and materials["+2"] then
                        display_materials(materials["+2"])
                    end
                end
            elseif found_nq then
                if armor_type == 'ARTIFACT' then
                    total_cards = total_cards + cards_needed
                    log(base_name:color(255) .. ': Can upgrade to ' .. '+1':color(158))
                    if materials and materials["+1"] then
                        display_materials(materials["+1"])
                    end
                else
                    log(base_name:color(255) .. ': Can upgrade to ' .. '+1':color(158))
                    if materials and materials["+1"] then
                        display_materials(materials["+1"])
                    end
                end
            else
                log(base_name:color(255) .. ': Not found')
            end
        end
    end
    
    if armor_type == 'ARTIFACT' and total_cards > 0 then
        log('Total ' .. card_name .. 's needed: ' .. tostring(total_cards):color(158))
        log('You currently have: ' .. tostring(existing_cards):color(158) .. ' cards')
        local remaining_cards = total_cards - existing_cards
        if remaining_cards > 0 then
            log('Additional cards needed: ' .. tostring(remaining_cards):color(158))
        end
    elseif not has_upgrades then
        log('No upgrades needed')
        if armor_type == 'ARTIFACT' then
            log('You currently have: ' .. tostring(existing_cards):color(158) .. ' cards')
        end
    end
end

windower.register_event('load', function()
    if windower.ffxi.get_info().logged_in then
        inventory.update()
    end
end)

windower.register_event('login', function()
    inventory.update()
end)

function find_cards_all(job, armor_type)
    if not job_equipment[job] or not job_equipment[job][armor_type] then
        log('No ' .. armor_type:lower() .. ' equipment data found for job: ' .. job)
        return
    end

    -- First, check equipment on current character
    if not windower.ffxi.get_info().logged_in then
        error('You have to be logged in to use this command.')
        return
    end

    if not update() then
        error('Failed to update storage information.')
        return
    end

    -- Request an update of currency values and wait briefly for the response
    currency.request_update()
    coroutine.sleep(1)

    local total_cards = 0
    local has_upgrades = false
    local card_name = 'P. ' .. job .. ' Card'
    local player_name = windower.ffxi.get_player().name
    
    log('Checking ' .. job .. ' equipment...')

    -- Helper function to map material names to currency names
    local function map_currency_name(material_name)
        -- Handle Rem's Tales chapter name mapping
        local chapter = material_name:match("^Rem's Tale Ch%.(%d+)$")
        if chapter then
            local mapped_name = "Rem's Tale Chapters " .. chapter .. " Stored"
            return mapped_name
        end
        -- Handle other currency mappings
        local currency_mappings = {
            ["Gallimaufry"] = "Gallimaufry",
            ["Apollyon Units"] = "Apollyon Units",
            ["Temenos Units"] = "Temenos Units"
        }
        return currency_mappings[material_name] or material_name
    end

    -- Helper function to get currency count
    local function get_currency_count(material_name)
        -- Map the material name to its currency name
        local currency_name = map_currency_name(material_name)
        
        -- Check if this is a tracked currency
        if currency_name:match("^Rem's Tale Chapters %d+ Stored$") or
           currency_name:match("Units$") or
           currency_name == "Gallimaufry" then
            local value = currency.get_value(currency_name)
            return value or 0
        end
        
        -- If not a currency, check all storage locations
        local count = 0
        for storage_name, items in pairs(global_storages[player_name]) do
            if storage_name ~= 'gil' and storage_name ~= 'key items' then
                for item_id, quantity in pairs(items) do
                    local item = res.items[tonumber(item_id)]
                    if item and item.name == material_name then
                        count = count + quantity
                    end
                end
            end
        end
        return count
    end

    -- Helper function to display materials
    local function display_materials(mats)
        if not mats then return end
        local mat_strings = {}
        for _, mat in ipairs(mats) do
            local count = get_currency_count(mat.name)
            local color = count >= mat.count and 200 or 167
            local count_str = count >= mat.count 
                and tostring(count):color(200)
                or tostring(count)
            table.insert(mat_strings, mat.name .. ': ' .. count_str .. '/' .. tostring(mat.count):color(color))
        end
        if #mat_strings > 0 then
            log('  Required materials: ' .. table.concat(mat_strings, ', '))
        end
    end
    
    -- Check the specified armor type for current character
    for index, equip_data in ipairs(job_equipment[job][armor_type]) do
        local equip_names = equip_data[1]
        local cards_needed = equip_data[2]
        local materials = equip_data[3]
        local base_name = equip_names[1]
        local found_plus4 = false
        local found_plus3 = false
        local found_plus2 = false
        local found_plus1 = false
        local found_nq = false
        
        local storages = global_storages[player_name]
        if storages then
            for storage_name, items in pairs(storages) do
                if storage_name ~= 'gil' and storage_name ~= 'key items' then
                    for item_id, quantity in pairs(items) do
                        local item = res.items[tonumber(item_id)]
                        if item and item.name then
                            for _, name in ipairs(equip_names) do
                                if name then
                                    local plus1_name = name .. ' +1'
                                    local plus2_name = name .. ' +2'
                                    local plus3_name = name .. ' +3'
                                    local plus4_name = name .. ' +4'
                                    
                                    if item.name == plus4_name then
                                        found_plus4 = true
                                        log(base_name:color(255) .. ': ' .. 'Already +4':color(158))
                                        break
                                    elseif item.name == plus3_name then
                                        found_plus3 = true
                                    elseif item.name == plus2_name then
                                        found_plus2 = true
                                    elseif item.name == plus1_name then
                                        found_plus1 = true
                                    elseif item.name == name then
                                        found_nq = true
                                    end
                                end
                            end
                        end
                        if found_plus4 then break end
                    end
                end
                if found_plus4 then break end
            end
        end
        
        if not found_plus4 then
            has_upgrades = true
            if found_plus3 then
                if materials and materials["+4"] then
                    for _, mat in ipairs(materials["+4"]) do
                        if mat.name:match("Units$") then
                            log((base_name .. ' +3'):color(255) .. ': Can upgrade to ' .. '+4':color(158))
                            display_materials(materials["+4"])
                            break
                        end
                    end
                else
                    log((base_name .. ' +3'):color(255))
                end
            elseif found_plus2 then
                if armor_type == 'ARTIFACT' then
                    local plus2_cards
                    if index == 1 then plus2_cards = 12
                    elseif index == 2 then plus2_cards = 15
                    elseif index == 3 then plus2_cards = 9
                    elseif index == 4 then plus2_cards = 12
                    elseif index == 5 then plus2_cards = 9 end
                    total_cards = total_cards + plus2_cards
                    log((base_name .. ' +2'):color(255) .. ': Can upgrade to ' .. '+3':color(158))
                    if materials and materials["+3"] then
                        display_materials(materials["+3"])
                    end
                else
                    log((base_name .. ' +2'):color(255) .. ': Can upgrade to ' .. '+3':color(158))
                    if materials and materials["+3"] then
                        display_materials(materials["+3"])
                    end
                end
            elseif found_plus1 then
                if armor_type == 'ARTIFACT' then
                    total_cards = total_cards + cards_needed
                    log((base_name .. ' +1'):color(255) .. ': Can upgrade to ' .. '+2':color(158))
                    if materials and materials["+2"] then
                        display_materials(materials["+2"])
                    end
                else
                    log((base_name .. ' +1'):color(255) .. ': Can upgrade to ' .. '+2':color(158))
                    if materials and materials["+2"] then
                        display_materials(materials["+2"])
                    end
                end
            elseif found_nq then
                if armor_type == 'ARTIFACT' then
                    total_cards = total_cards + cards_needed
                    log(base_name:color(255) .. ': Can upgrade to ' .. '+1':color(158))
                    if materials and materials["+1"] then
                        display_materials(materials["+1"])
                    end
                else
                    log(base_name:color(255) .. ': Can upgrade to ' .. '+1':color(158))
                    if materials and materials["+1"] then
                        display_materials(materials["+1"])
                    end
                end
            else
                log(base_name:color(255) .. ': Not found')
            end
        end
    end

    -- Check all characters for cards only if it's ARTIFACT armor
    if armor_type == 'ARTIFACT' then
        update_global_storage()
        local total_available_cards = 0
        local cards_by_char = {}
        
        for char_name, storage in pairs(global_storages) do
            local char_cards = 0
            for storage_name, items in pairs(storage) do
                if storage_name ~= 'gil' and storage_name ~= 'key items' then
                    for item_id, quantity in pairs(items) do
                        local item = res.items[tonumber(item_id)]
                        if item and item.name == card_name then
                            char_cards = char_cards + quantity
                        end
                    end
                end
            end
            if char_cards > 0 then
                cards_by_char[char_name] = char_cards
                total_available_cards = total_available_cards + char_cards
            end
        end

        -- Display card results for ARTIFACT only
        if total_cards > 0 then
            log('Total ' .. card_name .. 's needed: ' .. tostring(total_cards):color(158))
            log('Available cards by character:')
            for char_name, count in pairs(cards_by_char) do
                log('  ' .. char_name .. ': ' .. tostring(count):color(158))
            end
            log('Total available cards: ' .. tostring(total_available_cards):color(158))
            
            local remaining_cards = total_cards - total_available_cards
            if remaining_cards > 0 then
                log('Additional cards needed: ' .. tostring(remaining_cards):color(158))
            end
        end
    end

    if not has_upgrades then
        log('No upgrades needed')
    end
end
