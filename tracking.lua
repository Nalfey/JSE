--[[
JSE Tracking Window Module
Handles the draggable window display for JSE equipment tracking
]]

local tracking = {}

local texts = require('texts')
local config = require('config')

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
local captured_output = {}
local original_log = log

-- Function to create color tag
local function create_color_tag(type)
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
local function format_material_count(current, required)
    current = tonumber(current)
    required = tonumber(required)
    if current >= required then
        return create_color_tag('number') .. current .. '/' .. required .. '\\cr'
    else
        return create_color_tag('header') .. current .. '/' .. create_color_tag('number') .. required .. '\\cr'
    end
end

-- Function to update the tracking window content
local function update_tracking_window(content)
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

-- Override the log function to capture output
local function log_override(message)
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
local function clear_captured_output()
    captured_output = {}
end

-- Function to get captured output as a string
local function get_captured_output()
    return table.concat(captured_output, '\n')
end

-- Initialize tracking system
local function initialize()
    -- Override the global log function
    log = log_override
    
    -- Set up mouse event handling
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
end

-- Public interface functions
function tracking.start_tracking()
    is_tracking = true
    clear_captured_output()
end

function tracking.stop_tracking()
    is_tracking = false
    -- Update the tracking window with captured output
    update_tracking_window(get_captured_output())
end

function tracking.hide_window()
    tracking_window:visible(false)
end

function tracking.show_window()
    if #captured_output > 0 then
        tracking_window:visible(true)
    else
        log('No tracking data available. Run //jsetrack [af|relic|empy] JOB first.')
    end
end

function tracking.is_tracking()
    return is_tracking
end

function tracking.has_content()
    return #captured_output > 0
end

-- Initialize the tracking system
initialize()

return tracking