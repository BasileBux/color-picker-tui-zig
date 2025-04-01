const std = @import("std");
const u = @import("../utils.zig");
const term = @import("../term.zig");
const cp = @import("../clipboard.zig");

pub const FixedSizeInput = struct {
    update_flag: bool,
    stdout: std.fs.File.Writer,
    pos: u.Vec2,
    input_buffer: []u8,
    input_len: usize,
    constraint: Constraint,
    title: []const u8,
    focused: bool,

    allocator: std.mem.Allocator,

    pub const Constraint = enum {
        hex,
        numbers,
        none,
    };

    pub fn init(stdout: std.fs.File.Writer, pos: u.Vec2, buff_size: usize, title: []const u8, constraint: Constraint, allocator: std.mem.Allocator) !FixedSizeInput {
        return .{
            .update_flag = true,
            .stdout = stdout,
            .pos = pos,
            .input_buffer = try allocator.alloc(u8, buff_size),
            .input_len = buff_size - 1,
            .constraint = constraint,
            .title = title,
            .focused = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FixedSizeInput) void {
        self.allocator.free(self.input_buffer);
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

    pub fn getNumber(self: *FixedSizeInput, max: u32) u32 {
        if (self.constraint == .hex) {
            return u.hex_string_to_int(self.input_buffer);
        } else {
            const num = u.string_to_int(self.input_buffer);
            if (num > max) return max;
            return num;
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

    pub fn update(self: *FixedSizeInput, in: term.Input, offset: u.Vec2) bool {
        switch (in) {
            .mouse => |mouse| {
                const button = mouse.b & 0x3;
                const is_drag = mouse.b & 32;
                const modifiers = mouse.b & 12;

                if (mouse.x >= self.pos.x + offset.x and mouse.x < self.pos.x +
                    self.input_buffer.len + self.title.len + offset.x and
                    mouse.y >= self.pos.y + offset.y and mouse.y < self.pos.y + offset.y + 1)
                {
                    if (button == 0 and is_drag == 0 and modifiers == 0 and mouse.suffix == 'M') {
                        self.focused = true;
                        self.input_len = 0;
                        self.update_flag = true;
                    }
                } else {
                    if (button == 0 and is_drag >= 0 and modifiers == 0 and mouse.suffix == 'M') {
                        self.focused = false;
                        self.stdout.print("\x1B[?25l", .{}) catch {};
                        self.update_flag = true;
                    }
                }
            },
            .utf8 => |char| {
                if (self.focused and (char[0] == 0x7f or char[0] == 0x08)) { // backspace
                    self.update_flag = true;
                    if (self.input_len == 0) return false;
                    self.input_len -= 1;
                    self.input_buffer[self.input_len] = ' ';
                }
                if (self.focused and char[0] == 'p') { // paste
                    self.update_flag = true;
                    if (self.input_len == 0) {
                        for (0..self.input_buffer.len) |i| {
                            self.input_buffer[i] = ' ';
                        }
                    }
                    const paste = cp.read_wayland_clipboard(self.allocator) catch return false;
                    for (self.input_len..self.input_buffer.len) |i| {
                        if (i > paste.len) break;
                        const current = [_]u8{ paste[i], 0, 0, 0 };
                        if (!self.validateConstraint(current)) return false;
                        self.input_buffer[i] = current[0];
                        self.input_len += 1;
                    }
                    self.update_flag = true;
                    if (self.input_len == self.input_buffer.len) {
                        self.focused = false;
                        self.stdout.print("\x1B[?25l", .{}) catch {};
                        return true;
                    }
                    self.allocator.free(paste);
                }
                if (self.focused and char[0] == '\n') {
                    self.focused = false;
                    self.stdout.print("\x1B[?25l", .{}) catch {};
                    self.update_flag = true;
                    return true;
                }
                if (!self.focused or !self.validateConstraint(char) or
                    self.input_len == self.input_buffer.len) return false;

                if (self.input_len == 0) {
                    for (0..self.input_buffer.len) |i| {
                        self.input_buffer[i] = ' ';
                    }
                }
                self.update_flag = true;
                // index 0 because we only accept ascii chars
                self.input_buffer[self.input_len] = char[0];
                self.input_len += 1;
            },
            else => return false,
        }
        return false;
    }

    pub fn render(self: *FixedSizeInput, offset: u.Vec2) !void {
        if (!self.update_flag) return;
        self.update_flag = false;
        try self.stdout.print("\x1b[{d};{d}H\x1b[K", .{ self.pos.y + offset.y, self.pos.x + offset.x });

        try self.stdout.print("{s}{s}\n", .{ self.title, self.input_buffer });
        try self.stdout.print("\x1b[{d};{d}H", .{ self.pos.y + offset.y, self.pos.x + offset.x + self.title.len + self.input_buffer.len - self.input_len });
    }

    pub fn renderCursor(self: FixedSizeInput, offset: u.Vec2) !void {
        if (!self.focused) return;
        self.stdout.print("\x1B[?25h", .{}) catch {};
        try self.stdout.print("\x1b[{d};{d}H", .{ self.pos.y + offset.y, self.pos.x + offset.x + self.title.len + self.input_len });
    }
};
