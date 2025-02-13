const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn init() Color {
        return .{
            .r = 0,
            .g = 0,
            .b = 0,
            .a = 0,
        };
    }

    pub fn initRandom() !Color {
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();
        return .{
            .r = rand.int(u8),
            .g = rand.int(u8),
            .b = rand.int(u8),
            .a = 255,
        };
    }

    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn fromRgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromHex(hex: u24) Color {
        return .{
            .r = @truncate(hex >> 16),
            .g = @truncate(hex >> 8),
            .b = @truncate(hex),
            .a = 255,
        };
    }

    pub fn fromHexWithAlpha(hexa: u32) Color {
        var ret = fromHex(@truncate(hexa));
        ret.b = @truncate(hexa);
        return ret;
    }

    pub fn fromHsl(h: f32, s: f32, l: f32) !Color {
        if (h > 360.0 or s > 1 or h > 1) return error.ColorOutOfRange;
        const c = (1 - @abs(2 * l - 1)) * s;
        const x = c * (1 - @abs(@mod(h / 60, 2) - 1));
        const m = l - c / 2;

        var r: f32 = 0;
        var g: f32 = 0;
        var b: f32 = 0;

        if (h >= 0 and h < 60) {
            r = c;
            g = x;
            b = 0;
        } else if (h >= 60 and h < 120) {
            r = x;
            g = c;
            b = 0;
        } else if (h >= 120 and h < 180) {
            r = 0;
            g = c;
            b = x;
        } else if (h >= 180 and h < 240) {
            r = 0;
            g = x;
            b = c;
        } else if (h >= 240 and h < 300) {
            r = x;
            g = 0;
            b = c;
        } else {
            r = c;
            g = 0;
            b = x;
        }

        return .{
            .r = @intFromFloat(@round((r + m) * 255)),
            .g = @intFromFloat(@round((g + m) * 255)),
            .b = @intFromFloat(@round((b + m) * 255)),
            .a = 255,
        };
    }

    pub fn toRgb(self: *Color) ![]const u8 {
        var buffer: [11]u8 = undefined; // xxx,xxx,xxx
        const slice = try std.fmt.bufPrint(&buffer, "{d},{d},{d}", .{ self.r, self.g, self.b });
        return slice;
    }

    pub fn toRgba(self: *Color) ![]const u8 {
        var buffer: [15]u8 = undefined; // xxx,xxx,xxx,xxx
        const slice = try std.fmt.bufPrint(&buffer, "{d},{d},{d},{d}", .{ self.r, self.g, self.b, self.a });
        return slice;
    }

    pub fn toHex(self: Color) u24 {
        var hex: u24 = 0;
        hex |= @as(u24, self.r) << 16;
        hex |= @as(u24, self.g) << 8;
        hex |= self.b;
        return hex;
    }

    pub fn toHexWithAlpha(self: *Color) u32 {
        const hex = self.toHex();
        return (hex << 8) | self.a;
    }

    pub fn toHsl(self: *Color) Hsl {
        var r: f32 = @floatFromInt(self.r);
        r /= 255.0;
        var g: f32 = @floatFromInt(self.g);
        g /= 255.0;
        var b: f32 = @floatFromInt(self.b);
        b /= 255.0;
        const min: f32 = @min(r, @min(g, b));
        const max: f32 = @max(r, @max(g, b));
        const l: f32 = (max + min) / 2.0;

        var s: f32 = 0.0;
        if (max != min) {
            if (l > 0.5) {
                s = (max - min) / (2.0 - max - min);
            } else {
                s = (max - min) / (max + min);
            }
        }

        var h: f32 = 0.0;
        if (max != min) {
            if (max == r) {
                h = (g - b) / (max - min);
            } else if (max == g) {
                h = 2.0 + (b - r) / (max - min);
            } else {
                h = 4.0 + (r - g) / (max - min);
            }
        }
        h *= 60.0;
        if (h < 0) {
            h += 360.0;
        }

        return .{
            .h = h,
            .s = s,
            .l = l,
        };
    }

    pub fn invert(self: Color) Color {
        self.r = 0xff - self.r;
        self.g = 0xff - self.g;
        self.b = 0xff - self.b;
    }

    pub fn newInverted(self: Color) Color {
        return .{
            .r = 0xff - self.r,
            .g = 0xff - self.g,
            .b = 0xff - self.b,
        };
    }
};

pub const Hsl = struct {
    h: f32,
    s: f32,
    l: f32,
};
