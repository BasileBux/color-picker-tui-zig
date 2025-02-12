const std = @import("std");
const c = @import("color.zig");
const w = @import("../widgets.zig");
const u = @import("../../utils.zig");
const term = @import("../../term.zig");

const SIZE: u16 = 32;

pub const ColorPicker = struct {
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    color: c.Color, // color in the top right corner
    selected_color: c.Color,
    color_table: [SIZE][SIZE]c.Color,

    render_update: bool,
    select_update: bool,

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2) !ColorPicker {
        return .{
            .stdout = stdout,
            .pos = pos,
            .color = try c.Color.initRandom(),
            .selected_color = c.Color.init(),
            .color_table = undefined,
            .render_update = true,
            .select_update = true,
        };
    }

    pub fn update(self: *ColorPicker, in: term.Input) !void {
        switch (in) {
            .mouse => |mouse| {
                const button = mouse.b & 0x3;
                const is_drag = mouse.b & 32;
                const modifiers = mouse.b & 12;

                if (mouse.x >= self.pos.x and mouse.x <= self.pos.x + SIZE and
                    mouse.y > self.pos.y and mouse.y <= (self.pos.y + SIZE) / 2 + 1 and
                    button == 0 and is_drag >= 0 and modifiers == 0 and mouse.suffix == 'M')
                {
                    const x_idx = if ((mouse.x - 1) >= self.pos.x) (mouse.x - 1) - self.pos.x else 0;
                    var y_idx = ((mouse.y - 1) - self.pos.y) * 2;
                    y_idx = if (y_idx >= SIZE - 2) SIZE - 1 else y_idx;
                    self.selected_color = self.color_table[y_idx][x_idx];
                    self.select_update = true;
                }
            },
            else => {},
        }
    }

    pub fn calculateTable(self: *ColorPicker) void {
        const size: f32 = @floatFromInt(SIZE);

        var max_left_value: f32 = 255.0;
        const left_delta: f32 = max_left_value / size;

        var red_float: f32 = @floatFromInt(self.color.r);
        var green_float: f32 = @floatFromInt(self.color.g);
        var blue_float: f32 = @floatFromInt(self.color.b);

        const right_r_delta: f32 = red_float / (size - 1);
        const right_g_delta: f32 = green_float / (size - 1);
        const right_b_delta: f32 = blue_float / (size - 1);

        for (0..SIZE) |i| {
            const red_h_coef: f32 = ((max_left_value - red_float) / size);

            const green_h_coef: f32 = ((max_left_value - green_float) / size);

            const blue_h_coef: f32 = ((max_left_value - blue_float) / size);

            for (0..SIZE) |j| {
                if (i == SIZE - 1) {
                    self.color_table[i][j] = c.Color.fromRgb(0, 0, 0);
                    continue;
                }
                const j_float: f32 = @floatFromInt(j);

                var top_col = self.color;
                top_col.r = @intFromFloat(max_left_value - (red_h_coef * j_float));

                top_col.g = @intFromFloat(max_left_value - (green_h_coef * j_float));

                top_col.b = @intFromFloat(max_left_value - (blue_h_coef * j_float));

                self.color_table[i][j] = top_col;
            }
            max_left_value -= left_delta;
            red_float -= right_r_delta;
            green_float -= right_g_delta;
            blue_float -= right_b_delta;
        }
    }

    pub inline fn clear(self: *ColorPicker) void {
        w.clear_zone(self.stdout, self.pos, .{ .x = SIZE, .y = SIZE / 2 }) catch {};
    }

    pub fn render(self: *ColorPicker) void {
        if (!self.render_update) return;
        self.clear();
        self.calculateTable();
        var pos_r = self.pos;
        var i: usize = 0;
        var j: usize = 0;
        while (i < self.color_table.len) {
            pos_r.x = self.pos.x;
            while (j < self.color_table[i].len) {
                w.draw_2_stacked_pixels(self.stdout, pos_r, self.color_table[i][j], self.color_table[i + 1][j]) catch {};
                pos_r.x += 1;
                j += 1;
            }
            j = 0;
            pos_r.y += 1;
            i += 2;
        }
        self.render_update = false;
    }
};
