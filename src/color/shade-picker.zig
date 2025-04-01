const std = @import("std");
const c = @import("color.zig");
const w = @import("../widgets/widgets.zig");
const u = @import("../utils.zig");
const term = @import("../term.zig");
const commons = @import("../commons.zig");

/// SIZE must be even. If not, the picker's last row will be incorrect.
pub const SIZE: u16 = @intFromFloat(commons.SIZE_GLOBAL);

pub const ShadePicker = struct {
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    color: c.Color, // color in the top right corner
    selected_color: c.Color,
    selected_pos: u.Vec2,
    color_table: [SIZE][SIZE]c.Color,
    allocator: std.mem.Allocator,

    render_update: bool,
    select_update: bool,

    pub fn init(stdout: std.fs.File.Writer, allocator: std.mem.Allocator, pos: u.Vec2) !ShadePicker {
        return .{
            .stdout = stdout,
            .pos = pos,
            .color = c.Color.init(),
            .selected_color = c.Color.init(),
            .selected_pos = .{ .x = SIZE - 1, .y = 0 },
            .color_table = undefined,
            .render_update = true,
            .select_update = true,
            .allocator = allocator,
        };
    }

    pub fn update(self: *ShadePicker, in: term.Input, offset: u.Vec2) !void {
        switch (in) {
            .mouse => |mouse| {
                const button = mouse.b & 0x3;
                const is_drag = mouse.b & 32;
                const modifiers = mouse.b & 12;

                if (mouse.x >= self.pos.x + offset.x and mouse.x <= self.pos.x + offset.x + SIZE and
                    mouse.y > self.pos.y + offset.y and mouse.y <= (self.pos.y + offset.y + SIZE) / 2 + 1 and
                    button == 0 and is_drag >= 0 and modifiers == 0 and mouse.suffix == 'M')
                {
                    var x_idx = if ((mouse.x - 1) >= (self.pos.x + offset.x)) (mouse.x - 1) - (self.pos.x + offset.y) else 0;
                    x_idx = if (x_idx >= SIZE) SIZE - 1 else x_idx;
                    var y_idx = ((mouse.y - 1) - (self.pos.y + offset.y)) * 2;
                    y_idx = if (y_idx >= SIZE - 2) SIZE - 1 else y_idx;
                    self.selected_color = self.color_table[y_idx][x_idx];
                    self.selected_pos = .{ .x = x_idx, .y = y_idx };
                    self.select_update = true;
                }
            },
            else => {},
        }
    }

    pub fn calculateTableAndRender(self: *ShadePicker, fixed_color: bool, offset: u.Vec2) void {
        if (!self.render_update) return;
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        // Initial cursor positioning
        const offset_x: i32 = if (self.pos.x + offset.x > 0) @intCast(self.pos.x + offset.x) else -1;
        const offset_y: i32 = if (self.pos.y + offset.y > 0) @intCast(self.pos.y + offset.y) else -1;
        buffer.writer().print("\x1b[H\x1b[{d}B\x1b[{d}C", .{ offset_y, offset_x }) catch {};

        const size: f32 = @floatFromInt(SIZE);
        var max_left_value: f32 = 255.0; // White in top left corner
        var red_float: f32 = @floatFromInt(self.color.r);
        var green_float: f32 = @floatFromInt(self.color.g);
        var blue_float: f32 = @floatFromInt(self.color.b);
        // Deltas are vertical
        const left_delta: f32 = max_left_value / size;
        const right_r_delta: f32 = red_float / (size - 1);
        const right_g_delta: f32 = green_float / (size - 1);
        const right_b_delta: f32 = blue_float / (size - 1);

        var i: usize = 0;
        while (i < SIZE - 1) : (i += 2) {
            // Top color horizontal deltas
            const red_h_coef1: f32 = ((max_left_value - red_float) / (size - 1));
            const green_h_coef1: f32 = ((max_left_value - green_float) / (size - 1));
            const blue_h_coef1: f32 = ((max_left_value - blue_float) / (size - 1));

            // Pre-calculate coefficients for bottom color
            const next_max_left = max_left_value - left_delta;
            const next_red = red_float - right_r_delta;
            const next_green = green_float - right_g_delta;
            const next_blue = blue_float - right_b_delta;
            const red_h_coef2: f32 = ((next_max_left - next_red) / (size - 1));
            const green_h_coef2: f32 = ((next_max_left - next_green) / (size - 1));
            const blue_h_coef2: f32 = ((next_max_left - next_blue) / (size - 1));

            for (0..SIZE) |j| {
                const j_float: f32 = @floatFromInt(j);

                // Calculate colors for current and next row simultaneously
                const r1: u8 = @intFromFloat(max_left_value - (red_h_coef1 * j_float));
                const g1: u8 = @intFromFloat(max_left_value - (green_h_coef1 * j_float));
                const b1: u8 = @intFromFloat(max_left_value - (blue_h_coef1 * j_float));

                const r2: u8 = @intFromFloat(next_max_left - (red_h_coef2 * j_float));
                const g2: u8 = @intFromFloat(next_max_left - (green_h_coef2 * j_float));
                const b2: u8 = @intFromFloat(next_max_left - (blue_h_coef2 * j_float));

                self.color_table[i][j] = c.Color{ .r = r1, .g = g1, .b = b1, .a = 0xff };
                self.color_table[i + 1][j] = c.Color{ .r = r2, .g = g2, .b = b2, .a = 0xff };

                // Build output string for rendering
                buffer.writer().print("\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m\u{2580}", .{
                    r1, g1, b1,
                    r2, g2, b2,
                }) catch {};
            }
            buffer.writer().print("\x1b[B\x1b[{d}D", .{SIZE}) catch {};

            // Update values for next iteration
            max_left_value = next_max_left - left_delta;
            red_float = next_red - right_r_delta;
            green_float = next_green - right_g_delta;
            blue_float = next_blue - right_b_delta;
        }

        buffer.writer().print("\x1b[0m", .{}) catch {};
        self.stdout.writeAll(buffer.items) catch {};

        self.select_update = true;
        if (!fixed_color) self.selected_color = self.color_table[self.selected_pos.y][self.selected_pos.x];
        self.render_update = false;
    }

    pub inline fn clear(self: *ShadePicker) void {
        w.clear_zone(self.stdout, self.pos, .{ .x = SIZE, .y = SIZE / 2 }) catch {};
    }
};
