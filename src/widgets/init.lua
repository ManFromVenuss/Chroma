-- The single registration point for widgets. container.lua generates its
-- methods from this map, so it never learns what any individual widget is --
-- adding a widget in a later milestone is one line here plus one new file.

return {
    Label = require("widgets/label"),
    Separator = require("widgets/separator"),
    Toggle = require("widgets/toggle"),
    Slider = require("widgets/slider"),
    Dropdown = require("widgets/dropdown"),
    Button = require("widgets/button"),
    TextBox = require("widgets/textbox"),
    Keybind = require("widgets/keybind"),
}
