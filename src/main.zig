const std = @import("std");
const term = @import("term.zig");
const ui = @import("ui.zig");

pub fn main() !void {
    // Faster GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .stack_trace_frames = 0,
        .enable_memory_limit = false,
        .safety = false,
        .never_unmap = false,
        .retain_metadata = false,
        .verbose_log = false,
    }){};
    _ = gpa.allocator();

    var ctx = try term.TermContext.init();
    defer ctx.deinit();

    // var tui = try ui.Ui.init(&ctx);
    // try tui.run();
}
