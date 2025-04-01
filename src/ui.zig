const std = @import("std");
const term = @import("term.zig");
const shade_pick = @import("color/shade-picker.zig");
const hue_pick = @import("color/hue-picker.zig");
const commons = @import("commons.zig");
const color_input = @import("color/input.zig");
const u = @import("utils.zig");
const color = @import("color/color.zig");
const cb = @import("clipboard.zig");

const MIN_WIDTH: u32 = @intFromFloat(commons.SIZE_GLOBAL + 2 * commons.SPACING + hue_pick.WIDTH + 2 * commons.SPACING + color_input.WIDTH);
const MIN_HEIGHT: u32 = @intFromFloat(commons.SIZE_GLOBAL / 2 + 5);

var window_resized = std.atomic.Value(bool).init(false);
fn handleSigwinch(sig: c_int) callconv(.C) void {
    _ = sig;
    window_resized.store(true, .seq_cst);
}

var sigint_received: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
fn handleSigint(_: c_int) callconv(.C) void {
    sigint_received.store(true, .seq_cst);
}

pub const Ui = struct {
    ctx: *term.TermContext,
    exit_sig: bool,

    shade_picker: shade_pick.ShadePicker,
    hue_picker: hue_pick.HuePicker,
    input: color_input.ColorInput,
    allocator: std.mem.Allocator,

    pos: u.Vec2,

    win_too_small: bool,

    pub fn init(ctx: *term.TermContext, allocator: std.mem.Allocator) !Ui {
        // Signal handling
        const sigint_act = std.os.linux.Sigaction{
            .handler = .{ .handler = handleSigint },
            .mask = std.os.linux.empty_sigset,
            .flags = 0,
        };
        _ = std.os.linux.sigaction(std.os.linux.SIG.INT, &sigint_act, null);
        const sigwinch_act = std.os.linux.Sigaction{
            .handler = .{ .handler = handleSigwinch },
            .mask = std.os.linux.empty_sigset,
            .flags = 0,
        };
        _ = std.os.linux.sigaction(std.os.linux.SIG.WINCH, &sigwinch_act, null);

        return Ui{
            .ctx = ctx,
            .exit_sig = false,
            .shade_picker = try shade_pick.ShadePicker.init(ctx.stdout, allocator, .{ .x = 1, .y = 2 }),
            .hue_picker = hue_pick.HuePicker.init(ctx.stdout, .{ .x = commons.SIZE_GLOBAL + commons.SPACING, .y = 2 }),
            .input = try color_input.ColorInput.init(ctx.stdout, .{ .x = commons.SIZE_GLOBAL + 2 * commons.SPACING + hue_pick.WIDTH - 1, .y = 2 }, allocator),
            .allocator = allocator,
            .pos = .{ .x = 0, .y = 0 },
            .win_too_small = false,
        };
    }

    pub fn deinit(self: *Ui) void {
        self.input.deinit();
    }

    pub fn run(self: *Ui) !void {
        const pid = std.os.linux.getpid();
        _ = std.os.linux.kill(pid, std.os.linux.SIG.WINCH);

        self.hue_picker.render(.{ .x = 50, .y = 0 });
        while (!self.exit_sig) {
            try self.signal_manager();
            const in: term.Input = self.ctx.getInput() catch break;
            try self.shade_picker.update(in, self.pos);
            self.hue_picker.update(in, self.pos);
            const input_color = try self.input.update(in, self.pos);
            switch (in) {
                term.InputType.control => |control| {
                    const unwrapped_control = control orelse term.ControlKeys.None;
                    switch (unwrapped_control) {
                        term.ControlKeys.Escape => {
                            self.exit_sig = true;
                        },
                        else => {
                            // Handle other control keys
                        },
                    }
                },
                term.InputType.utf8 => |char| {
                    if (char[0] == 'q') self.exit_sig = true;
                },
                term.InputType.mouse => |mouse| {
                    const button = mouse.b & 0x3;
                    const is_drag = mouse.b & 32;
                    const modifiers = mouse.b & 12;

                    const TOP_HEX_OFF: u32 = 3 * @as(u32, commons.WHITESPACE.len);
                    const TOP_HEX_SIZE: u32 = 14;

                    const TOP_RGB_OFF: u32 = TOP_HEX_OFF + TOP_HEX_SIZE + @as(u32, commons.WHITESPACE.len);
                    var TOP_RGB_SIZE: u32 = 0;
                    TOP_RGB_SIZE += if (self.shade_picker.color.r == 0) 1 else std.math.log10(self.shade_picker.color.r);
                    TOP_RGB_SIZE += if (self.shade_picker.color.g == 0) 1 else std.math.log10(self.shade_picker.color.g);
                    TOP_RGB_SIZE += if (self.shade_picker.color.b == 0) 1 else std.math.log10(self.shade_picker.color.b);
                    TOP_RGB_SIZE += 10;

                    const TOP_HSL_OFF: u32 = TOP_RGB_OFF + TOP_RGB_SIZE + @as(u32, commons.WHITESPACE.len);
                    const hsl_color = self.shade_picker.selected_color.toHsl();
                    var TOP_HSL_SIZE: u32 = 0;
                    TOP_HSL_SIZE = if (hsl_color.h == 0) 1 else std.math.log10(@as(u32, @intFromFloat(hsl_color.h)));
                    TOP_HSL_SIZE = if (hsl_color.s == 0) 1 else std.math.log10(@as(u32, @intFromFloat(hsl_color.s * 100)));
                    TOP_HSL_SIZE = if (hsl_color.l == 0) 1 else std.math.log10(@as(u32, @intFromFloat(hsl_color.l * 100)));
                    TOP_HSL_SIZE += 23;

                    if (mouse.x >= self.pos.x + TOP_HEX_OFF and mouse.x < self.pos.x + TOP_HEX_OFF + TOP_HEX_SIZE and
                        mouse.y >= self.pos.y + 1 and mouse.y < self.pos.y + 2 and button == 0 and is_drag == 0 and modifiers == 0)
                    {
                        try cb.write_wayland_clipboard(self.allocator, try self.shade_picker.color.toHexString(self.allocator));
                    }

                    if (mouse.x >= self.pos.x + TOP_RGB_OFF and mouse.x < self.pos.x + TOP_RGB_OFF + TOP_RGB_SIZE and
                        mouse.y >= self.pos.y + 1 and mouse.y < self.pos.y + 2 and button == 0 and is_drag == 0 and modifiers == 0)
                    {
                        try cb.write_wayland_clipboard(self.allocator, try self.shade_picker.color.toRgb(self.allocator));
                    }

                    if (mouse.x >= self.pos.x + TOP_HSL_OFF and mouse.x < self.pos.x + TOP_HSL_OFF + TOP_HSL_SIZE and
                        mouse.y >= self.pos.y + 1 and mouse.y < self.pos.y + 2 and button == 0 and is_drag == 0 and modifiers == 0)
                    {
                        try cb.write_wayland_clipboard(self.allocator, try self.shade_picker.color.toHslString(self.allocator));
                    }
                },
            }
            if (self.win_too_small) continue;

            var fixed_color = false;
            if (input_color) |col| {
                self.shade_picker.selected_color = col;
                fixed_color = true;

                self.hue_picker.select_update = true;
                self.hue_picker.selected_hue = try color.Color.fromHsl(col.toHsl().h, 1, 0.5);

                self.shade_picker.select_update = true;
                self.input.color = col;
                self.input.updateColor(col);
            }

            if (self.hue_picker.select_update) {
                self.hue_picker.select_update = false;
                self.shade_picker.color = self.hue_picker.selected_hue;
                self.shade_picker.render_update = true;
                self.input.updateColor(self.shade_picker.color);
            }

            if (self.shade_picker.select_update) {
                if (self.ctx.background_color) |bg| {
                    try self.ctx.stdout.print("\x1B[48;2;{};{};{}m", .{ bg[0], bg[1], bg[2] });
                }

                try self.ctx.stdout.print("\x1b[H", .{}); // Move cursor to top left

                try self.ctx.stdout.print("\x1b[K", .{});
                try self.ctx.stdout.print("\x1b[{d}C\x1b[{d}B", .{ self.pos.x + 1, self.pos.y });
                try self.ctx.stdout.print("\x1B[0m\x1B[48;2;{};{};{}m{s}{s}\x1B[0m", .{
                    self.shade_picker.selected_color.r,
                    self.shade_picker.selected_color.g,
                    self.shade_picker.selected_color.b,
                    commons.WHITESPACE,
                    commons.WHITESPACE,
                });
                if (self.ctx.background_color) |bg| {
                    try self.ctx.stdout.print("\x1B[48;2;{};{};{}m", .{ bg[0], bg[1], bg[2] });
                }
                const hex_color = self.shade_picker.selected_color.toHex();
                const hsl_color = self.shade_picker.selected_color.toHsl();
                try self.ctx.stdout.print("{s}HEX: #{x:0>6}{s}RGB: {d}, {d}, {d}{s}HSL: {d:.0}, {d:.2}%, {d:.2}%", .{
                    commons.WHITESPACE,
                    hex_color,
                    commons.WHITESPACE,
                    self.shade_picker.selected_color.r,
                    self.shade_picker.selected_color.g,
                    self.shade_picker.selected_color.b,
                    commons.WHITESPACE,
                    hsl_color.h,
                    hsl_color.s * 100,
                    hsl_color.l * 100,
                });
                self.input.updateColor(self.shade_picker.selected_color);
                self.shade_picker.select_update = false;
            }
            self.shade_picker.calculateTableAndRender(fixed_color, self.pos);
            try self.input.render(self.pos, self.ctx.background_color);
        }
    }

    fn signal_manager(self: *Ui) !void {
        if (sigint_received.load(.seq_cst)) {
            sigint_received.store(false, .seq_cst);
            self.exit_sig = true;
            return;
        }
        if (window_resized.load(.seq_cst)) {
            window_resized.store(false, .seq_cst);
            try self.ctx.getTermSize();
            try self.ctx.stdout.print("\x1b[2J\x1b[H", .{}); // Clear screen and move cursor to top left
            if (self.ctx.win_size.cols < MIN_WIDTH or self.ctx.win_size.rows < MIN_HEIGHT) {
                self.win_too_small = true;
                try self.ctx.stdout.print("Window too small", .{});
                try self.ctx.stdout.print("Min size: {d} x {d}", .{ MIN_WIDTH, MIN_HEIGHT });
            } else {
                self.win_too_small = false;
                self.pos.x = if (self.ctx.win_size.cols > MIN_WIDTH) @intCast(self.ctx.win_size.cols / 2 - MIN_WIDTH / 2) else 0;
                self.pos.y = if (self.ctx.win_size.rows > MIN_HEIGHT) @intCast(self.ctx.win_size.rows / 2 - MIN_HEIGHT / 2) else 0;

                if (self.ctx.background_color) |bg| {
                    try self.ctx.stdout.print("\x1B[48;2;{};{};{}m", .{ bg[0], bg[1], bg[2] });
                }
                try self.ctx.stdout.print("\x1b[2J\x1b[H", .{}); // Clear screen and move cursor to top left
                self.shade_picker.render_update = true;
                self.hue_picker.render(self.pos);
            }
        }
    }
};
