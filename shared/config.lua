Config = {}

Config.ItemName = 'harness'
Config.DefaultTemporaryUses = 10
Config.InstallTime = 10000
Config.UninstallTime = 7000
Config.RequireDriverForInstall = true
Config.AllowTemporaryHarness = true
Config.AllowPermanentHarness = true
Config.UninstallHarnessWithItem = false
Config.AutoDetachOnExit = true
Config.DisableExitWhenBuckled = true

Config.ToggleCommand = 'toggleseatbelt'
Config.ToggleKey = 'B'

Config.NotifyPosition = 'top'
Config.ProgressLabelInstall = 'Installing Harness'
Config.ProgressLabelUninstall = 'Removing Harness'
Config.ProgressLabelAttach = 'Attaching Harness'

Config.BlacklistedVehicleClasses = {
    [8] = true,  -- Motorcycles
    [13] = true, -- Cycles
    [14] = true, -- Boats
}

Config.VehicleTable = 'player_vehicles'
Config.PlateColumn = 'plate'
Config.HarnessColumn = 'harness'

Config.Eject = {
    enabled = true,
    minimumSpeed = 150.0,      -- MPH
    speedDropThreshold = 0.25, -- 25% drop within one sample
    bodyHealthDelta = 35.0,   -- body damage delta needed before ejection can happen
    requireForwardMotion = true,
    ragdollTime = 4500,
    cooldownMs = 1500,
    checkInterval = 120,
}
