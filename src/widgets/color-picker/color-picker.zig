const std = @import("std");
const col = @import("color.zig");
const w = @import("../widgets.zig");
const u = @import("../../utils.zig");

pub const ColorPicker = struct {
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    size: u.Vec2,
    color: col.Color, // color in the top right corner

    update_flag: bool,

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2, size: u.Vec2) !ColorPicker {
        return .{
            .stdout = stdout,
            .pos = pos,
            .size = size,
            // .color = try col.Color.initRandom(),
            .color = col.Color.fromHex(0xff0000),
            .update_flag = true,
        };
    }

    pub fn render(self: *ColorPicker) !void {
        // Blue for testing: 0x0000ff
        if (!self.update_flag) return;

        const width: f32 = @floatFromInt(self.size.x);
        const height: f32 = @floatFromInt(self.size.y);

        const red_float: f32 = @floatFromInt(self.color.r);
        const red_h_coef: f32 = ((255.0 - red_float) / width);
        const red_v_coef: f32 = (red_float / height);

        const green_float: f32 = @floatFromInt(self.color.g);
        const green_h_coef: f32 = ((255.0 - green_float) / width);
        const green_v_coef: f32 = (green_float / height);

        const blue_float: f32 = @floatFromInt(self.color.b);
        const blue_h_coef: f32 = ((255.0 - blue_float) / width);
        const blue_v_coef: f32 = (blue_float / height);

        for (0..self.size.x) |i| {
            const i_float: f32 = @floatFromInt(i);

            var top_col = self.color;
            if (self.color.r != 0xff) {
                top_col.r = @intFromFloat(255 - (red_h_coef * i_float));
            }

            if (top_col.g != 0xff) {
                top_col.g = @intFromFloat(255 - (green_h_coef * i_float));
            }

            if (top_col.b != 0xff) {
                top_col.b = @intFromFloat(255 - (blue_h_coef * i_float));
            }

            var bot_col = top_col;
            bot_col.r = @intFromFloat(red_v_coef * i_float);
            bot_col.g = @intFromFloat(green_v_coef * i_float);
            bot_col.b = @intFromFloat(blue_v_coef * i_float);
            var pos = self.pos;
            pos.x += @intCast(i);

            try w.draw_2_stacked_pixels(self.stdout, pos, top_col, bot_col);
        }
        self.update_flag = false;
    }
};
