local M = {}

local function clamp(v)
    if v < 0 then return 0 end
    if v > 255 then return 255 end
    return v
end

local function rgbToHsl(r, g, b)
    r = r / 255
    g = g / 255
    b = b / 255

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local h, s, l
    l = (max + min) / 2

    if max == min then
        h = 0
        s = 0
    else
        local d = max - min
        s = l > 0.5 and d / (2 - max - min) or d / (max + min)

        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end

        h = h / 6
    end

    return h * 360, s, l
end

local function hslToRgb(h, s, l)
    h = h / 360

    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    local r, g, b

    if s == 0 then
        r = l
        g = l
        b = l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hue2rgb(p, q, h + 1 / 3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1 / 3)
    end

    return clamp(math.floor(r * 255)),
        clamp(math.floor(g * 255)),
        clamp(math.floor(b * 255))
end

local function placeholder_shades()
    return { Color(0, 0, 0, 0) }
end

local function build_generated_shades(base_color, steps, hshift, lshift, sshift)
    local colors = {}
    local h, s, l = rgbToHsl(base_color.red, base_color.green, base_color.blue)
    local steps_count = math.max(0, math.floor(tonumber(steps) or 0))

    colors[#colors + 1] = Color(base_color)

    for i = 1, steps_count do
        local sh = (h - hshift * i) % 360
        local ss = math.min(1, s + sshift * i)
        local sl = math.max(0, l - lshift * i)
        local r, g, b = hslToRgb(sh, ss, sl)
        colors[#colors + 1] = Color { r = r, g = g, b = b }
    end

    for i = 1, steps_count do
        local lh = (h + hshift * i) % 360
        local ls = math.max(0, s - sshift * i)
        local ll = math.min(1, l + lshift * i)
        local r, g, b = hslToRgb(lh, ls, ll)
        colors[#colors + 1] = Color { r = r, g = g, b = b }
    end

    return colors
end

local dlg = Dialog { title = "Pixel Shader Generator" }

dlg:number { id = "steps", label = "Steps", text = "3" }
dlg:number { id = "hshift", label = "Hue Shift", text = "6" }
dlg:number { id = "lshift", label = "Light Shift%", text = "15" }
dlg:number { id = "sshift", label = "Sat Shift%", text = "5" }

dlg:button {
    text = "Generate",
    onclick = function()
        local fg = app.fgColor
        local steps = dlg.data.steps
        local hshift = tonumber(dlg.data.hshift) or 0
        local lshift = (tonumber(dlg.data.lshift) or 0) / 100
        local sshift = (tonumber(dlg.data.sshift) or 0) / 100

        dlg:modify {
            id = "gen_shift",
            colors = build_generated_shades(fg, steps, hshift, lshift, sshift)
        }
    end
}

dlg:newrow()
    :shades {
        id = "gen_shift",
        colors = placeholder_shades(),
        onclick = function(ev)
            app.fgColor = ev.color
        end
    }

function M.init(plugin)
    plugin:newCommand {
        id = "color_shift_v2_open",
        title = "Color shift v2",
        group = "dipflix_menu",
        onclick = function()
            dlg:show { wait = false }
        end
    }
end

return M
