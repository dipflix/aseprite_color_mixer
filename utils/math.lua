local M = {}

---@param color Color
---@return int
function M.colorToInt(color)
    return (color.red << 16) + (color.green << 8) + (color.blue)
end

---@param color number
---@return Color
function M.colorFromInt(color)
    return Color {
        red = (color >> 16) & 255,
        green = (color >> 8) & 255,
        blue = color & 255
    }
end

---@param v number
---@param lo number
---@param hi number
---@return number
function M.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

---@param v number
---@return number
function M.clamp01(v)
    return M.clamp(v, 0.0, 1.0)
end

---@param first number
---@param second number
---@param by number
---@return number
function M.lerp(first, second, by)
    return first * (1 - by) + second * by
end

---@param color1 number
---@param color2 number
---@param amount number
---@return number
function M.lerpRGBInt(color1, color2, amount)
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

return M
