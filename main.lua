local dlg = Dialog { id = "cm_d", title = "Color mixer", visible = false }
local MIX_STEP = 15
local DEFAULT_PERCENT = 50

local state = {
    left = nil,
    right = nil,
    percent = DEFAULT_PERCENT,
    base = nil
}

function colorToInt(color)
    return (color.red << 16) + (color.green << 8) + (color.blue)
end

function colorFromInt(color)
    return Color {
        red = (color >> 16) & 255,
        green = (color >> 8) & 255,
        blue = color & 255
    }
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function clamp01(v)
    return clamp(v, 0.0, 1.0)
end

local function srgb_to_linear(c)
    if c <= 0.04045 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function linear_to_srgb(c)
    if c <= 0.0031308 then
        return 12.92 * c
    end
    return 1.055 * (c ^ (1.0 / 2.4)) - 0.055
end

local function lerp(first, second, by)
    return first * (1 - by) + second * by
end

local function lerpRGBInt(color1, color2, amount)
    local X1 = 1 - amount
    local X2 = color1 >> 24 & 255
    local X3 = color1 >> 16 & 255
    local X4 = color1 >> 8 & 255
    local X5 = color1 & 255
    local X6 = color2 >> 24 & 255
    local X7 = color2 >> 16 & 255
    local X8 = color2 >> 8 & 255
    local X9 = color2 & 255
    local X10 = X2 * X1 + X6 * amount
    local X11 = X3 * X1 + X7 * amount
    local X12 = X4 * X1 + X8 * amount
    local X13 = X5 * X1 + X9 * amount
    return X10 << 24 | X11 << 16 | X12 << 8 | X13
end

local function colorShift(color, hueShift, satShift, lightShift, shadeShift)
    local newColor = Color(color)

    newColor.hue = newColor.hue + hueShift * 359

    if satShift > 0 then
        newColor.saturation = lerp(newColor.saturation, 1, satShift)
    elseif satShift < 0 then
        newColor.saturation = lerp(newColor.saturation, 0, -satShift)
    end

    if lightShift > 0 then
        newColor.lightness = lerp(newColor.lightness, 1, lightShift)
    elseif lightShift < 0 then
        newColor.lightness = lerp(newColor.lightness, 0, -lightShift)
    end

    local newShade = Color { red = newColor.red, green = newColor.green, blue = newColor.blue }
    local shadeInt = 0
    if shadeShift >= 0 then
        newShade.hue = 50
        shadeInt = lerpRGBInt(colorToInt(newColor), colorToInt(newShade), shadeShift)
    else
        newShade.hue = 215
        shadeInt = lerpRGBInt(colorToInt(newColor), colorToInt(newShade), -shadeShift)
    end
    newColor.red = shadeInt >> 16
    newColor.green = shadeInt >> 8 & 255
    newColor.blue = shadeInt & 255

    return newColor
end

local function mix_linear_srgb(orig, dest, t)
    local ro01, go01, bo01 = orig.red / 255.0, orig.green / 255.0, orig.blue / 255.0
    local rd01, gd01, bd01 = dest.red / 255.0, dest.green / 255.0, dest.blue / 255.0

    local roLin, goLin, boLin = ro01 ^ 2.2, go01 ^ 2.2, bo01 ^ 2.2
    local rdLin, gdLin, bdLin = rd01 ^ 2.2, gd01 ^ 2.2, bd01 ^ 2.2

    local u = 1.0 - t
    local mrLin = u * roLin + t * rdLin
    local mgLin = u * goLin + t * gdLin
    local mbLin = u * boLin + t * bdLin

    local r = clamp(math.floor(0.5 + (mrLin ^ (1.0 / 2.2)) * 255.0), 0, 255)
    local g = clamp(math.floor(0.5 + (mgLin ^ (1.0 / 2.2)) * 255.0), 0, 255)
    local b = clamp(math.floor(0.5 + (mbLin ^ (1.0 / 2.2)) * 255.0), 0, 255)
    local a = clamp(math.floor(0.5 + (u * orig.alpha + t * dest.alpha)), 0, 255)

    return Color(r, g, b, a)
end

local function lab_to_ase_color(lab)
    local lightness = lab.l
    local a = lab.a
    local b = lab.b
    local t = lab.alpha

    local x0 = 0.01 * lightness + 0.000904127 * a + 0.000456344 * b
    local y0 = 0.01 * lightness - 0.000533159 * a - 0.000269178 * b
    local z0 = 0.01 * lightness - 0.0058 * b

    local x1 = x0 * (2700.0 / 24389.0)
    local y1 = y0 * (2700.0 / 24389.0)
    local z1 = z0 * (2700.0 / 24389.0)

    if x0 > 0.08 then x1 = ((x0 + 0.16) / 1.16) ^ 3.0 end
    if y0 > 0.08 then y1 = ((y0 + 0.16) / 1.16) ^ 3.0 end
    if z0 > 0.08 then z1 = ((z0 + 0.16) / 1.16) ^ 3.0 end

    local rl = 5.435679 * x1 - 4.599131 * y1 + 0.163593 * z1
    local gl = -1.16809 * x1 + 2.327977 * y1 - 0.159798 * z1
    local bl = 0.03784 * x1 - 0.198564 * y1 + 1.160644 * z1

    local rs = rl * 12.92
    local gs = gl * 12.92
    local bs = bl * 12.92

    if rl > 0.00304 then rs = 1.055 * (rl ^ (1.0 / 2.4)) - 0.055 end
    if gl > 0.00304 then gs = 1.055 * (gl ^ (1.0 / 2.4)) - 0.055 end
    if bl > 0.00304 then bs = 1.055 * (bl ^ (1.0 / 2.4)) - 0.055 end

    local r255 = math.floor(0.5 + rs * 255.0)
    local g255 = math.floor(0.5 + gs * 255.0)
    local b255 = math.floor(0.5 + bs * 255.0)

    local rClipped = clamp(r255, 0, 255)
    local gClipped = clamp(g255, 0, 255)
    local bClipped = clamp(b255, 0, 255)

    return Color(rClipped, gClipped, bClipped, t)
end

local function ase_color_to_lab(aseColor)
    local r255, g255, b255, a255 = aseColor.red, aseColor.green, aseColor.blue, aseColor.alpha

    local rNorm, gNorm, bNorm = r255 / 255.0, g255 / 255.0, b255 / 255.0

    local rLin, gLin, bLin = rNorm / 12.92, gNorm / 12.92, bNorm / 12.92

    if rNorm > 0.03928 then rLin = ((rNorm + 0.055) / 1.055) ^ 2.4 end
    if gNorm > 0.03928 then gLin = ((gNorm + 0.055) / 1.055) ^ 2.4 end
    if bNorm > 0.03928 then bLin = ((bNorm + 0.055) / 1.055) ^ 2.4 end

    local x0 = 0.32053 * rLin + 0.63692 * gLin + 0.04256 * bLin
    local y0 = 0.161987 * rLin + 0.756636 * gLin + 0.081376 * bLin
    local z0 = 0.017228 * rLin + 0.10866 * gLin + 0.874112 * bLin

    local x1 = x0 * (24389.0 / 2700.0)
    local y1 = y0 * (24389.0 / 2700.0)
    local z1 = z0 * (24389.0 / 2700.0)

    if x0 > (216.0 / 24389.0) then x1 = 1.16 * (x0 ^ (1.0 / 3.0)) - 0.16 end
    if y0 > (216.0 / 24389.0) then y1 = 1.16 * (y0 ^ (1.0 / 3.0)) - 0.16 end
    if z0 > (216.0 / 24389.0) then z1 = 1.16 * (z0 ^ (1.0 / 3.0)) - 0.16 end

    local lightness = 37.095 * x1 + 62.9054 * y1 - 0.0008 * z1
    local a = 663.4684 * x1 - 750.5078 * y1 + 87.0328 * z1
    local b = 63.9569 * x1 + 108.4576 * y1 - 172.4152 * z1

    return { l = lightness, a = a, b = b, alpha = a255 }
end

local function mix_lab(orig, dest, t)
    local oLab = ase_color_to_lab(orig)
    local dLab = ase_color_to_lab(dest)
    local u = 1.0 - t

    local ml = u * oLab.l + t * dLab.l
    local ma = u * oLab.a + t * dLab.a
    local mb = u * oLab.b + t * dLab.b
    local mt = clamp(math.floor(0.5 + (u * oLab.alpha + t * dLab.alpha)), 0, 255)

    return lab_to_ase_color({ l = ml, a = ma, b = mb, alpha = mt })
end

local function get_mix_space()
    return dlg.data.mixSpace or "linear-srgb"
end

local function get_shortest_hue()
    return dlg.data.shortestHue == true
end

local function lab_to_lch(lab)
    local c = math.sqrt(lab.a * lab.a + lab.b * lab.b)
    local h = math.deg(math.atan(lab.b, lab.a))
    if h < 0 then h = h + 360 end
    return { l = lab.l, c = c, h = h, alpha = lab.alpha }
end

local function lch_to_lab(lch)
    local hrad = math.rad(lch.h)
    local a = lch.c * math.cos(hrad)
    local b = lch.c * math.sin(hrad)
    return { l = lch.l, a = a, b = b, alpha = lch.alpha }
end

local function mix_lch(orig, dest, t, shortestHue)
    local oLab = ase_color_to_lab(orig)
    local dLab = ase_color_to_lab(dest)
    local o = lab_to_lch(oLab)
    local d = lab_to_lch(dLab)
    local u = 1.0 - t

    local dh = d.h - o.h
    if shortestHue then
        if dh > 180 then dh = dh - 360 end
        if dh < -180 then dh = dh + 360 end
    end
    local h = o.h + dh * t
    if h < 0 then h = h + 360 end
    if h >= 360 then h = h - 360 end

    local l = u * o.l + t * d.l
    local c = u * o.c + t * d.c
    local a = clamp(math.floor(0.5 + (u * o.alpha + t * d.alpha)), 0, 255)

    return lab_to_ase_color(lch_to_lab({ l = l, c = c, h = h, alpha = a }))
end

local function srgb_to_oklab(color)
    local r = srgb_to_linear(color.red / 255.0)
    local g = srgb_to_linear(color.green / 255.0)
    local b = srgb_to_linear(color.blue / 255.0)

    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    local l_ = l ^ (1.0 / 3.0)
    local m_ = m ^ (1.0 / 3.0)
    local s_ = s ^ (1.0 / 3.0)

    local L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    local A = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    local B = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

    return { l = L, a = A, b = B, alpha = color.alpha }
end

local function oklab_to_srgb(ok)
    local l_ = ok.l + 0.3963377774 * ok.a + 0.2158037573 * ok.b
    local m_ = ok.l - 0.1055613458 * ok.a - 0.0638541728 * ok.b
    local s_ = ok.l - 0.0894841775 * ok.a - 1.2914855480 * ok.b

    local l = l_ * l_ * l_
    local m = m_ * m_ * m_
    local s = s_ * s_ * s_

    local r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    local b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    local rs = clamp01(linear_to_srgb(r))
    local gs = clamp01(linear_to_srgb(g))
    local bs = clamp01(linear_to_srgb(b))

    return Color(
        clamp(math.floor(0.5 + rs * 255.0), 0, 255),
        clamp(math.floor(0.5 + gs * 255.0), 0, 255),
        clamp(math.floor(0.5 + bs * 255.0), 0, 255),
        ok.alpha
    )
end

local function oklab_to_oklch(ok)
    local c = math.sqrt(ok.a * ok.a + ok.b * ok.b)
    local h = math.deg(math.atan(ok.b, ok.a))
    if h < 0 then h = h + 360 end
    return { l = ok.l, c = c, h = h, alpha = ok.alpha }
end

local function oklch_to_oklab(lch)
    local hrad = math.rad(lch.h)
    local a = lch.c * math.cos(hrad)
    local b = lch.c * math.sin(hrad)
    return { l = lch.l, a = a, b = b, alpha = lch.alpha }
end

local function mix_oklab(orig, dest, t)
    local o = srgb_to_oklab(orig)
    local d = srgb_to_oklab(dest)
    local u = 1.0 - t

    local L = u * o.l + t * d.l
    local A = u * o.a + t * d.a
    local B = u * o.b + t * d.b
    local a = clamp(math.floor(0.5 + (u * o.alpha + t * d.alpha)), 0, 255)

    return oklab_to_srgb({ l = L, a = A, b = B, alpha = a })
end

local function mix_oklch(orig, dest, t, shortestHue)
    local o = oklab_to_oklch(srgb_to_oklab(orig))
    local d = oklab_to_oklch(srgb_to_oklab(dest))
    local u = 1.0 - t

    local dh = d.h - o.h
    if shortestHue then
        if dh > 180 then dh = dh - 360 end
        if dh < -180 then dh = dh + 360 end
    end
    local h = o.h + dh * t
    if h < 0 then h = h + 360 end
    if h >= 360 then h = h - 360 end

    local l = u * o.l + t * d.l
    local c = u * o.c + t * d.c
    local a = clamp(math.floor(0.5 + (u * o.alpha + t * d.alpha)), 0, 255)

    return oklab_to_srgb(oklch_to_oklab({ l = l, c = c, h = h, alpha = a }))
end

local function anime_preset(name)
    if name == "anime-soft" then
        return {
            shadowHue = 0.05,
            shadowSat = 0.15,
            shadowLight = -0.25,
            highlightHue = 0.02,
            highlightSat = 0.10,
            highlightLight = 0.20
        }
    elseif name == "anime-punchy" then
        return {
            shadowHue = 0.07,
            shadowSat = 0.30,
            shadowLight = -0.35,
            highlightHue = 0.04,
            highlightSat = 0.25,
            highlightLight = 0.30
        }
    end
    return {
        shadowHue = -0.08,
        shadowSat = 0.20,
        shadowLight = -0.30,
        highlightHue = 0.03,
        highlightSat = 0.15,
        highlightLight = 0.25
    }
end

local function mix_anime(orig, dest, t, presetName)
    local base = mix_oklab(orig, dest, t)
    local preset = anime_preset(presetName)

    local shadow = clamp01((0.5 - t) / 0.5)
    local highlight = clamp01((t - 0.5) / 0.5)

    local hueShift = preset.shadowHue * shadow + preset.highlightHue * highlight
    local satShift = preset.shadowSat * shadow + preset.highlightSat * highlight
    local lightShift = preset.shadowLight * shadow + preset.highlightLight * highlight

    return colorShift(base, hueShift, satShift, lightShift, 0)
end

local function mix_color_at_percent(percent, mixSpace, shortestHue)
    local t = percent / 100.0
    if mixSpace == "sr-lab-2" then return mix_lab(state.left, state.right, t) end
    if mixSpace == "lch" then return mix_lch(state.left, state.right, t, shortestHue) end
    if mixSpace == "oklab" then return mix_oklab(state.left, state.right, t) end
    if mixSpace == "oklch" then return mix_oklch(state.left, state.right, t, shortestHue) end
    return mix_linear_srgb(state.left, state.right, t)
end

local function build_mix_shades(step, mixSpace, shortestHue)
    local colors = {}
    local count = math.floor(100 / step)
    for i = 0, count do
        local percent = i * step
        colors[#colors + 1] = mix_color_at_percent(percent, mixSpace, shortestHue)
    end
    if (100 % step) ~= 0 then
        colors[#colors + 1] = mix_color_at_percent(100, mixSpace, shortestHue)
    end
    return colors
end

local function build_anime_shades(step, preset)
    local colors = {}
    local count = math.floor(100 / step)
    for i = 0, count do
        local percent = i * step
        colors[#colors + 1] = mix_anime(state.left, state.right, percent / 100.0, preset)
    end
    if (100 % step) ~= 0 then
        colors[#colors + 1] = mix_anime(state.left, state.right, 1.0, preset)
    end
    return colors
end

local function update_mix_shades()
    dlg:modify {
        id = "mix",
        colors = build_mix_shades(MIX_STEP, get_mix_space(), get_shortest_hue()),
    }
    dlg:modify {
        id = "mix_anime_soft",
        colors = build_anime_shades(MIX_STEP, "anime-soft"),
    }
    dlg:modify {
        id = "mix_anime_punchy",
        colors = build_anime_shades(MIX_STEP, "anime-punchy"),
    }
    dlg:modify {
        id = "mix_anime_cool",
        colors = build_anime_shades(MIX_STEP, "anime-cool"),
    }
end

local function set_fg_color(color)
    app.fgColor = color
end

local function placeholder_shades()
    return { Color(0, 0, 0, 0) }
end

local function update_generated_palettes()
    if not state.base then
        return
    end

    local C = state.base
    local shade = {
        colorShift(C, 0, 0.3, -0.6, -0.6),
        colorShift(C, 0, 0.2, -0.2, -0.3),
        colorShift(C, 0, 0.1, -0.1, -0.1),
        C,
        colorShift(C, 0, 0.1, 0.1, 0.1),
        colorShift(C, 0, 0.2, 0.2, 0.2),
        colorShift(C, 0, 0.3, 0.5, 0.4)
    }

    local light = {
        colorShift(C, 0, 0, -0.4, 0),
        colorShift(C, 0, 0, -0.2, 0),
        colorShift(C, 0, 0, -0.1, 0),
        C,
        colorShift(C, 0, 0, 0.1, 0),
        colorShift(C, 0, 0, 0.2, 0),
        colorShift(C, 0, 0, 0.4, 0)
    }

    local sat = {
        colorShift(C, 0, -0.5, 0, 0),
        colorShift(C, 0, -0.2, 0, 0),
        colorShift(C, 0, -0.1, 0, 0),
        C,
        colorShift(C, 0, 0.1, 0, 0),
        colorShift(C, 0, 0.2, 0, 0),
        colorShift(C, 0, 0.5, 0, 0)
    }

    local hue = {
        colorShift(C, -0.15, 0, 0, 0),
        colorShift(C, -0.1, 0, 0, 0),
        colorShift(C, -0.05, 0, 0, 0),
        C,
        colorShift(C, 0.05, 0, 0, 0),
        colorShift(C, 0.1, 0, 0, 0),
        colorShift(C, 0.15, 0, 0, 0)
    }

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
end

local function load_pref_color(plugin, key, defaultColor)
    local stored = plugin.preferences[key]
    if stored == nil then
        plugin.preferences[key] = colorToInt(defaultColor)
        return defaultColor
    end
    return colorFromInt(stored)
end

local function save_pref_color(plugin, key, color)
    plugin.preferences[key] = colorToInt(color)
end

local function handle_left_color_change(value)
    state.left = value or dlg.data.lc
    update_mix_shades()
end

local function handle_right_color_change(value)
    state.right = value or dlg.data.rc
    update_mix_shades()
end

local function set_left_from_fg(plugin)
    state.left = Color(app.fgColor)
    dlg:modify { id = "lc", color = state.left }
    save_pref_color(plugin, "lc", state.left)
    update_mix_shades()
end

local function set_right_from_fg(plugin)
    state.right = Color(app.fgColor)
    dlg:modify { id = "rc", color = state.right }
    save_pref_color(plugin, "rc", state.right)
    update_mix_shades()
end

local function get_color_under_cursor()
    local editor = app.editor
    if not editor or not editor.sprite then
        return nil
    end

    local cel = app.activeCel
    if not cel or not cel.image then
        return nil
    end

    local pos = editor.spritePos
    if not pos then
        return nil
    end

    local x = pos.x - cel.position.x
    local y = pos.y - cel.position.y
    if x < 0 or y < 0 or x >= cel.image.width or y >= cel.image.height then
        return nil
    end

    local pixel = cel.image:getPixel(x, y)
    local pc = app.pixelColor
    local mode = editor.sprite.colorMode

    if mode == ColorMode.RGB then
        return Color {
            r = pc.rgbaR(pixel),
            g = pc.rgbaG(pixel),
            b = pc.rgbaB(pixel),
            a = pc.rgbaA(pixel)
        }
    elseif mode == ColorMode.GRAY then
        return Color {
            gray = pc.grayaV(pixel),
            alpha = pc.grayaA(pixel)
        }
    elseif mode == ColorMode.INDEXED then
        return Color { index = pixel }
    end

    return nil
end

local function set_left_from_cursor_or_fg(plugin)
    local picked = get_color_under_cursor() or Color(app.fgColor)
    state.left = picked
    dlg:modify { id = "lc", color = state.left }
    save_pref_color(plugin, "lc", state.left)
    update_mix_shades()
end

local function set_right_from_cursor_or_fg(plugin)
    local picked = get_color_under_cursor() or Color(app.fgColor)
    state.right = picked
    dlg:modify { id = "rc", color = state.right }
    save_pref_color(plugin, "rc", state.right)
    update_mix_shades()
end

local function handle_mix_click(ev)
    local index = ev.index or 1
    local percent = (index - 1) * MIX_STEP
    if percent > 100 then percent = 100 end
    state.percent = percent
    set_fg_color(ev.color)
end

local function handle_mix_space_change()
    update_mix_shades()
    set_fg_color(mix_color_at_percent(state.percent, get_mix_space(), get_shortest_hue()))
end

local function handle_shortest_hue_change()
    update_mix_shades()
    set_fg_color(mix_color_at_percent(state.percent, get_mix_space(), get_shortest_hue()))
end

local function handle_anime_click(ev)
    local index = ev.index or 1
    local percent = (index - 1) * MIX_STEP
    if percent > 100 then percent = 100 end
    state.percent = percent
    set_fg_color(ev.color)
end

local function handle_generated_click(ev)
    set_fg_color(ev.color)
end

local function add_to_palette()
    local spr = app.sprite
    if not spr then return end
    local pal = spr.palettes[1]
    if not pal then return end

    local mixed = mix_color_at_percent(state.percent, get_mix_space(), get_shortest_hue())

    local ncolors = #pal
    pal:resize(ncolors + 1)
    pal:setColor(ncolors, mixed)
end


function init(plugin)
    state.left = load_pref_color(plugin, "lc", Color(255, 255, 255, 1))
    state.right = load_pref_color(plugin, "rc", Color(0, 0, 0, 1))
    state.base = Color(app.fgColor)

    main(plugin)
end

function main(plugin)
    dlg:newrow()

        :color {
            id = "lc",
            color = state.left,
            onchange = function()
                handle_left_color_change()
            end
        }
        :color {
            id = "rc",
            color = state.right,
            onchange = function()
                handle_right_color_change()
            end
        }
        :shades { id = "mix", colors = build_mix_shades(MIX_STEP, "linear-srgb", true),
            onclick = function(ev)
                handle_mix_click(ev)
            end }
        :combobox {
            id = "mixSpace",
            option = "linear-srgb",
            options = { "linear-srgb", "sr-lab-2", "lch", "oklab", "oklch" },
            onchange = function()
                handle_mix_space_change()
            end
        }
        :check {
            id = "shortestHue",
            text = "Shortest Hue",
            selected = true,
            onclick = function()
                handle_shortest_hue_change()
            end
        }
    dlg:newrow()
    dlg:newrow()
    dlg:button {
        text = "Generate",
        onclick = function()
            state.base = Color(app.fgColor)
            update_generated_palettes()
        end
    }
    dlg:newrow()
        :shades { id = "gen_gray", colors = placeholder_shades(),
            onclick = function(ev)
                handle_generated_click(ev)
            end }
        :newrow()
        :shades { id = "gen_shade", colors = placeholder_shades(),
            onclick = function(ev)
                handle_generated_click(ev)
            end }
        :newrow()
        :shades { id = "gen_light", colors = placeholder_shades(),
            onclick = function(ev)
                handle_generated_click(ev)
            end }
        :newrow()
        :shades { id = "gen_sat", colors = placeholder_shades(),
            onclick = function(ev)
                handle_generated_click(ev)
            end }
        :newrow()
        :shades { id = "gen_hue", colors = placeholder_shades(),
            onclick = function(ev)
                handle_generated_click(ev)
            end }
        :newrow()
        :shades { id = "mix_anime_soft", colors = build_anime_shades(MIX_STEP, "anime-soft"),
            onclick = function(ev)
                handle_anime_click(ev)
            end }
        :newrow()
        :shades { id = "mix_anime_punchy", colors = build_anime_shades(MIX_STEP, "anime-punchy"),
            onclick = function(ev)
                handle_anime_click(ev)
            end }
        :newrow()
        :shades { id = "mix_anime_cool", colors = build_anime_shades(MIX_STEP, "anime-cool"),
            onclick = function(ev)
                handle_anime_click(ev)
            end }
    dlg:newrow()
    dlg:button {
        text = "Add to Palette",
        onclick = function()
            add_to_palette()
        end
    }

    plugin:newMenuGroup {
        id = "dipflix_menu",
        title = "Dipflix",
        group = "help_readme"

    }

    plugin:newCommand {
        id = "cm_open",
        title = "Color Mixer",
        group = "dipflix_menu",
        onclick = function()
            dlg:show { wait = false }
        end
    }

    plugin:newCommand {
        id = "cm_pick_left_color",
        title = "Color mixer pick left color",

        onclick = function()
            dlg:show { wait = false }
            set_left_from_cursor_or_fg(plugin)
        end
    }

    plugin:newCommand {
        id = "cm_pick_right_color",
        title = "Color mixer pick right color",
        onclick = function()
            dlg:show { wait = false }
            set_right_from_cursor_or_fg(plugin)
        end
    }
end

function exit(plugin)

end
