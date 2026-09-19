const std = @import("std");

const PixelPacking = enum { horizontal, vertical };

pub fn FrameBuffer(
    comptime width: usize,
    comptime height: usize,
    comptime packing: PixelPacking,
) type {
    return struct {
        const Self = @This();

        pixels: [width * height / 8]u8 = @splat(0),

        pub fn bit_stream(self: *const Self) *const [1024]u8 {
            return &self.pixels;
        }

        pub fn set_pixel(self: *Self, x: usize, y: usize) void {
            switch (packing) {
                .vertical => self.set_pixel_VBP(x, y),
                .horizontal => self.set_pixel_HBP(x, y),
            }
        }

        pub fn unset_pixel(self: *Self, x: usize, y: usize) void {
            switch (packing) {
                .vertical => self.unset_pixel_VBP(x, y),
                .horizontal => self.unset_pixel_HBP(x, y),
            }
        }

        pub fn get_pixel(self: *Self, x: usize, y: usize) u8 {
            return switch (packing) {
                .vertical => self.get_pixel_VBP(x, y),
                .horizontal => self.get_pixel_HBP(x, y),
            };
        }

        fn set_pixel_HBP(self: *Self, x: usize, y: usize) void {
            const bit = x & 7;
            const pos = (width * y + x) >> 3;

            self.pixels[pos] |= (@as(u8, 0x80) >> @truncate(bit));
        }

        fn set_pixel_VBP(self: *Self, x: usize, y: usize) void {
            const page = y >> 3; // div 8
            const bit = y & 7; // mod 8
            const offset = page * width + x; // page << 7 + x

            self.pixels[offset] |= (@as(u8, 1) << @truncate(bit));
        }

        fn unset_pixel_HBP(self: *Self, x: usize, y: usize) void {
            const bit = x & 7;
            const pos = (width * y + x) >> 3;

            self.pixels[pos] &= ~(@as(u8, 0x80) >> @truncate(bit));
        }

        pub fn unset_pixel_VBP(self: *Self, x: usize, y: usize) void {
            const page = y >> 3;
            const bit = y & 7;
            const offset = page * width + x; // for 128 (page << 7) + x

            self.pixels[offset] &= ~(@as(u8, 1) << @truncate(bit));
        }

        fn get_pixel_HBP(self: *Self, x: usize, y: usize) u8 {
            const pos = (width * y + x) >> 3;

            return self.pixels[pos] & (@as(u8, 0x80) >> @truncate(x));
        }

        fn get_pixel_VBP(self: *const Self, x: usize, y: usize) u8 {
            const page = y >> 3; // div 8
            const pos = page * width + x;
            const bit = y & 7; // mod 8

            return self.pixels[pos] & (@as(u8, 1) << @truncate(bit));
        }

        fn get_packed_byte(self: *const Self, x: usize, y: usize) u8 {
            const page = y >> 3;
            const pos = page * width + x;
            return self.pixels[pos];
        }

        pub fn draw_bitmap(
            self: *Self,
            start_x: u7,
            start_y: u6,
            bm_width: usize,
            bm_height: usize,
            bitmap: []const u8,
        ) void {
            const bytes_per_row = width >> 3;

            for (0..bm_height) |y| {
                for (0..bm_width) |x| {
                    if (start_x + x >= bm_width) continue;
                    if (start_y + y >= bm_height) continue;

                    const byte_index = y * bytes_per_row + (x >> 3);
                    const bit_index = x & 7;
                    const mask = @as(u8, 0x80) >> @truncate(bit_index);

                    if (bitmap[byte_index] & mask != 0)
                        self.set_pixel(start_x + x, start_y + y)
                    else
                        self.unset_pixel(start_x + x, start_y + y);
                }
            }
        }
    };
}

test "set pixel with horizontal pixel packing" {
    var fb: FrameBuffer(128, 64, .horizontal) = .{};

    fb.set_pixel(0, 0);
    const p1 = fb.get_pixel(0, 0);
    try std.testing.expectEqual(0b10000000, p1);

    fb.set_pixel(1, 0);
    const p2 = fb.get_pixel(1, 0);
    try std.testing.expectEqual(0b01000000, p2);

    const b1 = fb.get_packed_byte(0, 0);
    try std.testing.expectEqual(0b11000000, b1);
}

test "set pixel with vertical pixel packing" {
    var fb: FrameBuffer(128, 64, .vertical) = .{};

    fb.set_pixel(0, 0);
    const p1 = fb.get_pixel(0, 0);
    try std.testing.expectEqual(0b00000001, p1);

    fb.set_pixel(0, 1);
    const p2 = fb.get_pixel(0, 1);
    try std.testing.expectEqual(0b00000010, p2);

    const b1 = fb.get_packed_byte(0, 0);
    try std.testing.expectEqual(0b00000011, b1);
}

test "draw bitmap for vertical framebuffer" {
    var fb: FrameBuffer(24, 24, .vertical) = .{};

    const bm = [_]u8{
        0b11111111, 0b11111111, 0b11111111,
        0b11111111, 0b00000000, 0b11111111,
        0b11111111, 0b11111111, 0b11111111,
    };

    fb.draw_bitmap(0, 0, 24, 3, &bm);

    try std.testing.expectEqual(0b00000111, fb.get_packed_byte(0, 0));
    try std.testing.expectEqual(0b00000101, fb.get_packed_byte(8, 0));
    try std.testing.expectEqual(0b00000101, fb.get_packed_byte(9, 0));
}

test "draw bitmap for horizontal framebuffer" {
    var fb: FrameBuffer(24, 24, .horizontal) = .{};

    const bm = [_]u8{
        0b11111111, 0b11111111, 0b11111111,
        0b11111111, 0b00000000, 0b11111111,
        0b11111111, 0b11111111, 0b11111111,
    };

    fb.draw_bitmap(0, 0, 24, 3, &bm);

    try std.testing.expectEqual(0b11111111, fb.get_packed_byte(0, 0));
    try std.testing.expectEqual(0b11111111, fb.get_packed_byte(8, 1));
}

test "draw horizontal bitmap clips at right edge" {
    var fb: FrameBuffer(24, 24, .horizontal) = .{};

    const bm = [_]u8{
        0b11111111, 0b11111111, 0b11111111,
        0b11111111, 0b00000000, 0b11111111,
        0b11111111, 0b11111111, 0b11111111,
    };

    fb.draw_bitmap(8, 0, 24, 3, &bm);

    try std.testing.expectEqual(0b00000000, fb.get_packed_byte(0, 0));
    try std.testing.expectEqual(0b00000000, fb.get_packed_byte(0, 1));
    try std.testing.expectEqual(0b00000000, fb.get_packed_byte(0, 2));
    try std.testing.expectEqual(0b11111111, fb.get_packed_byte(8, 1));
}

test "draw vertical bitmap clips at right edge" {
    var fb: FrameBuffer(24, 24, .vertical) = .{};

    const bm = [_]u8{
        0b11111111, 0b11111111, 0b11111111,
        0b11111111, 0b00000000, 0b11111111,
        0b11111111, 0b11111111, 0b11111111,
    };

    fb.draw_bitmap(8, 0, 24, 3, &bm);

    try std.testing.expectEqual(0b00000000, fb.get_packed_byte(0, 8));
    try std.testing.expectEqual(
        0b00000111,
        fb.get_packed_byte(8, 0),
    );
    try std.testing.expectEqual(
        0b00000101,
        fb.get_packed_byte(16, 0),
    );
}
