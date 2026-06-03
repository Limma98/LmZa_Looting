local RSGCore = exports['rsg-core']:GetCoreObject()

-- ─────────────────────────────────────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────────────────────────────────────

local isLooting   = false   -- prevents re-entry while a loot action is in progress
local lootKey     = 1101824977  -- INPUT_CONTEXT (same key as original)

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Returns the nearest dead NPC within Config.LootRadius, or nil
local function getNearbyDeadNPC()
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)

    local shapeTest = StartShapeTestBox(
        coords.x, coords.y, coords.z,
        Config.LootRadius * 2, Config.LootRadius * 2, Config.LootRadius * 2,
        0.0, 0.0, 0.0,
        true, 8, player
    )
    local _, hit, _, _, entityHit = GetShapeTestResult(shapeTest)

    if not hit or entityHit == 0 then return nil end

    -- Must be a human NPC (type 4) and actually dead
    if GetPedType(entityHit) ~= 4 then return nil end
    if not IsEntityDead(entityHit)  then return nil end

    -- Must not have already been looted (native loot flag)
    if Citizen.InvokeNative(0x8DE41E9902E85756, entityHit) then return nil end

    return entityHit
end

-- Draw a simple 2D text hint above the crosshair
local function drawHint(text)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.0, 0.35)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.5, 0.85)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Main thread  (sleeps at 500 ms when idle; tightens only while looting)
-- ─────────────────────────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(500)   -- idle poll: check whether we should wake up

        -- Skip entirely while in a vehicle or already mid-loot
        if IsPedInAnyVehicle(PlayerPedId(), true) or isLooting then
            goto continue
        end

        local entity = getNearbyDeadNPC()
        if not entity then goto continue end

        -- ── We have a nearby lootable body – switch to tight loop for responsiveness ──
        local hintShown = false
        while true do
            Wait(0)

            -- Re-check each frame in case player walked away
            if not getNearbyDeadNPC() then
                break   -- back to idle 500 ms loop
            end

            drawHint('Hold [~INPUT_CONTEXT~] to loot')

            if IsControlJustPressed(0, lootKey) then
                local pressTime = GetGameTimer()
                isLooting = true

                -- Hold-detection inner loop
                while true do
                    Wait(0)
                    drawHint('Looting...')

                    if IsControlJustReleased(0, lootKey) then
                        local held = GetGameTimer() - pressTime

                        if held >= Config.LootHoldTime then
                            -- Small pause so the native loot-flag settles
                            Wait(300)

                            -- Re-validate: still dead? still unlooted?
                            if not IsEntityDead(entity) then
                                lib.notify({ title = 'Looting', description = 'Nothing to loot.', type = 'inform' })
                                isLooting = false
                                break
                            end

                            local alreadyLooted = Citizen.InvokeNative(0x8DE41E9902E85756, entity)
                            if not alreadyLooted then
                                lib.notify({ title = 'Looting', description = 'Nothing to loot.', type = 'inform' })
                                isLooting = false
                                break
                            end

                            -- Request reward from server, passing network ID for cooldown keying
                            local entityNetId = NetworkGetNetworkIdFromEntity(entity)
                            RSGCore.Functions.TriggerCallback('LmZa_Looting:server:requestLoot', function(success, itemOrReason, cash, isRare)
                                if success then
                                    local tier = isRare and '★ Rare find!' or 'Common loot'
                                    lib.notify({
                                        title       = tier,
                                        description = ('Found %s and $%d'):format(itemOrReason, cash),
                                        type        = 'success',
                                        duration    = 5000,
                                    })
                                    if Config.TriggerLawman then
                                        TriggerServerEvent('rsg-lawman:server:lawmanAlert', 'Someone is looting a body')
                                    end
                                else
                                    local msgs = {
                                        already_looted = 'This body has already been looted.',
                                        rate_limited   = 'You are looting too quickly.',
                                        invalid_player = 'Something went wrong.',
                                    }
                                    lib.notify({
                                        title       = 'Looting',
                                        description = msgs[itemOrReason] or 'Could not loot.',
                                        type        = 'error',
                                        duration    = 4000,
                                    })
                                end
                                isLooting = false
                            end, entityNetId)

                        else
                            -- Key not held long enough
                            isLooting = false
                        end
                        break
                    end

                    -- Player moved away while holding key – cancel
                    if not getNearbyDeadNPC() then
                        isLooting = false
                        break
                    end
                end

                break   -- exit tight loop back to 500 ms idle
            end
        end

        ::continue::
    end
end)
