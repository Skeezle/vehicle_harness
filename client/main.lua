local state = {
    seatbeltOn = false,
    harnessOn = false,
    harnessMode = nil,
    currentPlate = nil,
    installedHarness = false,
    speedBuffer = { 0.0, 0.0 },
    bodyBuffer = { 1000.0, 1000.0 },
    lastEject = 0,
}

local function notify(description, type)
    lib.notify({
        title = 'Harness',
        description = description,
        type = type or 'inform',
        position = Config.NotifyPosition,
    })
end

local function trim(value)
    return (value and value:gsub('^%s*(.-)%s*$', '%1')) or value
end

local function isVehicleAllowed(vehicle)
    if vehicle == 0 then return false end
    return not Config.BlacklistedVehicleClasses[GetVehicleClass(vehicle)]
end

local function getVehiclePlate(vehicle)
    return trim(GetVehicleNumberPlateText(vehicle))
end

local function resetSafetyState()
    state.seatbeltOn = false
    state.harnessOn = false
    state.harnessMode = nil
    state.currentPlate = nil
    state.installedHarness = false
    LocalPlayer.state:set('seatbelt', false, true)
    LocalPlayer.state:set('harness', false, true)
end

local function syncStates()
    LocalPlayer.state:set('seatbelt', state.seatbeltOn, true)
    LocalPlayer.state:set('harness', state.harnessOn, true)
end

local function attachHarness(mode, silent)
    state.seatbeltOn = false
    state.harnessOn = true
    state.harnessMode = mode
    syncStates()
    if not silent then
        notify(Locales.harness_attached, 'success')
    end
end

local function detachHarness(silent)
    if not state.harnessOn then return end
    state.harnessOn = false
    state.harnessMode = nil
    syncStates()
    if not silent then
        notify(Locales.harness_detached, 'inform')
    end
end

local function toggleSeatbeltOrHarness()
    local ped = PlayerPedId()
    if IsPauseMenuActive() or not IsPedInAnyVehicle(ped, false) then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not isVehicleAllowed(vehicle) then
        return notify(Locales.invalid_vehicle, 'error')
    end

    local plate = getVehiclePlate(vehicle)
    if plate ~= state.currentPlate then
        state.currentPlate = plate
        local info = lib.callback.await('skeezle_harness:server:getHarnessState', false, plate)
        state.installedHarness = info and info.installed or false
    end

    if state.harnessOn then
        detachHarness()
        return
    end

    if state.installedHarness then
        attachHarness('installed')
        return
    end

    state.seatbeltOn = not state.seatbeltOn
    syncStates()
    -- notify(state.seatbeltOn and Locales.seatbelt_on or Locales.seatbelt_off, state.seatbeltOn and 'success' or 'inform')
end

RegisterCommand(Config.ToggleCommand, toggleSeatbeltOrHarness, false)
RegisterKeyMapping(Config.ToggleCommand, 'Toggle seatbelt / harness', 'keyboard', Config.ToggleKey)


    exports('harness', function(data, slot)
        -- print('HARNESS EXPORT FIRED')
        local ped = PlayerPedId()
        local itemSlot = slot or (data and data.slot)

    if not IsPedInAnyVehicle(ped, false) then
        return notify(Locales.not_in_vehicle, 'error')
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not isVehicleAllowed(vehicle) then
        return notify(Locales.invalid_vehicle, 'error')
    end

    local seat = GetPedInVehicleSeat(vehicle, -1)
    local plate = getVehiclePlate(vehicle)
    local info = lib.callback.await('skeezle_harness:server:getHarnessState', false, plate)
    local owned = info and info.owned or false

    if owned and Config.RequireDriverForInstall and seat ~= ped then
        return notify(Locales.must_be_driver, 'error')
    end

    exports.ox_inventory:useItem(data, function(usedData)
        -- print('HARNESS useItem CALLBACK FIRED')
        if not usedData then return end

        local finalSlot = (usedData and usedData.slot) or itemSlot
        -- print('HARNESS CLIENT DEBUG slot=', finalSlot, 'data=', json.encode(data), 'usedData=', json.encode(usedData))

        if not finalSlot then
            return notify('Harness slot could not be detected.', 'error')
        end

        local duration = owned and (info.installed and Config.UninstallTime or Config.InstallTime) or 2500
        local label = owned and (info.installed and Config.ProgressLabelUninstall or Config.ProgressLabelInstall) or Config.ProgressLabelAttach

        LocalPlayer.state.invBusy = true
        local completed = lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true,
            },
        })
        LocalPlayer.state.invBusy = false

        if not completed then
            return notify(Locales.install_cancelled, 'error')
        end

        local result = lib.callback.await('skeezle_harness:server:useHarnessItem', false, plate, finalSlot)
        if not result or not result.ok then
            return notify(result and result.message or Locales.action_failed, 'error')
        end

        state.currentPlate = plate
        local refreshed = lib.callback.await('skeezle_harness:server:getHarnessState', false, plate)
        state.installedHarness = refreshed and refreshed.installed or false

        if result.action == 'temporary' then
            attachHarness('temporary', true)
            if result.usesLeft then
                notify(('Temporary harness attached. Uses left: %s'):format(result.usesLeft), 'success')
            else
                notify(Locales.harness_attached, 'success')
            end
            if result.broke then
                notify(Locales.harness_broke, 'warning')
            end
            return
        end

        notify(result.message or Locales.action_failed, 'success')
    end)
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and isVehicleAllowed(vehicle) then
                local newPlate = getVehiclePlate(vehicle)
                if state.currentPlate and state.currentPlate ~= newPlate and Config.AutoDetachOnExit then
                    resetSafetyState()
                end
                state.currentPlate = newPlate
                state.speedBuffer[2] = state.speedBuffer[1]
                state.speedBuffer[1] = GetEntitySpeed(vehicle) * 2.236936
                state.bodyBuffer[2] = state.bodyBuffer[1]
                state.bodyBuffer[1] = GetVehicleBodyHealth(vehicle)

                if Config.DisableExitWhenBuckled and (state.seatbeltOn or state.harnessOn) then
                    DisableControlAction(0, 75, true)
                end

                if Config.Eject.enabled and not state.seatbeltOn and not state.harnessOn then
                    local speedNow = state.speedBuffer[1]
                    local speedPrev = state.speedBuffer[2]
                    local bodyDelta = state.bodyBuffer[2] - state.bodyBuffer[1]
                    local timeNow = GetGameTimer()
                    local forward = GetEntitySpeedVector(vehicle, true).y > 1.0
                    local speedDroppedEnough = speedPrev > 0 and ((speedPrev - speedNow) / speedPrev) >= Config.Eject.speedDropThreshold

                    if speedNow >= Config.Eject.minimumSpeed and speedDroppedEnough and bodyDelta >= Config.Eject.bodyHealthDelta and (not Config.Eject.requireForwardMotion or forward) and (timeNow - state.lastEject) > Config.Eject.cooldownMs then
                        state.lastEject = timeNow
                        local coords = GetOffsetFromEntityInWorldCoords(vehicle, 1.0, 0.0, 1.0)
                        SetEntityCoords(ped, coords.x, coords.y, coords.z)
                        Wait(0)
                        SetPedToRagdoll(ped, Config.Eject.ragdollTime, Config.Eject.ragdollTime, 0, false, false, false)
                        SetEntityVelocity(ped, GetEntityVelocity(vehicle))
                    end
                end

                Wait(Config.Eject.checkInterval)
            else
                if Config.AutoDetachOnExit then
                    resetSafetyState()
                end
                Wait(300)
            end
        else
            if Config.AutoDetachOnExit then
                resetSafetyState()
            end
            Wait(300)
        end
    end
end)

AddEventHandler('baseevents:leftVehicle', function()
    if Config.AutoDetachOnExit then
        resetSafetyState()
    end
end)
