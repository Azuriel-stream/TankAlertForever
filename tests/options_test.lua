-- Headless test for the options panel; run with tools/test.ps1 from the workspace (not loaded by the TOC).
return function(sim, t)
    local db = sim.env.TankAlertForeverDB
    t.ok(db and db.global, "SavedVariables initialized on ADDON_LOADED")

    sim:Slash("/ta")
    local panel = sim.env.TankAlertForeverOptionsPanel
    t.ok(panel and panel:IsShown(), "/ta opens the options panel")
    local w = panel.widgets

    -- Sliders write their rounded value to the DB.
    w.threshold.Slider:SetValue(74.6)
    t.eq(db.global.threatWhisperThreshold, 75, "threshold slider writes rounded value")
    w.alertThrottle.Slider:SetValue(12)
    t.eq(db.global.alertThrottle, 12, "alert throttle slider writes value")

    -- Checkboxes toggle their setting.
    local before = db.global.announceCC
    w.cc:Click()
    t.eq(db.global.announceCC, not before, "CC checkbox toggles announceCC")

    -- Channel radios (a dropdown menu crashed the beta client), exactly one selected
    local count = 0
    for _ in pairs(w.channels) do count = count + 1 end
    t.eq(count, 5, "5 channel options")
    w.channels.raid:Click()
    t.eq(db.global.forceChannel, "raid", "channel selection is saved")
    local selected = 0
    for _, cb in pairs(w.channels) do if cb:GetChecked() then selected = selected + 1 end end
    t.eq(selected, 1, "exactly one channel is selected")
    w.channels.raid:Click()
    t.ok(w.channels.raid:GetChecked(), "clicking the selected channel keeps it selected")
    for _, f in ipairs(sim.frames) do
        t.ok(f._type ~= "DropdownButton", "no Blizzard menu dropdowns")
    end

    -- Diagnostics are opt-in: nothing changed CVars at load; /ta debug on|off does
    t.eq(sim.cvars.scriptErrors, nil, "no CVars changed at load")
    sim:Slash("/ta debug on")
    t.eq(sim.cvars.scriptErrors, "1", "/ta debug on shows Lua errors")
    t.eq(sim.cvars.taintLog, "1", "/ta debug on logs taint")
    sim:Slash("/ta debug off")
    t.eq(sim.cvars.taintLog, "0", "/ta debug off stops taint logging")

    -- Template close button hides the panel.
    panel.CloseButton:Click()
    t.ok(not panel:IsShown(), "close button hides the panel")
    sim:Slash("/ta")

    -- Reopening re-syncs widgets from the DB.
    db.global.whisperThrottle = 20
    sim:Slash("/ta"); sim:Slash("/ta")
    t.eq(w.whisperThrottle.Slider:GetValue(), 20, "slider re-synced from DB on show")
    t.eq(w.cc:GetChecked(), db.global.announceCC, "checkbox re-synced from DB on show")
end
