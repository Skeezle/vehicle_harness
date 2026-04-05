local ox_inventory = exports.ox_inventory

local function trim(value)
    return (value and value:gsub('^%s*(.-)%s*$', '%1')) or value
end

local function getDefaultMetadata()
    return {
        uses = Config.DefaultTemporaryUses,
        description = ('Temporary harness uses left: %s'):format(Config.DefaultTemporaryUses)
    }
end

local function normalizeMetadata(metadata)
    metadata = metadata or {}
    metadata.uses = tonumber(metadata.uses) or Config.DefaultTemporaryUses
    metadata.description = ('Temporary harness uses left: %s'):format(metadata.uses)
    return metadata
end

local function normalizePlate(plate)
    return trim(plate or '')
end

local function fetchHarnessState(plate)
    plate = normalizePlate(plate)
    if plate == '' then return false, false end

    local query = ('SELECT `%s` FROM `%s` WHERE `%s` = ? LIMIT 1'):format(Config.HarnessColumn, Config.VehicleTable, Config.PlateColumn)
    local result = MySQL.single.await(query, { plate })
    if not result then return false, false end

    local value = result[Config.HarnessColumn]
    return true, value == true or value == 1 or value == '1'
end

local function setHarnessState(plate, state)
    plate = normalizePlate(plate)
    if plate == '' then return false end

    local query = ('UPDATE `%s` SET `%s` = ? WHERE `%s` = ?'):format(Config.VehicleTable, Config.HarnessColumn, Config.PlateColumn)
    local changed = MySQL.update.await(query, { state and 1 or 0, plate })
    return changed and changed > 0
end

lib.callback.register('skeezle_harness:server:getHarnessState', function(_, plate)
    local exists, installed = fetchHarnessState(plate)
    return {
        owned = exists,
        installed = installed,
    }
end)

lib.callback.register('skeezle_harness:server:useHarnessItem', function(source, plate, slot)
    slot = tonumber(slot)

    -- print(('HARNESS SERVER DEBUG source=%s plate=%s slot=%s expectedItem=%s'):format(
    --     source, tostring(plate), tostring(slot), tostring(Config.ItemName)
    -- ))

    local invSlot = slot and ox_inventory:GetSlot(source, slot) or nil
    -- print('HARNESS SERVER DEBUG invSlot=', json.encode(invSlot))

    if not invSlot or invSlot.name ~= Config.ItemName then
        return { ok = false, message = Locales.item_missing }
    end

    plate = normalizePlate(plate)
    local owned, installed = fetchHarnessState(plate)

    if owned then
        if not Config.AllowPermanentHarness then
            return { ok = false, message = Locales.no_permanent_allowed }
        end

        if installed then
            if not Config.UninstallHarnessWithItem then
                return { ok = false, message = Locales.harness_already_installed }
            end

            if not ox_inventory:CanCarryItem(source, Config.ItemName, 1, getDefaultMetadata()) then
                return { ok = false, message = 'Not enough space to receive the harness item back.' }
            end

            if not setHarnessState(plate, false) then
                return { ok = false, message = Locales.action_failed }
            end

            ox_inventory:AddItem(source, Config.ItemName, 1, getDefaultMetadata())
            return { ok = true, action = 'uninstall', message = Locales.harness_removed }
        end

        local removed = ox_inventory:RemoveItem(source, Config.ItemName, 1, nil, slot)
        if not removed then
            return { ok = false, message = Locales.item_missing }
        end

        if not setHarnessState(plate, true) then
            ox_inventory:AddItem(source, Config.ItemName, 1, invSlot.metadata or getDefaultMetadata())
            return { ok = false, message = Locales.action_failed }
        end

        return { ok = true, action = 'install', message = Locales.harness_installed }
    end

    if not Config.AllowTemporaryHarness then
        return { ok = false, message = Locales.no_temporary_allowed }
    end

    local metadata = normalizeMetadata(invSlot.metadata)
    local uses = metadata.uses

    if uses <= 1 then
        ox_inventory:RemoveItem(source, Config.ItemName, 1, nil, slot)
        return { ok = true, action = 'temporary', usesLeft = 0, broke = true, message = Locales.harness_broke }
    end

    metadata.uses = uses - 1
    metadata.description = ('Temporary harness uses left: %s'):format(metadata.uses)
    ox_inventory:SetMetadata(source, slot, metadata)

    return {
        ok = true,
        action = 'temporary',
        usesLeft = metadata.uses,
        message = ('Temporary harness attached. Uses left: %s'):format(metadata.uses)
    }
end)

exports('HasInstalledHarness', function(plate)
    local _, installed = fetchHarnessState(plate)
    return installed
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    ox_inventory:registerHook('createItem', function(payload)
        if payload.item.name ~= Config.ItemName then return end
        return normalizeMetadata(payload.metadata)
    end, {
        itemFilter = {
            [Config.ItemName] = true
        }
    })
end)
