const std = @import("std");

pub fn read_wayland_clipboard(allocator: std.mem.Allocator) ![]u8 {
    var process = std.process.Child.init(&[_][]const u8{"wl-paste"}, allocator);
    process.stdout_behavior = .Pipe; // Capture stdout

    try process.spawn(); // Start the process

    const stdout = process.stdout.?;

    const output = try stdout.readToEndAlloc(allocator, 4096); // Read clipboard (max 4KB)
    _ = process.wait() catch {}; // Wait for process to exit (optional)

    return output; // Return clipboard content
}

pub fn write_wayland_clipboard(allocator: std.mem.Allocator, text: []const u8) !void {
    var process = std.process.Child.init(&[_][]const u8{"wl-copy"}, allocator);
    process.stdin_behavior = .Pipe; // Open stdin for writing

    try process.spawn(); // Start the wl-copy process

    const stdin = process.stdin.?;
    _ = try stdin.write(text); // Write to clipboard
    stdin.close(); // Close stdin (EOF)
}
