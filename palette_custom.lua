local math_color = require("utils.math_color")

local STEP_WEIGHTS = { -3, -2, -1, 0, 1, 2, 3 }

local function build_custom_shades(base_color, shifts)
    local colors = {}
    for i = 1, #STEP_WEIGHTS do
        local w = STEP_WEIGHTS[i] / 3.0
        colors[#colors + 1] = math_color.colorShift(
            base_color,
            (shifts.hue or 0) * w,
            (shifts.sat or 0) * w,
            (shifts.light or 0) * w,
            (shifts.shade or 0) * w
        )
    end
    return colors
end

local function update_generated_palettes_custom(dlg, base_color, shifts)
    if not base_color then
        return
    end

    dlg:modify { id = "gen_custom", colors = build_custom_shades(base_color, shifts) }
end

return {
    update_generated_palettes_custom = update_generated_palettes_custom
}
