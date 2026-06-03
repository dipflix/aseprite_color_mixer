local M = {}

local math_color = require("utils.math_color")

local dlg = Dialog { id = "cm_pal_d", title = "Color palettes", visible = false }

local function update_generated_palettes(base_color)
    if not base_color then
        return
    end

    local C = base_color
    local shade = {
        math_color.colorShift(C, 0, 0.3, -0.6, -0.6),
        math_color.colorShift(C, 0, 0.2, -0.2, -0.3),
        math_color.colorShift(C, 0, 0.1, -0.1, -0.1),
        C,
        math_color.colorShift(C, 0, 0.1, 0.1, 0.1),
        math_color.colorShift(C, 0, 0.2, 0.2, 0.2),
        math_color.colorShift(C, 0, 0.3, 0.5, 0.4)
    }

    local light = {
        math_color.colorShift(C, 0, 0, -0.4, 0),
        math_color.colorShift(C, 0, 0, -0.2, 0),
        math_color.colorShift(C, 0, 0, -0.1, 0),
        C,
        math_color.colorShift(C, 0, 0, 0.1, 0),
        math_color.colorShift(C, 0, 0, 0.2, 0),
        math_color.colorShift(C, 0, 0, 0.4, 0)
    }

    local sat = {
        math_color.colorShift(C, 0, -0.5, 0, 0),
        math_color.colorShift(C, 0, -0.2, 0, 0),
        math_color.colorShift(C, 0, -0.1, 0, 0),
        C,
        math_color.colorShift(C, 0, 0.1, 0, 0),
        math_color.colorShift(C, 0, 0.2, 0, 0),
        math_color.colorShift(C, 0, 0.5, 0, 0)
    }

    local hue = {
        math_color.colorShift(C, -0.15, 0, 0, 0),
        math_color.colorShift(C, -0.1, 0, 0, 0),
        math_color.colorShift(C, -0.05, 0, 0, 0),
        C,
        math_color.colorShift(C, 0.05, 0, 0, 0),
        math_color.colorShift(C, 0.1, 0, 0, 0),
        math_color.colorShift(C, 0.15, 0, 0, 0)
    }

    --local gc = {
    --    math_color.colorShift(C, -0.03, 0.03, -0.008, 0),
    --    math_color.colorShift(C, -0.008, 0.03, -0.03, 0),
    --    math_color.colorShift(C, -0.005, 0.03, -0.03, 0),
    --    C,
    --    math_color.colorShift(C, 0, 0.1, -0.1, 0),
    --    math_color.colorShift(C, 0, 0.2, -0.2, 0),
    --    math_color.colorShift(C, 0, 0.5, -0.3, 0)
    --}

    local gray = {
        Color { r = 238, g = 238, b = 238 },
        Color { r = 204, g = 204, b = 204 },
        Color { r = 153, g = 153, b = 153 },
        Color { r = 102, g = 102, b = 102 },
        Color { r = 51, g = 51, b = 51 },
        Color { r = 0, g = 0, b = 0 }
    }

    dlg:modify { id = "gen_gray", colors = gray }
    dlg:modify { id = "gen_shade", colors = shade }
    dlg:modify { id = "gen_light", colors = light }
    dlg:modify { id = "gen_sat", colors = sat }
    dlg:modify { id = "gen_hue", colors = hue }
    --dlg:modify { id = "gen_c", colors = gc }
end


function M.init(plugin)
    dlg:button {
        text = "Generate",
        onclick = function()
            update_generated_palettes(Color(app.fgColor))
        end
    }
    dlg:newrow()
        :shades { id = "gen_gray", colors = { Color(0, 0, 0) }, onclick = function(ev) app.fgColor = ev.color end }
        :newrow()
        :shades { id = "gen_shade", colors = { Color(0, 0, 0) }, onclick = function(ev) app.fgColor = ev.color end }
        :newrow()
        :shades { id = "gen_light", colors = { Color(0, 0, 0) }, onclick = function(ev) app.fgColor = ev.color end }
        :newrow()
        :shades { id = "gen_sat", colors = { Color(0, 0, 0) }, onclick = function(ev) app.fgColor = ev.color end }
        :newrow()
        :shades { id = "gen_hue", colors = { Color(0, 0, 0) }, onclick = function(ev) app.fgColor = ev.color end }
    --:newrow()
    --:shades { id = "gen_c", colors = { Color(0, 0, 0) }, onclick = function(ev) app.fgColor = ev.color end }


    plugin:newCommand {
        id = "cm_pal_open",
        title = "Color palettes",
        group = "dipflix_menu",
        onclick = function()
            dlg:show { wait = false }
        end
    }
end

return M
