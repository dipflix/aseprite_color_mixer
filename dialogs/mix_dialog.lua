local math_utils = require("utils.math")
local math_color = require("utils.math_color")
local editor_utils = require("utils.editor")

local M = {}

local dlg = Dialog { id = "cm_d", title = "Color mixer", visible = false }
local MIX_STEP = 12
local DEFAULT_PERCENT = 50

local plugin_ref = nil

local state = {
    left = nil,
    right = nil,
    percent = DEFAULT_PERCENT,
    auto_change_to_last_index = false,
    active_mix_index = nil,
    shades = {}
}

local function build_active_index_indicator_colors()
    local indicator = {}
    for i = 1, #state.shades do
        if i == state.active_mix_index then
            indicator[#indicator + 1] = Color(255, 255, 255)
        else
            indicator[#indicator + 1] = Color(0, 0, 0)
        end
    end
    return indicator
end

local function update_active_index_indicator()
    dlg:modify {
        id = "mixActive",
        colors = build_active_index_indicator_colors()
    }
end

local function get_mix_space()
    return dlg.data.mixSpace or "linear-srgb"
end

local function mix_color_at_percent(percent, mixSpace)
    local t = percent / 100.0
    if mixSpace == "sr-lab-2" then return math_color.mix_lab(state.left, state.right, t) end
    if mixSpace == "lch" then return math_color.mix_lch(state.left, state.right, t, true) end
    if mixSpace == "oklab" then return math_color.mix_oklab(state.left, state.right, t) end
    if mixSpace == "oklch" then return math_color.mix_oklch(state.left, state.right, t, true) end
    return math_color.mix_linear_srgb(state.left, state.right, t)
end

local function build_mix_shades(step, mixSpace)
    local shades = {}
    local count = math.floor(100 / step)
    for i = 0, count do
        local percent = i * step
        shades[#shades + 1] = mix_color_at_percent(percent, mixSpace)
    end
    if (100 % step) ~= 0 then
        shades[#shades + 1] = mix_color_at_percent(100, mixSpace)
    end
    state.shades = shades
    return shades
end

local function get_mix_color_by_active_index()
    local index = state.active_mix_index
    if type(index) ~= "number" then return nil end

    local shades = state.shades or {}
    if index < 1 or index > #shades then return nil end

    return shades[index]
end

local function resolve_mix_slot_from_click(ev)
    local shades = state.shades or {}
    if #shades == 0 then
        shades = build_mix_shades(MIX_STEP, get_mix_space())
    end
    if #shades == 0 then
        return nil
    end

    local raw = tonumber(ev.index)
    if raw then
        -- Aseprite returns zero-based index in shades click events.
        local from_left = math.floor(raw) + 1
        if from_left < 1 then from_left = 1 end
        if from_left > #shades then from_left = #shades end
        return from_left
    end

    if ev.color then
        for i = 1, #shades do
            if shades[i].rgbaPixel == ev.color.rgbaPixel then
                return i
            end
        end
    end

    return 1
end

local function update_mix_shades()
    dlg:modify {
        id = "mix",
        colors = build_mix_shades(MIX_STEP, get_mix_space()),
    }
    if type(state.active_mix_index) == "number" and state.active_mix_index > #state.shades then
        state.active_mix_index = nil
    end
    update_active_index_indicator()
end

local function normalize_mix_step(value)
    local step = tonumber(value)
    if not step then return nil end
    step = math.floor(step + 0.5)
    if step < 1 then step = 1 end
    if step > 100 then step = 100 end
    return step
end

local function handle_mix_step_change()
    local step = normalize_mix_step(dlg.data.mixStep)
    if not step then
        dlg:modify { id = "mixStep", text = tostring(MIX_STEP) }
        return
    end
    if step == MIX_STEP then return end
    MIX_STEP = step
    update_mix_shades()
end

local function set_fg_color(color)
    app.fgColor = color
end

local function load_pref_color(plugin, key, defaultColor)
    local stored = plugin.preferences[key]
    if stored == nil then
        plugin.preferences[key] = math_utils.colorToInt(defaultColor)
        return defaultColor
    end
    return math_utils.colorFromInt(stored)
end

local function save_pref_color(plugin, key, color)
    plugin.preferences[key] = math_utils.colorToInt(color)
end

local function load_pref_bool(plugin, key, defaultValue)
    local stored = plugin.preferences[key]
    if stored == nil then
        local encoded = defaultValue and 1 or 0
        plugin.preferences[key] = encoded
        return defaultValue
    end
    if type(stored) == "boolean" then
        return stored
    end
    if type(stored) == "number" then
        return stored ~= 0
    end
    if type(stored) == "string" then
        local normalized = string.lower(stored)
        return normalized == "1" or normalized == "true"
    end
    return defaultValue
end

local function save_pref_bool(plugin, key, value)
    plugin.preferences[key] = value and 1 or 0
end

local function apply_auto_change_to_last_index_if_enabled(selectedColor)
    if not state.auto_change_to_last_index then
        return
    end

    local mixColor = get_mix_color_by_active_index()
    if mixColor then
        set_fg_color(mixColor)
        return
    end

    set_fg_color(selectedColor)
end

local function handle_left_color_change(value)
    state.left = value or dlg.data.lc
    update_mix_shades()
    apply_auto_change_to_last_index_if_enabled(state.left)
end

local function handle_right_color_change(value)
    state.right = value or dlg.data.rc
    update_mix_shades()
    apply_auto_change_to_last_index_if_enabled(state.right)
end

local function set_left_from_cursor_or_fg()
    local picked = editor_utils.get_color_under_cursor() or Color(app.fgColor)
    state.left = picked
    dlg:modify { id = "lc", color = state.left }
    save_pref_color(plugin_ref, "lc", state.left)
    update_mix_shades()
    apply_auto_change_to_last_index_if_enabled(state.left)
end

local function set_right_from_cursor_or_fg()
    local picked = editor_utils.get_color_under_cursor() or Color(app.fgColor)
    state.right = picked
    dlg:modify { id = "rc", color = state.right }
    save_pref_color(plugin_ref, "rc", state.right)
    update_mix_shades()
    apply_auto_change_to_last_index_if_enabled(state.right)
end

local function handle_mix_click(ev)
    local index = resolve_mix_slot_from_click(ev) or 1
    local percent = (index - 1) * MIX_STEP
    if percent > 100 then percent = 100 end
    state.active_mix_index = index
    state.percent = percent
    update_active_index_indicator()
    set_fg_color(state.shades[index] or ev.color)
end

local function handle_mix_space_change()
    update_mix_shades()
    set_fg_color(mix_color_at_percent(state.percent, get_mix_space()))
end

local function add_to_palette()
    local spr = app.sprite
    if not spr then return end
    local pal = spr.palettes[1]
    if not pal then return end

    local mixed = mix_color_at_percent(state.percent, get_mix_space())

    local ncolors = #pal
    pal:resize(ncolors + 1)
    pal:setColor(ncolors, mixed)
end

function M.init(plugin)
    plugin_ref = plugin

    plugin:newCommand {
        id = "cm_open",
        title = "Color Mixer",
        group = "dipflix_menu",
        onclick = function()
            dlg:show { wait = false }
        end
    }

    state.left = load_pref_color(plugin, "lc", Color(255, 255, 255, 1))
    state.right = load_pref_color(plugin, "rc", Color(0, 0, 0, 1))
    state.auto_change_to_last_index = load_pref_bool(
        plugin,
        "auto_change_to_last_index",
        load_pref_bool(plugin, "auth_change_to_last_index", false)
    )

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
        :shades {
            id = "mix",
            colors = build_mix_shades(MIX_STEP, "linear-srgb"),
            mode = "pick",
            onclick = function(ev)
                handle_mix_click(ev)
            end
        }
    dlg:newrow()
        :shades {
            id = "mixActive",
            colors = build_active_index_indicator_colors(),
        }
    dlg:newrow()
        :combobox {
            id = "mixSpace",
            option = "linear-srgb",
            options = { "linear-srgb", "sr-lab-2", "lch", "oklab", "oklch" },
            onchange = function()
                handle_mix_space_change()
            end
        }
        :entry {
            id = "mixStep",
            label = "Step",
            text = tostring(MIX_STEP),
            onchange = function()
                handle_mix_step_change()
            end
        }
        :check {
            id = "auto_change_to_last_index",
            label = "",
            selected = state.auto_change_to_last_index,
            onclick = function()
                state.auto_change_to_last_index = dlg.data.auto_change_to_last_index and true or false
                save_pref_bool(plugin_ref, "auto_change_to_last_index", state.auto_change_to_last_index)
            end
        }

    dlg:newrow()
    dlg:button {
        text = "Add to Palette",
        onclick = function()
            add_to_palette()
        end
    }
    update_active_index_indicator()
end

function M.pick_left_from_cursor_or_fg()
    M.show()
    set_left_from_cursor_or_fg()
end

function M.pick_right_from_cursor_or_fg()
    M.show()
    set_right_from_cursor_or_fg()
end

function M.show()
    dlg:show { wait = false }
end

return M
