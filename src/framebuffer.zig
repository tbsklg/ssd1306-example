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

test "set pixel hbp" {
    var fb: FrameBuffer(128, 64, .horizontal) = .{};

    fb.set_pixel(0, 0);
    const p1 = fb.get_pixel(0, 0);
    try std.testing.expectEqual(0b10000000, p1);

    fb.set_pixel(1, 0);
    const p2 = fb.get_pixel(1, 0);
    try std.testing.expectEqual(0b01000000, p2);

    // const b1 = fb.getBox(0, 0);
    // try std.testing.expectEqual(0b11000000, b1);
}
