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

    -- Channel dropdown is a radio menu with one entry per channel.
    local items = w.channel._menuItems
    t.eq(#items, 5, "channel dropdown lists 5 channels")
    for _, item in ipairs(items) do
        if item.data == "raid" then item.Pick() end
    end
    t.eq(db.global.forceChannel, "raid", "channel selection is saved")
    local selected = 0
    for _, item in ipairs(w.channel._menuItems) do if item.IsSelected() then selected = selected + 1 end end
    t.eq(selected, 1, "exactly one channel is selected")

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
