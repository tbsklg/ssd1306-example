const microzig = @import("microzig");
const rp2xxx = microzig.hal;

// Compile-time pin configuration
const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO14 = .{ .name = "oled_sda", .direction = .in, .pull = .up },
    .GPIO15 = .{ .name = "oled_scl", .direction = .in, .pull = .up },
    .GPIO25 = .{ .name = "led", .direction = .out },
};

pub const Pins = @TypeOf(pin_config.apply());

pub fn apply() Pins {
    return pin_config.apply();
}
