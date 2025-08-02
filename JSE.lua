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
_addon.version = '1.10'
_addon.commands = {'jse'}

require('chat')
require('lists')
require('logger')
require('sets')
require('tables')
require('strings')
require('pack')

texts = require('texts')
config = require('config')

-- Default settings for the tracking window
local default_settings = T{
    global = {
        Tracker = {
            pos = {
                x = 100,
                y = 100
            },
            bg = {
                alpha = 150,
                red = 0,
                green = 0,
                blue = 0,
                visible = true,
            },
            text = {
                font = 'Arial',
                size = 11,
                alpha = 255,
                red = 255,
                green = 255,
                blue = 255,
                stroke = {
                    width = 2,
                    alpha = 255,
                    red = 0,
                    green = 38,
                    blue = 62
                }
            },
            padding = 5,
            flags = {
                draggable = true,
                bold = true,
                right = true,
            },
        }
    }
}

-- Load the settings file
local settings = config.load('data/settings.xml', default_settings)

-- Initialize the tracking window with loaded settings
local tracking_window = texts.new('', settings.global.Tracker)
local is_tracking = false
local is_minimized = false
local full_content = ''

-- Save settings when window is dragged
windower.register_event('mouse', function(type, x, y, delta, blocked)
    if tracking_window:visible() then
        -- Get the current real-time position of the window
        local pos_x, pos_y = tracking_window:pos()
        local size_x, size_y = tracking_window:size()
        
        -- Check if click is anywhere in the top-left area of the window
        if type == 1 and x >= pos_x and x <= pos_x + 60 and y >= pos_y and y <= pos_y + 20 then
            
            -- Check if it's the close button (pixels 5-25)
            if x >= pos_x + 5 and x <= pos_x + 25 then
                tracking_window:visible(false)
                return true
            -- Check if it's the minimize button (pixels 35-55)
            elseif x >= pos_x + 35 and x <= pos_x + 55 then
                is_minimized = not is_minimized
                -- Refresh the window content with current state
                update_tracking_window(nil)  -- Don't pass new content, just refresh
                return true
            end
        end
        
        -- Save position if window was moved (but don't save on every mouse event)
        local current_settings_x = settings.global.Tracker.pos.x
        local current_settings_y = settings.global.Tracker.pos.y
        if pos_x ~= current_settings_x or pos_y ~= current_settings_y then
            settings.global.Tracker.pos.x = pos_x
            settings.global.Tracker.pos.y = pos_y
            config.save(settings)
        end
    end
end)

-- Function to create color tag
function create_color_tag(type)
    if type == 'header' then
        return '\\cs(255,255,255)' -- White for "Checking equipment..."
    elseif type == 'item_name' then
        return '\\cs(255,255,150)' -- Light yellow for item names
    elseif type == 'upgrade_text' then
        return '\\cs(255,255,255)' -- White for "Can upgrade to"
    elseif type == 'upgrade_level' then
        return '\\cs(255,255,150)' -- Light yellow for "+X"
    elseif type == 'materials_header' then
        return '\\cs(255,255,255)' -- White for "Required materials:"
    elseif type == 'materials_text' then
        return '\\cs(140,200,255)' -- Light blue for materials text
    elseif type == 'number' then
        return '\\cs(255,255,150)' -- Light yellow for numbers
    elseif type == 'card_name' then
        return '\\cs(140,200,255)' -- Light blue for card names
    end
    return '\\cs(255,255,255)' -- Default white
end

-- Function to format a material count with conditional coloring
function format_material_count(current, required)
    current = tonumber(current)
    required = tonumber(required)
    if current >= required then
        return create_color_tag('number') .. current .. '/' .. required .. '\\cr'
    else
        return create_color_tag('header') .. current .. '/' .. create_color_tag('number') .. required .. '\\cr'
    end
end

-- Function to update the tracking window content
function update_tracking_window(content)
    if not is_tracking and content then
        -- If we're being called with new content, we should track it
        is_tracking = true
    elseif not content and not is_tracking and #full_content == 0 then
        -- Only return if we have no content at all and not tracking
        return
    end
    
    -- Store the full content if provided
    if content then
        full_content = content
    end
    
    if #full_content == 0 then
        return
    end
    
    -- Add close and minimize buttons at the top-left
    local first_line_end = full_content:find('\n') or #full_content
    local first_line = full_content:sub(1, first_line_end - 1)
    local rest = full_content:sub(first_line_end)
    
    local buttons = '\\cs(255,100,100)[X]\\cr \\cs(100,255,100)[_]\\cr '
    
    if is_minimized then
        -- Show only the first line with buttons when minimized
        local minimized_content = buttons .. first_line
        tracking_window:text(minimized_content)
    else
        -- Show full content with buttons
        local content_with_buttons = buttons .. first_line .. rest
        tracking_window:text(content_with_buttons)
    end
    
    tracking_window:visible(true)
end

-- Function to capture log output
local captured_output = {}
local original_log = log

-- Override the log function to capture output
function log(message)
    original_log(message)
    if is_tracking then
        local formatted_message = message
        
        -- Remove problematic characters more comprehensively
        formatted_message = formatted_message:gsub('□', '')
        formatted_message = formatted_message:gsub('', '')
        formatted_message = formatted_message:gsub('\239\191\189', '') -- UTF-8 replacement character
        formatted_message = formatted_message:gsub('\226\150\161', '') -- Another square character
        -- Remove FFXI color codes that might contain problematic characters
        formatted_message = formatted_message:gsub('\30[%z\1-\31]', '') -- Remove FFXI color codes
        formatted_message = formatted_message:gsub('\31[%z\1-\31]', '') -- Remove other FFXI codes
        -- Remove any remaining non-printable characters except basic ones we need
        formatted_message = formatted_message:gsub('[^\32-\126\r\n\t]', '')

        -- Format "Checking equipment..."
        if formatted_message:match('Checking .+ equipment...') then
            local job = formatted_message:match('Checking (%w+) equipment...')
            if job then
                formatted_message = create_color_tag('header') .. job .. ' equipment:' .. '\\cr'
            else
                formatted_message = create_color_tag('header') .. formatted_message .. '\\cr'
            end
        
        -- Format item lines with upgrade info
        elseif formatted_message:match('Can upgrade to') then
            local item_name = formatted_message:match('^([^+]+%+%d)')
            local rest = formatted_message:match('^[^:]+:(.+)')
            if item_name and rest then
                formatted_message = create_color_tag('item_name') .. item_name .. '\\cr: ' ..
                                  create_color_tag('upgrade_text') .. 'Can upgrade to ' ..
                                  create_color_tag('upgrade_level') .. rest:match('%+%d') .. '\\cr'
            end
        
        -- Format item lines that say "Not found"
        elseif formatted_message:match(': Not found') then
            local item_name = formatted_message:match('^([^:]+)')
            if item_name then
                formatted_message = create_color_tag('item_name') .. item_name .. '\\cr: Not found'
            end
        
        -- Format item lines that say "Already +4"
        elseif formatted_message:match(': Already %+4') then
            local item_name = formatted_message:match('^([^:]+)')
            if item_name then
                formatted_message = create_color_tag('item_name') .. item_name .. '\\cr: ' .. 
                                  create_color_tag('upgrade_text') .. 'Already +4' .. '\\cr'
            end
        
        -- Format materials lines
        elseif formatted_message:match('%s*Required materials:') then
            -- Keep the header as is
            local header_part = formatted_message:match('(%s*Required materials:)')
            local materials_part = formatted_message:match('%s*Required materials:%s*(.+)')
            
            if header_part and materials_part then
                -- Start with the white header with added space
                formatted_message = create_color_tag('materials_header') .. header_part .. ' \\cr'
                
                -- Simply make all numbers yellow while keeping text blue
                local colored_materials = materials_part:gsub('(%d+)', create_color_tag('number') .. '%1' .. '\\cr' .. create_color_tag('materials_text'))
                
                -- Add the materials with blue text color
                formatted_message = formatted_message .. create_color_tag('materials_text') .. colored_materials .. '\\cr'
            end
        
        -- Format total lines with specific pattern matching
        elseif formatted_message:match('^Total P%.') then
            local before_cards, number = formatted_message:match('^Total (P%. %w+ Cards)[^%d]+(%d+)')
            if before_cards and number then
                formatted_message = create_color_tag('header') .. 'Total ' ..
                                  create_color_tag('materials_text') .. before_cards ..
                                  create_color_tag('header') .. ' needed: ' ..
                                  create_color_tag('number') .. number .. '\\cr'
            end
        elseif formatted_message:match('You currently have:') then
            local number = formatted_message:match('(%d+)')
            if number then
                formatted_message = create_color_tag('header') .. 'You currently have: ' ..
                                  create_color_tag('number') .. number ..
                                  create_color_tag('header') .. ' cards' .. '\\cr'
            end
        elseif formatted_message:match('Additional cards needed:') then
            local number = formatted_message:match('(%d+)')
            if number then
                formatted_message = create_color_tag('header') .. 'Additional cards needed: ' ..
                                  create_color_tag('number') .. number .. '\\cr'
            end
        end

        table.insert(captured_output, formatted_message)
    end
end

-- Function to clear captured output
function clear_captured_output()
    captured_output = {}
end

-- Function to get captured output as a string
function get_captured_output()
    return table.concat(captured_output, '\n')
end

-- Function to handle tracking command
function handle_tracking_command(job, armor_type)
    is_tracking = true
    clear_captured_output()
    
    -- Execute the regular find_cards function
    if armor_type == 'ARTIFACT' then
        find_cards(job, 'ARTIFACT')
    elseif armor_type == 'RELIC' then
        find_cards(job, 'RELIC')
    elseif armor_type == 'EMPYREAN' then
        find_cards(job, 'EMPYREAN')
    end
    
    -- Update the tracking window with captured output
    update_tracking_window(get_captured_output())
    is_tracking = false
end

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
            tracking_window:visible(false)
            return
        elseif args[1]:lower() == 'show' then
            if #captured_output > 0 then
                tracking_window:visible(true)
            else
                log('No tracking data available. Run //jsetrack [af|relic|empy] JOB first.')
            end
            return
        end
        
        if not args[2] then
            log('Usage: //jsetrack [af|relic|empy] JOB')
            return
        end
        
        local armor_type = args[1]:lower()
        local job = args[2]:upper()
        
        if armor_type == 'af' then
            handle_tracking_command(job, 'ARTIFACT')
        elseif armor_type == 'relic' then
            handle_tracking_command(job, 'RELIC')
        elseif armor_type == 'empy' then
            handle_tracking_command(job, 'EMPYREAN')
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

-- Clean up when addon unloads
windower.register_event('unload', function()
    if tracking_window then
        local pos_x, pos_y = tracking_window:pos()
        settings.global.Tracker.pos.x = pos_x
        settings.global.Tracker.pos.y = pos_y
        config.save(settings)
        tracking_window:destroy()
    end
end)

-- Initialize window on load
windower.register_event('load', function()
    if windower.ffxi.get_info().logged_in then
        tracking_window:visible(false)
    end
end)

