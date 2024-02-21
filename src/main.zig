pub const std = @import("std");
pub const ascii = std.ascii;
pub const fmt = std.fmt;
pub const io = std.io;
pub const heap = std.heap;
pub const mem = std.mem;
pub const os = std.os;
pub const editor = @import("editor.zig");
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
    std.debug.print("{s}\n", .{TITLE});
    while (true) {
        var edit: editor.Editor = .{};
        _ = try edit.dump();
        if (edit.exit) break;
    }
}
