-- InventoryCheck
-- Adds //gs inventorycheck without modifying GearSwap core files.

local inventory_check = {}

inventory_check.version = '1.0.3'

inventory_check.settings = {
    check_other_inventory = false,
}

InventoryCheck = inventory_check

local command_aliases = {
    inventorycheck = true,
    invcheck = true,
    ic = true,
}

local bag_ids = {
    0,  -- Inventory
    8,  -- Wardrobe
    10, -- Wardrobe 2
    11, -- Wardrobe 3
    12, -- Wardrobe 4
    13, -- Wardrobe 5
    14, -- Wardrobe 6
    15, -- Wardrobe 7
    16, -- Wardrobe 8
}

local other_bag_ids = {
    1, -- Mog Safe
    9, -- Mog Safe 2
    2, -- Storage
    4, -- Mog Locker
    5, -- Mog Satchel
    6, -- Mog Sack
    7, -- Mog Case
}

local bag_order = {}
for index, bag_id in ipairs(bag_ids) do
    bag_order[bag_id] = index
end

local other_bag_order = {}
for index, bag_id in ipairs(other_bag_ids) do
    other_bag_order[bag_id] = index
end

local ignored_lua_files = {
    ['inventorycheck.lua'] = true,
}

local job_file_tokens

local function chat(color, text)
    windower.add_to_chat(color or 123, windower.to_shift_jis('[InventoryCheck] '..text))
end

local function normalize(value)
    if type(value) ~= 'string' then
        return nil
    end

    value = value:lower():gsub('^%s+', ''):gsub('%s+$', '')
    return value ~= '' and value or nil
end

local function get_resource_item(item_id)
    return gearswap.res and gearswap.res.items and gearswap.res.items[item_id]
end

local function item_display_name(item_id)
    local item = get_resource_item(item_id)
    if not item then
        return 'Unknown Item ID '..tostring(item_id)
    end

    return item[language] or item.english or item.name or item.name_log or tostring(item_id)
end

local function item_keys(item_id)
    local item = get_resource_item(item_id)
    local keys = {}

    if not item then
        return keys
    end

    local function add_key(value)
        value = normalize(value)
        if value then
            keys[value] = true
        end
    end

    add_key(item[language])
    add_key(item[language..'_log'])
    add_key(item.english)
    add_key(item.english_log)
    add_key(item.name)
    add_key(item.name_log)

    return keys
end

local function build_job_file_tokens()
    if job_file_tokens then
        return job_file_tokens
    end

    job_file_tokens = {}

    for _, job in pairs(gearswap.res.jobs) do
        if type(job) == 'table' then
            local short = normalize(job.english_short)
            local long = normalize(job.english)

            if short then
                job_file_tokens[short] = true
            end

            if long then
                job_file_tokens[long] = true
            end
        end
    end

    return job_file_tokens
end

local function is_equipment(item_id)
    local item = get_resource_item(item_id)
    return item and item.slots ~= nil
end

local function get_augments(item)
    if not item or not item.extdata or not gearswap.extdata then
        return nil
    end

    local ok, decoded = pcall(gearswap.extdata.decode, item)
    if not ok or not decoded or not decoded.augments then
        return nil
    end

    return decoded.augments
end

local function augment_key(augments)
    if type(augments) == 'string' then
        augments = {augments}
    end

    if type(augments) ~= 'table' then
        return ''
    end

    local parts = {}
    for _, augment in pairs(augments) do
        if augment and augment ~= 'none' then
            parts[#parts + 1] = tostring(augment):lower()
        end
    end

    table.sort(parts)
    return table.concat(parts, '|')
end

local function collect_bag_items(target_bag_ids, include_augments)
    local found = {}

    for _, bag_id in ipairs(target_bag_ids) do
        local bag_info_ok, bag_info = pcall(windower.ffxi.get_bag_info, bag_id)
        local bag_ok, bag = pcall(windower.ffxi.get_items, bag_id)

        if bag_info_ok and bag_ok and bag_info and bag then
            local resource_bag = gearswap.res and gearswap.res.bags and gearswap.res.bags[bag_id]
            local bag_name = bag_info.name or (resource_bag and (resource_bag[language] or resource_bag.english)) or ('Bag '..tostring(bag_id))

            for slot, item in pairs(bag) do
                if type(item) == 'table' and item.id and item.id ~= 0 and is_equipment(item.id) then
                    local entry = {
                        id = item.id,
                        bag_id = bag_id,
                        slot = slot,
                        bag = bag_name,
                        name = item_display_name(item.id),
                        keys = item_keys(item.id),
                        augment_key = include_augments and augment_key(get_augments(item)) or '',
                    }

                    found[#found + 1] = entry
                end
            end
        end
    end

    return found
end

local function collect_inventory_items(include_augments)
    return collect_bag_items(bag_ids, include_augments)
end

local function collect_other_inventory_items(include_augments)
    return collect_bag_items(other_bag_ids, include_augments)
end

local function parse_options(args)
    local options = {
        export = false,
        include_augments = false,
        check_other_inventory = inventory_check.settings.check_other_inventory,
        other_only = inventory_check.settings.check_other_inventory,
    }

    for _, arg in ipairs(args or {}) do
        arg = normalize(arg)
        if arg == 'export' then
            options.export = true
        elseif arg == 'augments' or arg == 'augs' then
            options.include_augments = true
        elseif arg == 'other' or arg == 'storage' then
            options.check_other_inventory = true
            options.other_only = true
        elseif arg == 'noother' or arg == 'nostorage' then
            options.check_other_inventory = false
            options.other_only = false
        elseif arg == 'help' or arg == '?' then
            options.help = true
        end
    end

    return options
end

local function print_help()
    chat(123, 'Commands:')
    chat(123, '//gs inventorycheck - list inventory/wardrobe equipment not used by any Lua file in data.')
    chat(123, '//gs inventorycheck export - writes a dated export file to data/export.')
    chat(123, '//gs inventorycheck other - list Lua gear sitting in inaccessible storage.')
    chat(123, '//gs inventorycheck augments - also requires matching augment text in the Lua files.')
end

local function path_join(left, right)
    if left:sub(-1) == '/' or left:sub(-1) == '\\' then
        return left..right
    end

    return left..'/'..right
end

local function collect_lua_files(dir)
    local files = {}
    local ok, entries = pcall(windower.get_dir, dir)
    local tokens = build_job_file_tokens()

    if not ok or type(entries) ~= 'table' then
        return files
    end

    table.sort(entries)

    for _, entry in ipairs(entries) do
        local path = path_join(dir, entry)
        local lower_entry = entry:lower()

        if lower_entry:sub(-4) == '.lua' and not ignored_lua_files[lower_entry] and not windower.dir_exists(path) then
            local normalized_filename = lower_entry:sub(1, -5):gsub('[^%a%d]+', ' ')
            local is_job_file = tokens[normalized_filename] == true

            for token in normalized_filename:gmatch('%S+') do
                if tokens[token] then
                    is_job_file = true
                    break
                end
            end

            if is_job_file then
                files[#files + 1] = path
            end
        end
    end

    return files
end

local function read_file(path)
    local file_handle = io.open(path, 'r')
    if not file_handle then
        return nil
    end

    local contents = file_handle:read('*all')
    file_handle:close()

    return contents
end

local function unescape_lua_string(value)
    value = value:gsub("\\'", "'")
    value = value:gsub('\\"', '"')
    value = value:gsub('\\\\', '\\')

    return value
end

local function collect_lua_strings_and_uncommented(contents, keep_uncommented)
    local strings = {}
    local output = {}
    local index = 1
    local length = #contents
    local quote
    local quoted_value

    while index <= length do
        local char = contents:sub(index, index)
        local next_two = contents:sub(index, index + 1)

        if quote then
            if keep_uncommented then
                output[#output + 1] = char
            end

            if char == '\\' and index < length then
                quoted_value[#quoted_value + 1] = char
                index = index + 1
                char = contents:sub(index, index)
                quoted_value[#quoted_value + 1] = char
                if keep_uncommented then
                    output[#output + 1] = char
                end
            elseif char == quote then
                strings[#strings + 1] = unescape_lua_string(table.concat(quoted_value))
                quote = nil
                quoted_value = nil
            else
                quoted_value[#quoted_value + 1] = char
            end

            index = index + 1
        elseif char == '"' or char == "'" then
            quote = char
            quoted_value = {}
            if keep_uncommented then
                output[#output + 1] = char
            end
            index = index + 1
        elseif next_two == '--' then
            if contents:sub(index + 2, index + 3) == '[[' then
                local close_start, close_end = contents:find('%]%]', index + 4)
                if close_end then
                    if keep_uncommented then
                        local comment = contents:sub(index, close_end)
                        local _, newline_count = comment:gsub('\n', '')
                        output[#output + 1] = string.rep('\n', newline_count)
                    end
                    index = close_end + 1
                else
                    break
                end
            else
                while index <= length and contents:sub(index, index) ~= '\n' do
                    index = index + 1
                end
            end
        else
            if keep_uncommented then
                output[#output + 1] = char
            end
            index = index + 1
        end
    end

    return strings, keep_uncommented and table.concat(output) or nil
end

local function build_target_item_lookup(target_items)
    local lookup = {}

    for _, item in ipairs(target_items or {}) do
        for key in pairs(item.keys or {}) do
            lookup[key] = item.id
        end
    end

    return lookup
end

local function add_lua_item_source(equipment, item_id, path)
    equipment.by_id[item_id] = true
    equipment.sources[item_id] = equipment.sources[item_id] or {}
    equipment.sources[item_id][path] = true
end

local function source_file_list(sources)
    local files = {}

    for path in pairs(sources or {}) do
        files[#files + 1] = path:gsub('\\', '/'):match('([^/]+)$') or path
    end

    table.sort(files)
    return table.concat(files, ', ')
end

local function collect_lua_equipment(include_augments, target_items)
    local equipment = {by_id = {}, sources = {}, augmented = {}, files = {}, unreadable = {}}
    local item_lookup = build_target_item_lookup(target_items)
    local files = collect_lua_files(windower.addon_path..'data/')

    for _, path in ipairs(files) do
        local contents = read_file(path)

        if contents then
            local quoted_strings, uncommented = collect_lua_strings_and_uncommented(contents, include_augments)
            equipment.files[#equipment.files + 1] = path

            for _, quoted_string in ipairs(quoted_strings) do
                local normalized_name = normalize(quoted_string)
                local item_id = normalized_name and item_lookup[normalized_name]

                if item_id then
                    add_lua_item_source(equipment, item_id, path)
                end
            end

            if include_augments then
                local lower_contents = uncommented:lower()

                for quoted_table in lower_contents:gmatch('name%s*=%s*["\'][^"\']+["\'][^}]*augments%s*=%s*{[^}]*}') do
                    local name = quoted_table:match('name%s*=%s*["\']([^"\']+)["\']')
                    local augments = {}

                    for augment in quoted_table:gmatch('["\']([^"\']+)["\']') do
                        if augment ~= name then
                            augments[#augments + 1] = augment
                        end
                    end

                    if name then
                        local item_id = item_lookup[normalize(name)]

                        if item_id then
                            equipment.augmented[item_id..'||'..augment_key(augments)] = true
                        end
                    end
                end
            end
        else
            equipment.unreadable[#equipment.unreadable + 1] = path
        end
    end

    return equipment
end

local function inventory_item_is_in_lua_files(item, lua_equipment, include_augments)
    if not lua_equipment.by_id[item.id] then
        return false
    end

    if not include_augments or item.augment_key == '' then
        return true
    end

    return lua_equipment.augmented[item.id..'||'..item.augment_key] == true
end

local function other_inventory_item_is_in_lua_files(item, lua_equipment, include_augments)
    return inventory_item_is_in_lua_files(item, lua_equipment, include_augments)
end

local function safe_date_for_filename()
    return os.date('%Y-%m-%d %H-%M-%S')
end

local function ensure_export_dir()
    local export_dir = windower.addon_path..'data/export'

    if not windower.dir_exists(export_dir) then
        windower.create_dir(export_dir)
    end

    return export_dir
end

local function group_items_by_bag(unused_items)
    local grouped = {}

    for _, bag_id in ipairs(bag_ids) do
        grouped[bag_id] = {}
    end

    for _, item in ipairs(unused_items) do
        grouped[item.bag_id] = grouped[item.bag_id] or {}
        grouped[item.bag_id][#grouped[item.bag_id] + 1] = item
    end

    return grouped
end

local function sort_items_by_bag(items, order)
    table.sort(items, function(left, right)
        local left_bag_order = order[left.bag_id] or 999
        local right_bag_order = order[right.bag_id] or 999

        if left_bag_order ~= right_bag_order then
            return left_bag_order < right_bag_order
        end

        if left.name:lower() ~= right.name:lower() then
            return left.name:lower() < right.name:lower()
        end

        return tostring(left.slot) < tostring(right.slot)
    end)
end

local function write_bag_sections(file_handle, title, items, section_bag_ids, lua_equipment, include_sources)
    file_handle:write(title..'\n\n')

    local grouped = group_items_by_bag(items)
    for _, bag_id in ipairs(section_bag_ids) do
        local items_in_bag = grouped[bag_id] or {}
        local resource_bag = gearswap.res and gearswap.res.bags and gearswap.res.bags[bag_id]
        local bag_name = (items_in_bag[1] and items_in_bag[1].bag) or (resource_bag and (resource_bag[language] or resource_bag.english)) or ('Bag '..tostring(bag_id))

        file_handle:write(bag_name..' ('..tostring(#items_in_bag)..')\n')
        file_handle:write(string.rep('-', #bag_name + #tostring(#items_in_bag) + 3)..'\n')

        if #items_in_bag == 0 then
            file_handle:write('None\n')
        else
            for _, item in ipairs(items_in_bag) do
                local line = item.name
                if item.augment_key and item.augment_key ~= '' then
                    line = line..' | '..item.augment_key
                end
                if include_sources then
                    line = line..' | Lua: '..source_file_list(lua_equipment.sources[item.id])
                end
                file_handle:write(line..'\n')
            end
        end

        file_handle:write('\n')
    end
end

local function write_export(unused_items, inaccessible_items, options, lua_equipment)
    local export_dir = ensure_export_dir()
    local path = export_dir..'/Inventory Check '..safe_date_for_filename()..'.txt'
    local file_handle = io.open(path, 'w+')

    if not file_handle then
        chat(123, 'Could not write export file.')
        return
    end

    file_handle:write('InventoryCheck Export\n')
    file_handle:write('Generated: '..os.date('%Y-%m-%d %H:%M:%S')..'\n')
    file_handle:write('Scanned Lua files: '..tostring(#lua_equipment.files)..'\n')
    file_handle:write('Equipment names found: '..tostring(table.length(lua_equipment.by_id))..'\n')
    file_handle:write('Augment-sensitive: '..tostring(options.include_augments)..'\n\n')
    file_handle:write('Other inventory reverse lookup: '..tostring(options.check_other_inventory)..'\n')
    file_handle:write('Other only: '..tostring(options.other_only)..'\n\n')

    file_handle:write('Files scanned:\n')
    for _, scanned_file in ipairs(lua_equipment.files) do
        file_handle:write('  '..scanned_file..'\n')
    end
    file_handle:write('\n')

    if #lua_equipment.unreadable > 0 then
        file_handle:write('Unreadable files:\n')
        for _, unreadable_file in ipairs(lua_equipment.unreadable) do
            file_handle:write('  '..unreadable_file..'\n')
        end
        file_handle:write('\n')
    end

    if not options.other_only then
        write_bag_sections(file_handle, 'Unused equipment by inventory type:', unused_items, bag_ids, lua_equipment, false)
    end

    if options.check_other_inventory then
        write_bag_sections(file_handle, 'Lua equipment found in inaccessible storage:', inaccessible_items, other_bag_ids, lua_equipment, true)
    end

    file_handle:close()
    chat(123, 'Export written to '..path:sub(#windower.addon_path + 1))
end

local function collect_inaccessible_items(lua_equipment, options, other_inventory_items)
    local inaccessible_items = {}
    local seen = {}
    other_inventory_items = other_inventory_items or collect_other_inventory_items(options.include_augments)

    for _, item in ipairs(other_inventory_items) do
        if other_inventory_item_is_in_lua_files(item, lua_equipment, options.include_augments) then
            local dedupe_key = item.name:lower()..'||'..tostring(item.bag_id)..'||'..item.augment_key
            if not seen[dedupe_key] then
                seen[dedupe_key] = true
                inaccessible_items[#inaccessible_items + 1] = item
            end
        end
    end

    sort_items_by_bag(inaccessible_items, other_bag_order)
    return inaccessible_items
end

function inventory_check.run_other_only(options)
    local other_inventory_items = collect_other_inventory_items(options.include_augments)
    local lua_equipment = collect_lua_equipment(options.include_augments, other_inventory_items)
    local inaccessible_items = collect_inaccessible_items(lua_equipment, options, other_inventory_items)

    chat(123, 'Mode: inaccessible storage only.')
    chat(123, 'Collected '..tostring(table.length(lua_equipment.by_id))..' equipment names from '..tostring(#lua_equipment.files)..' Lua files in data.')

    if #inaccessible_items == 0 then
        chat(120, 'No Lua equipment found in inaccessible storage.')
    else
        chat(123, 'Lua equipment found in inaccessible storage:')
        for _, item in ipairs(inaccessible_items) do
            chat(120, item.name..' - '..item.bag..' - Lua: '..source_file_list(lua_equipment.sources[item.id]))
        end
    end

    chat(123, 'Inaccessible count = '..tostring(#inaccessible_items))

    if #lua_equipment.unreadable > 0 then
        chat(123, 'Skipped unreadable files = '..tostring(#lua_equipment.unreadable))
    end

    if options.export then
        write_export({}, inaccessible_items, options, lua_equipment)
    end

    return true
end

function inventory_check.run(args)
    local options = parse_options(args)

    if options.help then
        print_help()
        return true
    end

    if options.other_only then
        return inventory_check.run_other_only(options)
    end

    local inventory_items = collect_inventory_items(options.include_augments)
    local lua_targets = inventory_items
    local other_inventory_items

    if options.check_other_inventory then
        other_inventory_items = collect_other_inventory_items(options.include_augments)
        for _, item in ipairs(other_inventory_items) do
            lua_targets[#lua_targets + 1] = item
        end
    end

    local lua_equipment = collect_lua_equipment(options.include_augments, lua_targets)
    local unused_items = {}
    local inaccessible_items = {}
    local seen = {}

    for _, item in ipairs(inventory_items) do
        if not inventory_item_is_in_lua_files(item, lua_equipment, options.include_augments) then
            local dedupe_key = item.name:lower()..'||'..tostring(item.bag_id)..'||'..item.augment_key
            if not seen[dedupe_key] then
                seen[dedupe_key] = true
                unused_items[#unused_items + 1] = item
            end
        end
    end

    sort_items_by_bag(unused_items, bag_order)

    if options.check_other_inventory then
        inaccessible_items = collect_inaccessible_items(lua_equipment, options, other_inventory_items)
    end

    chat(123, 'Mode: inventory and wardrobes.')
    chat(123, 'Collected '..tostring(#inventory_items)..' inventory/wardrobe equipment entries.')
    chat(123, 'Collected '..tostring(table.length(lua_equipment.by_id))..' equipment names from '..tostring(#lua_equipment.files)..' Lua files in data.')

    if #unused_items == 0 then
        chat(120, 'No unused equipment found.')
    else
        for _, item in ipairs(unused_items) do
            chat(120, item.name..' - '..item.bag)
        end
    end

    chat(123, 'Final count = '..tostring(#unused_items))

    if options.check_other_inventory then
        if #inaccessible_items == 0 then
            chat(120, 'No Lua equipment found in inaccessible storage.')
        else
            chat(123, 'Lua equipment found in inaccessible storage:')
            for _, item in ipairs(inaccessible_items) do
                chat(120, item.name..' - '..item.bag..' - Lua: '..source_file_list(lua_equipment.sources[item.id]))
            end
        end

        chat(123, 'Inaccessible count = '..tostring(#inaccessible_items))
    end

    if #lua_equipment.unreadable > 0 then
        chat(123, 'Skipped unreadable files = '..tostring(#lua_equipment.unreadable))
    end

    if options.export then
        write_export(unused_items, inaccessible_items, options, lua_equipment)
    end

    return true
end

register_unhandled_command(function(command, ...)
    local extra_args = {...}
    command = normalize(command)

    if command and command:find(' ', 1, true) then
        local split = {}
        for part in command:gmatch('%S+') do
            split[#split + 1] = part
        end

        command = split[1]
        for index = #split, 2, -1 do
            table.insert(extra_args, 1, split[index])
        end
    end

    if not command_aliases[command] then
        return false
    end

    return inventory_check.run(extra_args)
end)

return inventory_check
