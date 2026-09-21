const std = @import("std");
const ziggy_mod = @import("ziggy.zig");
const microzig = @import("microzig");
const pico = @import("pico.zig");
const ssd1306 = @import("drivers/ssd1306.zig");
const framebuffer = @import("framebuffer.zig");

const FrameBuffer = framebuffer.FrameBuffer;
const rp2xxx = microzig.hal;
const gpio = rp2xxx.gpio;
const time = rp2xxx.time;

pub const std_options = microzig.std_options(.{
    .log_level = .debug,
    .logFn = rp2xxx.uart.log,
});

const uart = rp2xxx.uart.instance.num(0);
const uart_tx_pin = gpio.num(0);

comptime {
    _ = microzig.export_startup();
}

pub fn main() !void {
    uart_tx_pin.set_function(.uart);
    uart.apply(.{
        .clock_config = rp2xxx.clock_config,
    });
    rp2xxx.uart.init_logger(uart);

    std.log.info("UART logger initialized", .{});

    std.log.info("applying pin configuration", .{});
    const pins = pico.apply();
    std.log.info("pin configuration applied", .{});

    std.log.info("initializing SSD1306", .{});
    const _ssd1306 = ssd1306.init(pins.oled_sda, pins.oled_scl) catch |e| {
        std.log.err("SSD1306 initialization failed: {s}", .{@errorName(e)});
        return;
    };
    std.log.info("SSD1306 initialized", .{});

    // var fb = _ssd1306.fb;
    
    var fb: FrameBuffer(128, 64, .vertical) = .{};

    fb.draw_bitmap(
        0,
        0,
        ziggy_mod.ZIGGY_WIDTH,
        ziggy_mod.ZIGGY_HEIGHT,
        &ziggy_mod.ZIGGY,
    );

    std.log.info("writing framebuffer to SSD1306", .{});
    var display = _ssd1306.display;
    display.write_full_display(fb.bit_stream()) catch |e| {
        std.log.err("failed to write framebuffer: {s}", .{@errorName(e)});
        return;
    };
    std.log.info("framebuffer written successfully", .{});

    std.log.debug("entering blink loop", .{});
    blink(pins);
}

fn blink(pins: pico.Pins) void {
    while (true) {
        pins.led.toggle();
        time.sleep_ms(1_000);
    }
}
