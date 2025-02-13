const std = @import("std");
const w = @import("../widgets/widgets.zig");
const u = @import("../utils.zig");
const col = @import("color.zig");
const term = @import("../term.zig");

const HEIGHT: f32 = 32.0;
const I_HEIGHT: u32 = @intFromFloat(HEIGHT);
const WIDTH: f32 = 4.0;
const I_WIDTH: u32 = @intFromFloat(WIDTH);
const STEPS: f32 = 12.0;
const DELTA: f32 = 255.0 / ((HEIGHT * 2) / STEPS);

pub const HuePicker = struct {
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    selected_hue: col.Color,
    select_update: bool,
    tint_picker: [@intFromFloat(HEIGHT * 2.0)]col.Color = init: {
        var buff: [@intFromFloat(HEIGHT * 2.0)]col.Color = undefined;
        var red_float: f32 = 255.0;
        var green_float: f32 = 0.0;
        var blue_float: f32 = 0.0;
        const step_size: usize = @intFromFloat((HEIGHT * 2.0) / STEPS);
        for (0..@intFromFloat(HEIGHT * 2.0)) |i| {
            buff[i] = col.Color.fromRgb(@intFromFloat(red_float), @intFromFloat(green_float), @intFromFloat(blue_float));
            if (i < step_size) {
                green_float += DELTA;
                continue;
            }
            if (i < 2 * step_size) {
                red_float -= DELTA;
                continue;
            }
            if (i < 3 * step_size) {
                blue_float += DELTA;
                continue;
            }
            if (i < 4 * step_size) {
                green_float -= DELTA;
                continue;
            }
            if (i < 5 * step_size) {
                red_float += DELTA;
                continue;
            }
            if (i < 6 * step_size) {
                blue_float -= DELTA;
                continue;
            }
        }
        break :init buff;
    },

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2) HuePicker {
        return .{
            .stdout = stdout,
            .pos = pos,
            .selected_hue = col.Color.fromHex(0xff0000),
            .select_update = true,
        };
    }

    pub fn update(self: *HuePicker, in: term.Input) void {
        switch (in) {
            .mouse => |mouse| {
                const button = mouse.b & 0x3;
                const is_drag = mouse.b & 32;
                const modifiers = mouse.b & 12;

                if (mouse.x >= self.pos.x and mouse.x <= self.pos.x + I_WIDTH and
                    mouse.y > self.pos.y and mouse.y <= self.pos.y + (I_HEIGHT / 2) and
                    button == 0 and is_drag >= 0 and modifiers == 0 and mouse.suffix == 'M')
                {
                    var y_idx = ((mouse.y - 1) - self.pos.y) * 2;
                    y_idx = if (y_idx >= I_HEIGHT - 2) I_HEIGHT - 1 else y_idx;
                    self.selected_hue = self.tint_picker[y_idx];
                    self.select_update = true;
                }
            },
            else => {},
        }
    }

    pub fn render(self: HuePicker) void {
        var pos_r: u.Vec2 = self.pos;
        var i: usize = 0;
        while (i < HEIGHT) {
            for (0..WIDTH) |_| {
                w.draw_2_stacked_pixels(self.stdout, pos_r, self.tint_picker[i], self.tint_picker[i + 1]) catch {};
                pos_r.x += 1;
            }
            pos_r.y += 1;
            pos_r.x = self.pos.x;
            i += 2;
        }
    }
};
