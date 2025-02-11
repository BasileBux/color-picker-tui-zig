const std = @import("std");
const term = @import("term.zig");
const widgets = @import("widgets/widgets.zig");
const in_f = @import("widgets/input.zig");
const col_pick = @import("widgets/color-picker/color-picker.zig");

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
    input_field: in_f.InputField,
    color_picker: col_pick.ColorPicker,
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
            .input_field = in_f.InputField.init(ctx.stdout, .{ .x = 1, .y = 1 }, .{ .x = ctx.win_size.cols - 2, .y = 3 }),
            .color_picker = try col_pick.ColorPicker.init(ctx.stdout, .{ .x = 0, .y = 0 }),
            .win_too_small = false,
        };
    }

    pub fn run(self: *Ui) !void {
        self.input_field.update_flag = false;
        while (!self.exit_sig) {
            try self.signal_manager();
            if (self.win_too_small) continue;
            const in: term.Input = self.ctx.getInput() catch break;
            // self.input_field.update(in);
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

            if (self.input_field.update_flag or self.color_picker.update_flag) {
                try self.ctx.stdout.print("\x1b[2J\x1b[H", .{}); // Clear screen and move cursor to top left
            }
            self.color_picker.render();
            // try self.input_field.render();
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
            self.input_field.update_flag = true;
        }
    }
};
