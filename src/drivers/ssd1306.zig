const std = @import("std");
const microzig = @import("microzig");

const rp2xxx = microzig.hal;

const I2C_ADDR: u7 = 0x3C;

const Self = @This();

pub const Display = microzig.drivers.display.ssd1306.SSD1306_Generic(.{
    .mode = .i2c,
    .DatagramDevice = rp2xxx.drivers.I2C_DatagramDevice,
    .Digital_IO = @TypeOf(null),
});

fb: microzig.drivers.display.ssd1306.Framebuffer,
display: Display,

pub fn init(sda_pin: anytype, scl_pin: anytype) !Self {
    std.log.info("SSD1306: configuring pins", .{});

    inline for (.{ scl_pin, sda_pin }) |pin| {
        pin.set_slew_rate(.slow);
        pin.set_schmitt_trigger_enabled(true);
        pin.set_function(.i2c);
    }

    std.log.info("SSD1306: pins configured", .{});

    const i2c = rp2xxx.i2c.instance.num(1);

    std.log.info("SSD1306: configuring I2C1", .{});

    i2c.apply(.{
        .baud_rate = 400_000,
        .clock_config = rp2xxx.clock_config,
    });

    std.log.info("SSD1306: I2C1 configured", .{});

    const i2c_dd = rp2xxx.drivers.I2C_DatagramDevice.init(
        i2c,
        @fromBackingInt(I2C_ADDR),
        null,
    );

    std.log.info("SSD1306: datagram device created", .{});
    std.log.info("SSD1306: calling driver init", .{});

    const display = try microzig.drivers.display.ssd1306.init(
        .i2c,
        i2c_dd,
        null,
    );

    std.log.info("SSD1306: driver init completed", .{});

    return .{
        .display = display,
        .fb = .init(.black),
    };
}
