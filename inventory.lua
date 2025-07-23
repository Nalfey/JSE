-- Inventory management module for JSE addon
local inventory = {}

-- Required modules
require('chat')
require('lists')
require('logger')
require('sets')
require('tables')
require('strings')
require('pack')
res = require('resources')
texts = require('texts')
config = require('config')

-- Local variables and settings
local defaults = {}
defaults.Track = ''
defaults.Tracker = {}
defaults.KeyItemDisplay = true

local settings = config.load(defaults)
local tracker = texts.new(settings.Track, settings.Tracker, settings)

local storages_path = windower.addon_path..'data\\'
local storages_order_tokens = L{'temporary', 'inventory', 'wardrobe', 'wardrobe 2', 'wardrobe 3', 'wardrobe 4', 'wardrobe 5', 'wardrobe 6', 'wardrobe 7', 'wardrobe 8', 'safe', 'safe 2', 'storage', 'locker', 'satchel', 'sack', 'case'}
local storages_order = S(res.bags:map(string.gsub-{' ', ''} .. string.lower .. table.get-{'english'})):sort(function(name1, name2)
    local index1 = storages_order_tokens:find(name1)
    local index2 = storages_order_tokens:find(name2)

    if not index1 and not index2 then
        return name1 < name2
    end

    if not index1 then
        return false
    end

    if not index2 then
        return true
    end

    return index1 < index2
end)

-- Initialize tracker
do
    config.register(settings, function(settings)
        tracker:text(settings.Track)
        tracker:visible(settings.Track ~= '' and windower.ffxi.get_info().logged_in)
    end)

    local bag_ids = res.bags:rekey('english'):key_map(string.lower):map(table.get-{'id'})
    local variable_cache = S{}

    tracker:register_event('reload', function()
        for variable in tracker:it() do
            local bag_name, search = variable:match('(.*):(.*)')

            local bag = bag_name == 'all' and 'all' or bag_ids[bag_name:lower()]
            if not bag and bag_name ~= 'all' then
                warning('Unknown bag: %s':format(bag_name))
            else
                if not S{'$freespace', '$usedspace', '$maxspace'}:contains(search:lower()) then
                    local items = S(res.items:name(windower.wc_match-{search})) + S(res.items:name_log(windower.wc_match-{search}))
                    if items:empty() then
                        warning('No items matching "%s" found.':format(search))
                    else
                        variable_cache:add({
                            name = variable,
                            bag = bag,
                            type = 'item',
                            ids = items:map(table.get-{'id'}),
                            search = search,
                        })
                    end
                else
                    variable_cache:add({
                        name = variable,
                        bag = bag,
                        type = 'info',
                        search = search,
                    })
                end
            end
        end
    end)

    do
        local update = T{}

        local search_bag = function(bag, ids)
            return bag:filter(function(item)
                return type(item) == 'table' and ids:contains(item.id)
            end):reduce(function(acc, item)
                return type(item) == 'table' and item.count + acc or acc
            end, 0)
        end

        local last_check = 0

        windower.register_event('prerender', function()
            if os.clock() - last_check < 0.25 then
                return
            end
            last_check = os.clock()

            local items = T{}
            for variable in variable_cache:it() do
                if variable.type == 'info' then
                    local info
                    if variable.bag == 'all' then
                        info = {
                            max = 0,
                            count = 0
                        }
                        for bag_info in T(windower.ffxi.get_bag_info()):it() do
                            info.max = info.max + bag_info.max
                            info.count = info.count + bag_info.count
                        end
                    else
                        info = windower.ffxi.get_bag_info(variable.bag)
                    end

                    update[variable.name] =
                        variable.search == '$freespace' and (info.max - info.count)
                        or variable.search == '$usedspace' and info.count
                        or variable.search == '$maxspace' and info.max
                        or nil
                elseif variable.type == 'item' then
                    if variable.bag == 'all' then
                        for id in bag_ids:it() do
                            if not items[id] then
                                items[id] = T(windower.ffxi.get_items(id))
                            end
                        end
                    else
                        if not items[variable.bag] then
                            items[variable.bag] = T(windower.ffxi.get_items(variable.bag))
                        end
                    end

                    update[variable.name] = variable.bag ~= 'all' and search_bag(items[variable.bag], variable.ids) or items:reduce(function(acc, bag)
                        return acc + search_bag(bag, variable.ids)
                    end, 0)
                end
            end

            if not update:empty() then
                tracker:update(update)
            end
        end)
    end
end

-- Helper function to format table keys
local function encase_key(key)
    if type(key) == 'number' then
        return '['..tostring(key)..']'
    elseif type(key) == 'string' then
        return '["'..key..'"]'
    else
        return tostring(key)
    end
end

-- Helper function to create table string representation
local function make_table(tab, tab_offset)
    local offset = " ":rep(tab_offset)
    local ret = "{\n"
    for i,v in pairs(tab) do
        ret = ret..offset..encase_key(i)..' = '
        if type(v) == 'table' then
            ret = ret..make_table(v,tab_offset+2)..',\n'
        else
            ret = ret..tostring(v)..',\n'
        end
    end
    return ret..offset..'}'
end

-- Function to get local storage data
function inventory.get_local_storage()
    local items = windower.ffxi.get_items()
    if not items then
        error('Failed to get items from FFXI')
        return false
    end

    local storages = {
        gil = type(items.gil) == 'number' and items.gil or 0
    }

    for _, storage_name in ipairs(storages_order) do
        storages[storage_name] = T{}

        for _, data in ipairs(items[storage_name]) do
            if type(data) == 'table' then
                if data.id ~= 0 then
                    local id = tostring(data.id)
                    storages[storage_name][id] = (storages[storage_name][id] or 0) + data.count
                end
            end
        end
    end

    local slip_storages = slips.get_player_items()

    for _, slip_id in ipairs(slips.storages) do
        local slip_name = 'slip '..tostring(slips.get_slip_number_by_id(slip_id)):lpad('0', 2)
        storages[slip_name] = T{}

        for _, id in ipairs(slip_storages[slip_id]) do
            storages[slip_name][tostring(id)] = 1
        end
    end
    
    local key_items = windower.ffxi.get_key_items()
    
    storages['key items'] = T{}
    
    for _, id in ipairs(key_items) do
        storages['key items'][tostring(id)] = 1
    end

    return storages
end

-- Function to update storage data
function inventory.update()
    if not windower.ffxi.get_info().logged_in then
        error('You have to be logged in to use this addon.')
        return false
    end

    local player_name = windower.ffxi.get_player().name
    local local_storage = inventory.get_local_storage()
    if not local_storage then
        return false
    end

    if not windower.dir_exists(storages_path) then
        windower.create_dir(storages_path)
    end
    
    local success, err = pcall(function()
        local file = io.open(storages_path..player_name..'.lua', 'w')
        if file then
            file:write('return '..make_table(local_storage,0)..'\n')
            file:close()
        else
            error('Could not open storage file for writing')
        end
    end)
    
    if not success then
        error('Failed to write storage file: ' .. err)
        return false
    end

    collectgarbage()
    return true
end

-- Function to update global storage data
function inventory.update_global_storage()
    local player_name = windower.ffxi.get_player().name
    local global_storages = T{}
    
    -- Include current character's storage first
    global_storages[player_name] = inventory.get_local_storage()
    
    -- Then add other characters
    for _, f in pairs(windower.get_dir(storages_path)) do
        if f:sub(-4) == '.lua' and f:sub(1,-5) ~= player_name then
            local success, result = pcall(dofile, storages_path .. f)
            if success then
                global_storages[f:sub(1,-5)] = result
            end
        end
    end
    
    return global_storages
end

-- Export settings and tracker for external use
inventory.settings = settings
inventory.tracker = tracker
inventory.storages_order = storages_order
inventory.storages_order_tokens = storages_order_tokens

return inventory 