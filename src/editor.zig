pub const std = @import("std");
pub const ascii = std.ascii;
pub const fmt = std.fmt;
// pub const io = std.io;
pub const heap = std.heap;
pub const mem = std.mem;
pub const os = std.os;
pub const reader = std.io.getStdIn().reader();
pub const writer = std.io.getStdOut().writer();
pub const Editor = struct {
    const c_terminos: std.c.termios = undefined;
    exit: bool = false,
    const Self = @This();
    pub fn process(self: *Self) !void {
        const key: Key = try self.read();
        std.debug.print("{any}\n", .{key});
        switch (key) {
            .char => |byte| switch (byte) {
                else => {},
            },
            .movement => {},
            .delete => {},
        }
    }

    pub fn read(self: *Self) !Key {
        const ch = try reader.readByte();
        switch (ch) {
            '\x1b' => {
                const nch = reader.readByte() catch return Key{ .movement = .escape };
                switch (nch) {
                    'j' => return Key{ .movement = .down },
                    'k' => return Key{ .movement = .up },
                    'h' => return Key{ .movement = .left },
                    'l' => return Key{ .movement = .right },
                    'q' => {
                        self.exit = true;
                    },
                    '[' => {
                        const nnch = reader.readByte() catch return Key{ .movement = .escape };
                        if (nnch == '3') {
                            const nnnch = reader.readByte() catch return Key{ .movement = .escape };
                            if (nnnch == '~') {
                                return Key.delete;
                            }
                        }
                    },
                    else => {},
                }
            },
            '\x0A', '\x0C', '\x0D' => return Key{ .movement = .ret },
            // '\x7F' => return Key.delete,
            else => {
                // std.debug.print("ASCII {c}->{d}\n", .{ ch, ch });
            },
        }

        return .{ .char = ch };
    }
    pub fn dump(self: *Self) !void {
        _ = try self.process();
    }
};

pub const Movement = enum {
    down,
    up,
    left,
    right,
    escape,
    ret,
};

pub const Key = union(enum) {
    char: u8,
    movement: Movement,
    delete: void,
};

pub fn next_byte() !u8 {
    return reader.readByte();
}
// 10 is return
// 27 is ESC
//
