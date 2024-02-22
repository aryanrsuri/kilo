pub const std = @import("std");
pub const ascii = std.ascii;
pub const fmt = std.fmt;
pub const io = std.io;
pub const heap = std.heap;
pub const mem = std.mem;
pub const os = std.os;
pub const editor = @import("editor.zig");
pub const Editor = editor.Editor;
pub const TITLE =
    \\                VERSION 0.0.1 
    \\      ___                       ___       ___     
    \\     /\  \          ___        /\__\     /\  \    
    \\     \:\  \        /\  \      /:/  /    /::\  \   
    \\      \:\  \       \:\  \    /:/  /    /:/\:\  \  
    \\       \:\  \      /::\__\  /:/  /    /:/  \:\  \ 
    \\ _______\:\__\  __/:/\/__/ /:/__/    /:/__/ \:\__\
    \\ \::::::::/__/ /\/:/  /    \:\  \    \:\  \ /:/  /
    \\  \:\~~\~~     \::/__/      \:\  \    \:\  /:/  / 
    \\   \:\  \       \:\__\       \:\  \    \:\/:/  /  
    \\    \:\__\       \/__/        \:\__\    \::/  /   
    \\     \/__/                     \/__/     \/__/    
;
pub fn main() !void {
    // std.debug.print("{s}\n", .{TITLE});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    var edit = try Editor.init(alloc);
    if (args.len == 2) try edit.open(args[1]);
    try edit.dump();
    // try edit.repl();
    // edit.deinit();
}
