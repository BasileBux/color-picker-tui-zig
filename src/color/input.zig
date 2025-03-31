const std = @import("std");
const col = @import("color.zig");
const u = @import("../utils.zig");
const c = @import("../commons.zig");
const w = @import("../widgets/widgets.zig");
const term = @import("../term.zig");
const input_field = @import("../widgets/fixed-size-input.zig");

const WIDTH: u8 = 16;
const HEIGHT: u8 = c.SIZE_GLOBAL / 2 - 1;
const COLOR_BLOCK_HEIGHT: u8 = 4;
const NEW_LINE_SIZE = 2 + // \x1b
    2 + // [B
    2 + // [
    std.math.log10(WIDTH) + 1 + // digits for WIDTH
    1; // D

const CB_LINE_SIZE = WIDTH +
    2 + // \x1b
    2 + // [B
    2 + // [
    std.math.log10(WIDTH) + 1 + // digits for WIDTH
    1; // D

const COLOR_BLOCK = cblk: {
    var buffer: [CB_LINE_SIZE * COLOR_BLOCK_HEIGHT]u8 = undefined;
    var offset = 0;

    var i = 0;
    while (i < COLOR_BLOCK_HEIGHT) : (i += 1) {
        var j = 0;
        while (j < WIDTH) : (j += 1) {
            buffer[offset] = ' ';
            offset += 1;
        }

        const escape = std.fmt.comptimePrint("\x1b[B\x1b[{d}D", .{WIDTH});
        var k = 0;
        while (k < escape.len) : (k += 1) {
            buffer[offset] = escape[k];
            offset += 1;
        }
    }

    break :cblk buffer;
};

pub const ColorInput = struct {
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    hex: u24,
    color: col.Color,
    hsl: col.Hsl,
    update_flag: bool,

    hex_input: input_field.FixedSizeInput,
    r_input: input_field.FixedSizeInput,

    const focus = enum {
        hex,
        rgb,
        hsl,
        none,
    };

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2) ColorInput {
        var buffer = [_]u8{ '0', '0', '0' };
        var hex_buf = [_]u8{ '0', '0', '0', '0', '0', '0' };

        return .{
            .stdout = stdout,
            .pos = pos,
            .hex = 0,
            .color = col.Color.init(),
            .hsl = col.Hsl.init(),
            .hex_input = input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 1 }, &hex_buf, "# ", .hex),
            .r_input = input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 3 }, &buffer, "R ", .numbers),
            .update_flag = true,
        };
    }

    pub fn updateColor(self: *ColorInput, color: col.Color) void {
        self.update_flag = true;
        self.color = color;
        self.hsl = color.toHsl();

        const buf = color.toHexString() catch unreachable;
        self.hex_input.updateColor(buf);

        var buffer: [3]u8 = undefined;
        pad_number(color.r, 3, &buffer);
        self.r_input.updateColor(&buffer);
    }

    pub fn update(self: *ColorInput, in: term.Input) !void {
        self.hex_input.update(in);
        self.r_input.update(in);
        if (self.hex_input.update_flag or self.r_input.update_flag) {
            self.update_flag = true;
        }
    }

    pub fn render(self: *ColorInput) !void {
        if (!self.update_flag) return;
        const offset_x: i32 = if (self.pos.x > 0) @intCast(self.pos.x) else -1;
        const offset_y: i32 = if (self.pos.y > 0) @intCast(self.pos.y) else -1;

        try self.stdout.print("\x1b[H\x1b[{d}B\x1b[{d}C", .{ offset_y, offset_x });
        try self.stdout.print("\x1b[48;2;{d};{d};{d}m{s}\x1b[0m", .{
            self.color.r,
            self.color.g,
            self.color.b,
            COLOR_BLOCK,
        });

        try self.hex_input.render();
        try self.r_input.render();
    }
};

pub fn pad_number(number: u8, size: usize, buffer: []u8) void {
    var temp_buf: [3]u8 = undefined; // Large enough for any u8
    const numStr = std.fmt.bufPrint(&temp_buf, "{d}", .{number}) catch unreachable;

    const numLen = numStr.len;
    if (numLen > size) {
        @memcpy(buffer[0..size], numStr[numLen - size ..]);
    } else {
        @memset(buffer[0 .. size - numLen], '0');
        @memcpy(buffer[size - numLen .. size], numStr);
    }
}
