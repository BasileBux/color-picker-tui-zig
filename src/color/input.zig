const std = @import("std");
const col = @import("color.zig");
const u = @import("../utils.zig");
const c = @import("../commons.zig");
const w = @import("../widgets/widgets.zig");
const term = @import("../term.zig");
const input_field = @import("../widgets/fixed-size-input.zig");

pub const WIDTH: u8 = 16;
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
    g_input: input_field.FixedSizeInput,
    b_input: input_field.FixedSizeInput,

    h_input: input_field.FixedSizeInput,
    s_input: input_field.FixedSizeInput,
    l_input: input_field.FixedSizeInput,

    color_update: bool,

    const focus = enum {
        hex,
        rgb,
        hsl,
        none,
    };

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2, allocator: std.mem.Allocator) !ColorInput {
        return .{
            .stdout = stdout,
            .pos = pos,
            .hex = 0,
            .color = col.Color.init(),
            .hsl = col.Hsl.init(),
            .hex_input = try input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 1 }, 6, "# ", .hex, allocator),

            .r_input = try input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 3 }, 3, "R ", .numbers, allocator),
            .g_input = try input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 4 }, 3, "G ", .numbers, allocator),
            .b_input = try input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 5 }, 3, "B ", .numbers, allocator),

            .h_input = try input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 7 }, 3, "H ", .numbers, allocator),
            .s_input = try input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 8 }, 3, "S ", .numbers, allocator),
            .l_input = try input_field.FixedSizeInput.init(stdout, .{ .x = pos.x + 1, .y = pos.y + COLOR_BLOCK_HEIGHT + 9 }, 3, "L ", .numbers, allocator),

            .update_flag = true,
            .color_update = false,
        };
    }

    pub fn deinit(self: *ColorInput) void {
        self.hex_input.deinit();
        self.r_input.deinit();
        self.g_input.deinit();
        self.b_input.deinit();
        self.h_input.deinit();
        self.s_input.deinit();
        self.l_input.deinit();
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
        pad_number(color.g, 3, &buffer);
        self.g_input.updateColor(&buffer);
        pad_number(color.b, 3, &buffer);
        self.b_input.updateColor(&buffer);

        pad_number(@intFromFloat(color.toHsl().h), 3, &buffer);
        self.h_input.updateColor(&buffer);
        pad_number(@intFromFloat(color.toHsl().s * 100), 3, &buffer);
        self.s_input.updateColor(&buffer);
        pad_number(@intFromFloat(color.toHsl().l * 100), 3, &buffer);
        self.l_input.updateColor(&buffer);
    }

    pub fn update(self: *ColorInput, in: term.Input, offset: u.Vec2) !?col.Color {
        var color_update = false;

        color_update = self.hex_input.update(in, offset);
        if (color_update) {
            self.update_flag = true;
            self.color_update = true;
            return col.Color.fromHex(@intCast(self.hex_input.getNumber(0)));
        }

        const color_update_r = self.r_input.update(in, offset);
        const color_update_g = self.g_input.update(in, offset);
        const color_update_b = self.b_input.update(in, offset);
        if (color_update_r or color_update_g or color_update_b) {
            self.update_flag = true;
            self.color_update = true;
            return col.Color.fromRgb(
                @intCast(self.r_input.getNumber(255)),
                @intCast(self.g_input.getNumber(255)),
                @intCast(self.b_input.getNumber(255)),
            );
        }

        const color_update_h = self.h_input.update(in, offset);
        const color_update_s = self.s_input.update(in, offset);
        const color_update_l = self.l_input.update(in, offset);
        const s_value: f32 = @floatFromInt(self.s_input.getNumber(100));
        const l_value: f32 = @floatFromInt(self.l_input.getNumber(100));
        if (color_update_h or color_update_s or color_update_l) {
            self.update_flag = true;
            self.color_update = true;
            return try col.Color.fromHsl(
                @floatFromInt(self.h_input.getNumber(360)),
                s_value / 100.0,
                l_value / 100.0,
            );
        }

        if (self.hex_input.update_flag or self.r_input.update_flag or
            self.g_input.update_flag or self.b_input.update_flag or
            self.h_input.update_flag or self.s_input.update_flag or
            self.l_input.update_flag)
        {
            self.update_flag = true;
        }

        return null;
    }

    pub fn updatePos(self: *ColorInput, size: u32, add: bool) void {
        if (add) {
            self.pos.x += size;
            self.hex_input.pos.x += size;
            self.r_input.pos.x += size;
            self.g_input.pos.x += size;
            self.b_input.pos.x += size;
            self.h_input.pos.x += size;
            self.s_input.pos.x += size;
            self.l_input.pos.x += size;
        } else {
            self.pos.x -= size;
            self.hex_input.pos.x -= size;
            self.r_input.pos.x -= size;
            self.g_input.pos.x -= size;
            self.b_input.pos.x -= size;
            self.h_input.pos.x -= size;
            self.s_input.pos.x -= size;
            self.l_input.pos.x -= size;
        }
    }

    pub fn render(self: *ColorInput, offset: u.Vec2, background: ?[3]u8) !void {
        if (!self.update_flag) return;
        self.update_flag = false;
        const offset_x: i32 = if (self.pos.x + offset.x > 0) @intCast(self.pos.x + offset.x) else -1;
        const offset_y: i32 = if (self.pos.y + offset.y > 0) @intCast(self.pos.y + offset.y) else -1;

        try self.stdout.print("\x1b[H\x1b[{d}B\x1b[{d}C", .{ offset_y, offset_x });
        try self.stdout.print("\x1b[48;2;{d};{d};{d}m{s}", .{
            self.color.r,
            self.color.g,
            self.color.b,
            COLOR_BLOCK,
        });
        if (background) |bg| {
            try self.stdout.print("\x1b[48;2;{d};{d};{d}m", .{ bg[0], bg[1], bg[2] });
        } else {
            try self.stdout.print("\x1b[0m", .{});
        }

        try self.hex_input.render(offset);

        try self.r_input.render(offset);
        try self.g_input.render(offset);
        try self.b_input.render(offset);

        try self.h_input.render(offset);
        try self.s_input.render(offset);
        try self.l_input.render(offset);

        try self.hex_input.renderCursor(offset);

        try self.r_input.renderCursor(offset);
        try self.g_input.renderCursor(offset);
        try self.b_input.renderCursor(offset);

        try self.h_input.renderCursor(offset);
        try self.s_input.renderCursor(offset);
        try self.l_input.renderCursor(offset);
    }
};

pub fn pad_number(number: u16, size: usize, buffer: []u8) void {
    if (number >= 1000) return;
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
