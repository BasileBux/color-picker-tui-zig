const std = @import("std");
const c = @import("color.zig");
const w = @import("../widgets.zig");
const u = @import("../../utils.zig");

const SIZE: u8 = 30;

pub const ColorPicker = struct {
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    color: c.Color, // color in the top right corner
    color_table: [SIZE][SIZE]c.Color,

    update_flag: bool,

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2) !ColorPicker {
        return .{
            .stdout = stdout,
            .pos = pos,
            .color = try c.Color.initRandom(),
            .color_table = undefined,
            .update_flag = true,
        };
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

        var pos = self.pos;
        for (0..SIZE) |i| {
            const red_h_coef: f32 = ((max_left_value - red_float) / size);

            const green_h_coef: f32 = ((max_left_value - green_float) / size);

            const blue_h_coef: f32 = ((max_left_value - blue_float) / size);

            pos.x = self.pos.x;
            for (0..SIZE) |j| {
                const j_float: f32 = @floatFromInt(j);

                var top_col = self.color;
                top_col.r = @intFromFloat(max_left_value - (red_h_coef * j_float));

                top_col.g = @intFromFloat(max_left_value - (green_h_coef * j_float));

                top_col.b = @intFromFloat(max_left_value - (blue_h_coef * j_float));

                pos.x += 1;
                self.color_table[i][j] = top_col;
            }
            pos.y += 1;
            max_left_value -= left_delta;
            red_float -= right_r_delta;
            green_float -= right_g_delta;
            blue_float -= right_b_delta;
        }
    }

    pub fn render(self: *ColorPicker) void {
        if (!self.update_flag) return;
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
        self.update_flag = false;
    }
};
