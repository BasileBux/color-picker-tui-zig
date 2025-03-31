const std = @import("std");
const u = @import("../utils.zig");
const term = @import("../term.zig");

pub const FixedSizeInput = struct {
    update_flag: bool,
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    input_buffer: []u8,
    input_len: usize,
    constraint: Constraint,
    title: []const u8,
    focused: bool,

    pub const Constraint = enum {
        hex,
        numbers,
        none,
    };

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2, buff: []const u8, title: []const u8, constraint: Constraint) FixedSizeInput {
        return .{
            .update_flag = true,
            .stdout = stdout,
            .pos = pos,
            .input_buffer = @constCast(buff),
            .input_len = buff.len,
            .constraint = constraint,
            .title = title,
            .focused = false,
        };
    }

    fn validateConstraint(self: FixedSizeInput, in: [4]u8) bool {
        if (in[0] & 0x80 != 0) return false;
        switch (self.constraint) {
            .hex => {
                if (in[0] >= '0' and in[0] <= '9') return true;
                if (in[0] >= 'a' and in[0] <= 'f') return true;
                if (in[0] >= 'A' and in[0] <= 'F') return true;
                return false;
            },
            .numbers => {
                if (in[0] >= '0' and in[0] <= '9') return true;
                return false;
            },
            else => return true,
        }
    }

    pub fn updateColor(self: *FixedSizeInput, buf: []const u8) void {
        self.input_len = 0;
        for (buf) |char| {
            self.input_buffer[self.input_len] = char;
            self.input_len += 1;
        }
        self.update_flag = true;
    }

    pub fn update(self: *FixedSizeInput, in: term.Input) void {
        switch (in) {
            .utf8 => |input| {
                if (self.input_len >= self.input_buffer.len) {
                    self.input_len = 0;
                    self.update_flag = true;
                    return;
                }
                if (self.validateConstraint(input)) {
                    self.update_flag = true;
                    const char = input[0];
                    self.input_buffer[self.input_len] = char;
                    self.input_len += 1;
                }
            },
            .mouse => |mouse| {
                const button = mouse.b & 0x3;
                const is_drag = mouse.b & 32;
                const modifiers = mouse.b & 12;

                if (mouse.x >= self.pos.x and mouse.x < self.pos.x +
                    self.input_buffer.len + self.title.len and
                    mouse.y >= self.pos.y and mouse.y < self.pos.y + 1)
                {
                    if (button == 0 and is_drag == 0 and modifiers == 0 and mouse.suffix == 'M') {
                        self.focused = true;
                        self.update_flag = true;
                    }
                } else {
                    if (button == 0 and is_drag >= 0 and modifiers == 0 and mouse.suffix == 'M') {
                        self.focused = false;
                        self.update_flag = true;
                    }
                }
            },
            else => return,
        }
    }

    pub fn render(self: *FixedSizeInput) !void {
        if (!self.update_flag) return;
        self.update_flag = false;
        try self.stdout.print("\x1b[{d};{d}H\x1b[K", .{ self.pos.y, self.pos.x });

        if (self.focused) {
            try self.stdout.print("\x1b[31m", .{});
        } else {
            try self.stdout.print("\x1b[0m", .{});
        }

        try self.stdout.print("{s}{s}\n", .{ self.title, self.input_buffer });

        try self.stdout.print("\x1b[0m", .{});
    }
};
