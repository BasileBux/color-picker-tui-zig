const std = @import("std");
const term = @import("term.zig");
const shade_pick = @import("color/shade-picker.zig");
const hue_pick = @import("color/hue-picker.zig");

const MIN_WIDTH = 32;
const MIN_HEIGHT = 16;

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

    win_too_small: bool,

    pub fn init(ctx: *term.TermContext) !Ui {
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
            .shade_picker = try shade_pick.ShadePicker.init(ctx.stdout, .{ .x = 2, .y = 2 }),
            .hue_picker = hue_pick.HuePicker.init(ctx.stdout, .{ .x = 38, .y = 2 }),
            .win_too_small = false,
        };
    }

    pub fn run(self: *Ui) !void {
        self.hue_picker.render();
        while (!self.exit_sig) {
            try self.signal_manager();
            if (self.win_too_small) continue;
            const in: term.Input = self.ctx.getInput() catch break;
            try self.shade_picker.update(in);
            self.hue_picker.update(in);
            switch (in) {
                term.InputType.control => |control| {
                    const unwrapped_control = control orelse term.ControlKeys.None;
                    switch (unwrapped_control) {
                        term.ControlKeys.Escape => {
                            self.exit_sig = true;
                            break;
                        },
                        else => {
                            // Handle other control keys
                        },
                    }
                },
                term.InputType.utf8 => |_| {},
                term.InputType.mouse => |_| {},
            }

            if (self.hue_picker.select_update) {
                self.hue_picker.select_update = false;
                self.shade_picker.color = self.hue_picker.selected_hue;
                self.shade_picker.render_update = true;
            }

            if (self.shade_picker.select_update) {
                // try self.ctx.stdout.print("\x1b[2J\x1b[H", .{}); // Clear screen and move cursor to top left
                try self.ctx.stdout.print("\x1b[H", .{}); // Move cursor to top left

                try self.ctx.stdout.print("\x1b[K", .{});
                try self.ctx.stdout.print("Selected color: {x} ({d} : {d}) - hue: {x}\n", .{
                    self.shade_picker.selected_color.toHex(),
                    self.shade_picker.selected_pos.x,
                    self.shade_picker.selected_pos.y,
                    self.hue_picker.selected_hue.toHex(),
                });
                self.shade_picker.select_update = false;
            }
            self.shade_picker.render();
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
            }
            self.shade_picker.render_update = true;
            self.hue_picker.render();
        }
    }
};
