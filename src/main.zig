pub const std = @import("std");
pub const editor = @import("editor.zig");
pub const Editor = editor.Editor;

pub fn main() !void {
    // std.debug.print("{s}\n", .{TITLE});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    var edit = try Editor.init(alloc);
    defer edit.deinit();
    if (args.len == 2) try edit.open(args[1]);
    try edit.dump();
    // try edit.repl();
}
