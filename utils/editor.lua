
local M = {}

---Returns the composited color under the mouse cursor (all layers).
---Supports RGB, Grayscale, and Indexed color modes.
---@return Color|nil
function M.get_color_under_cursor()
    local editor = app.editor
    if not editor or not editor.sprite then
        return nil
    end

    local pos = editor.spritePos
    if not pos then
        return nil
    end

    if pos.x < 0 or pos.y < 0 or pos.x >= editor.sprite.width or pos.y >= editor.sprite.height then
        return nil
    end

    local image = Image(editor.sprite.spec)
    image:drawSprite(editor.sprite, app.activeFrame)

    local pixel = image:getPixel(pos.x, pos.y)
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

return M
