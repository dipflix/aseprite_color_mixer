local function ensure_package_path()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    local script_dir = app.fs.filePath(source)
    local dir_sep = package.config:sub(1, 1)
    local path_sep = package.config:sub(3, 3)
    local module_path = script_dir .. dir_sep .. "?.lua"
    local init_path = script_dir .. dir_sep .. "?" .. dir_sep .. "init.lua"
    if not string.find(package.path, script_dir, 1, true) then
        package.path = package.path .. path_sep .. module_path .. path_sep .. init_path
    end
end

ensure_package_path()

local palette = require("palette")
local mix_dialog = require("dialogs.mix_dialog")
local custom_dialog = require("dialogs.custom_dialog")
local color_shift_v2 = require("dialogs.color_shift_v2")

function init(plugin)
    main(plugin)
    mix_dialog.init(plugin)
    custom_dialog.init(plugin)
    color_shift_v2.init(plugin)
    palette.init(plugin)
end

function main(plugin)
    plugin:newMenuGroup {
        id = "dipflix_menu",
        title = "Dipflix",
        group = "help_readme"
    }


    plugin:newCommand {
        id = "cm_custom_open",
        title = "Custom shifts",
        group = "dipflix_menu",
        onclick = function()
            custom_dialog.show()
        end
    }

    plugin:newCommand {
        id = "cm_pick_left_color",
        title = "Color mixer pick left color",
        onclick = function()
            mix_dialog.pick_left_from_cursor_or_fg()
        end
    }

    plugin:newCommand {
        id = "cm_pick_right_color",
        title = "Color mixer pick right color",
        onclick = function()
            mix_dialog.pick_right_from_cursor_or_fg()
        end
    }
end

function exit(plugin)
end
