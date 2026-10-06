-- Headless test: miss alerts stay quiet while the player's threat lead is solid; run with tools/test.ps1.
return function(sim, t)
    local db = sim.env.TankAlertForeverDB
    t.eq(db.global.quietWhenThreatSolid, true, "quiet-while-solid is on by default")

    -- Cast an ability on the target, then have the target report an avoidance; returns the new chat lines.
    local function castAndAvoid(spellID, action)
        sim:Advance(2) -- past the per-ability 1 s throttle and the 1.5 s cast window
        local before = #sim.chat
        sim:Fire("UNIT_SPELLCAST_SENT", "player", "Defias Pillager", "Cast-1", spellID)
        sim:Fire("UNIT_COMBAT", "target", action, "", 0, 1)
        local lines = {}
        for i = before + 1, #sim.chat do lines[#lines + 1] = sim.chat[i].msg end
        return lines
    end

    sim:EnterCombat()

    -- Solid lead (0): Sunder dodge is not announced, Taunt resist still is.
    sim.units.player.threatLead = 0
    t.eq(#castAndAvoid(7386, "DODGE"), 0, "Sunder dodge quiet while threat is solid")
    local taunt = castAndAvoid(355, "RESIST")
    t.eq(#taunt, 1, "Taunt resist announced even with solid threat")
    t.ok(taunt[1] and taunt[1]:find("RESISTED"), "Taunt alert says RESISTED")

    -- Lead slipping (yellow and worse): announced.
    sim.units.player.threatLead = 1
    local sunder = castAndAvoid(7386, "PARRY")
    t.eq(#sunder, 1, "Sunder parry announced when the lead is yellow")
    t.ok(sunder[1] and sunder[1]:find("PARRIED"), "Sunder alert says PARRIED")
    sim.units.player.threatLead = 3
    t.eq(#castAndAvoid(23922, "MISS"), 1, "Shield Slam miss announced when not top on threat")

    -- Unknown threat (not on the list, or secret): announced.
    sim.units.player.threatLead = nil
    t.eq(#castAndAvoid(7386, "DODGE"), 1, "announced when threat is unknown")
    sim.units.player.threatLead = 0
    sim.units.target.secretThreatState = true
    t.eq(#castAndAvoid(7386, "DODGE"), 1, "announced when the lead state is secret")
    sim.units.target.secretThreatState = nil

    -- Option off: everything announced again.
    db.global.quietWhenThreatSolid = false
    t.eq(#castAndAvoid(7386, "DODGE"), 1, "announced with the option off")
    db.global.quietWhenThreatSolid = true

    -- Debug mode prints the skipped alert locally.
    db.global.debugMode = true
    local printed = #sim.output
    t.eq(#castAndAvoid(7386, "DODGE"), 0, "still quiet in debug mode")
    local found = false
    for i = printed + 1, #sim.output do
        if tostring(sim.output[i]):find("not announced") then found = true end
    end
    t.ok(found, "debug mode prints the skipped alert")
    db.global.debugMode = nil

    sim:LeaveCombat()

    -- Options checkbox toggles the setting.
    sim:Slash("/ta")
    local w = sim.env.TankAlertForeverOptionsPanel.widgets
    t.ok(w.quietThreat:GetChecked(), "checkbox synced on show")
    w.quietThreat:Click()
    t.eq(db.global.quietWhenThreatSolid, false, "checkbox turns the option off")
end
