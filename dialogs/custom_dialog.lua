local palette_custom = require("palette_custom")

local M = {}

local dlg_custom = Dialog { id = "cm_custom_d", title = "Custom shifts", visible = false }

local state = {
    base = nil,
    custom_shifts = {
        hue = 0,
        sat = 0,
        light = 0,
        shade = 0
    }
}

local function placeholder_shades()
    return { Color(0, 0, 0, 0) }
end

local function update_custom_palettes()
    palette_custom.update_generated_palettes_custom(dlg_custom, state.base, state.custom_shifts)
end

local function handle_generated_click(ev)
    app.fgColor = ev.color
end

function M.init()
    state.base = Color(app.fgColor)

    dlg_custom:newrow()
    dlg_custom:slider {
        id = "custom_h",
        label = "Hue shift",
        min = -100,
        max = 100,
        value = 0,
        onchange = function()
            state.custom_shifts.hue = (dlg_custom.data.custom_h or 0) / 100.0
            update_custom_palettes()
        end
    }
    dlg_custom:slider {
        id = "custom_s",
        label = "Sat shift",
        min = -100,
        max = 100,
        value = 0,
        onchange = function()
            state.custom_shifts.sat = (dlg_custom.data.custom_s or 0) / 100.0
            update_custom_palettes()
        end
    }
    dlg_custom:slider {
        id = "custom_l",
        label = "Light shift",
        min = -100,
        max = 100,
        value = 0,
        onchange = function()
            state.custom_shifts.light = (dlg_custom.data.custom_l or 0) / 100.0
            update_custom_palettes()
        end
    }
    dlg_custom:slider {
        id = "custom_sh",
        label = "Shade shift",
        min = -100,
        max = 100,
        value = 0,
        onchange = function()
            state.custom_shifts.shade = (dlg_custom.data.custom_sh or 0) / 100.0
            update_custom_palettes()
        end
    }
    dlg_custom:newrow()
        :shades {
            id = "gen_custom",
            colors = placeholder_shades(),
            onclick = function(ev)
                handle_generated_click(ev)
            end
        }
end

function M.show()
    dlg_custom:show { wait = false }
end

return M
