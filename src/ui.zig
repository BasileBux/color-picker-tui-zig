const std = @import("std");
const term = @import("term.zig");
const widgets = @import("widgets/widgets.zig");
const in_f = @import("widgets/input.zig");
const col_pick = @import("widgets/color-picker/color-picker.zig");
const tint_pick = @import("widgets/color-picker/tint-picker.zig");

const MIN_WIDTH = 80;
const MIN_HEIGHT = 24;

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

    color_picker: col_pick.ColorPicker,
    tint_picker: tint_pick.TintPicker,

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
            .color_picker = try col_pick.ColorPicker.init(ctx.stdout, .{ .x = 2, .y = 2 }),
            .tint_picker = tint_pick.TintPicker.init(ctx.stdout, .{ .x = 38, .y = 2 }),
            .win_too_small = false,
        };
    }

    pub fn run(self: *Ui) !void {
        self.tint_picker.render();
        while (!self.exit_sig) {
            try self.signal_manager();
            if (self.win_too_small) continue;
            const in: term.Input = self.ctx.getInput() catch break;
            try self.color_picker.update(in);
            self.tint_picker.update(in);
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

            if (self.tint_picker.select_update) {
                self.tint_picker.select_update = false;
                self.color_picker.color = self.tint_picker.selected_tint;
                self.color_picker.render_update = true;
            }

            if (self.color_picker.select_update) {
                // try self.ctx.stdout.print("\x1b[2J\x1b[H", .{}); // Clear screen and move cursor to top left
                try self.ctx.stdout.print("\x1b[H", .{}); // Move cursor to top left

                try self.ctx.stdout.print("\x1b[K", .{});
                try self.ctx.stdout.print("Selected color: {x}\n", .{self.color_picker.selected_color.toHex()});
                self.color_picker.select_update = false;
            }
            self.color_picker.render();
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
            self.color_picker.render_update = true;
            self.tint_picker.render();
        }
    }
};
