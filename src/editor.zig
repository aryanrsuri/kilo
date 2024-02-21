const std = @import("std");
const os = std.os;

const reader = std.io.getStdIn().reader();
const writer = std.io.getStdOut().writer();
const stdin_fd = std.io.getStdIn().handle;

pub const Editor = struct {
    const Self = @This();
    c_termios: os.termios = undefined,
    exit: bool = false,
    alloc: std.mem.Allocator,
    rows: usize,
    cols: usize,
    rbuffer: std.ArrayList([]u8),

    const Size = struct { rows: u16, cols: u16 };
    pub fn init(allocator: std.mem.Allocator) !Self {
        const size: Size = try get_size();
        const rbuffer: std.ArrayList([]u8) = std.ArrayList([]u8).init(allocator);

        return .{
            .alloc = allocator,
            .rows = size.rows,
            .cols = size.cols,
            .rbuffer = rbuffer,
        };
    }

    pub fn get_size() !Size {
        var ws = std.mem.zeroes(os.system.winsize);
        // os.system.getErrno(r: usize)
        switch (std.os.system.getErrno(os.system.ioctl(stdin_fd, os.system.T.IOCGWINSZ, &ws))) {
            .SUCCESS => {
                return Size{ .rows = ws.ws_col, .cols = ws.ws_row };
                // return Size{ .rows = ws.ws_rows, .cols = ws.ws_cols };
            },
            else => return error.SizeNotFound,
        }
    }

    pub fn process(self: *Self) !void {
        const key: Key = try self.read();
        // std.debug.print("{any}\n", .{key});
        // std.debug.print("{c}", .{key.char});
        switch (key) {
            .char => {
                // try writer.print("{c}", .{key.char});
                switch (key.char) {
                    else => {},
                }
            },
            .movement => {},
            .delete => {},
        }
    }

    pub fn render_rows(self: *Self) !void {
        var i: usize = 0;
        while (i < self.row) : (i += 1) {
            try writer.writeAll("~\r\n");
        }
    }
    pub fn refresh(self: *Self) !void {
        try writer.writeAll("\x1B[2J");
        try writer.writeAll("\x1B[H");
        try self.renderRows();

        try writer.writeAll("\x1B[H");
    }
    pub fn read(self: *Self) !Key {
        const ch = try reader.readByte();
        switch (ch) {
            '\x1b' => {
                const nch = reader.readByte() catch return .{ .movement = .escape };
                switch (nch) {
                    '\x6a' => return .{ .movement = .down },
                    '\x6b' => return .{ .movement = .up },
                    '\x68' => return .{ .movement = .left },
                    '\x6c' => return .{ .movement = .right },
                    '\x71' => {
                        self.exit = true;
                    },
                    '\x5b' => {
                        const nnch = reader.readByte() catch return .{ .movement = .escape };
                        if (nnch == '\x33') {
                            const nnnch = reader.readByte() catch return .{ .movement = .escape };
                            if (nnnch == '\x7e') {
                                return Key.delete;
                            }
                        }
                    },
                    else => {},
                }
            },
            '\x0A', '\x0C', '\x0D' => return .{ .movement = .ret },
            '\x7F' => return Key.delete,
            else => {},
        }
        return .{ .char = ch };
    }
    pub fn dump(self: *Self) !void {
        _ = try self.enable_raw_mode();
        // _ = try self.refresh();
        _ = try self.process();
    }

    pub fn enable_raw_mode(self: *Self) !void {
        self.c_termios = try std.os.tcgetattr(stdin_fd);
        var raw = self.c_termios;
        raw.lflag &= ~@as(os.system.tcflag_t, os.system.ECHO | os.system.ICANON | os.system.IEXTEN | os.system.ISIG);
        raw.oflag &= ~@as(os.system.tcflag_t, os.system.OPOST);
        raw.iflag &= ~@as(os.system.tcflag_t, os.system.ICRNL | os.system.IXON);
        // raw.cc[VMIN] = 0;
        // raw.cc[VMIN] = 0;
        try std.os.tcsetattr(stdin_fd, .FLUSH, raw);
    }

    pub fn disable_raw_mode(self: *Self) !void {
        try std.os.tcsetattr(stdin_fd, .FLUSH, self.c_termios);
    }
};

const Movement = enum {
    down,
    up,
    left,
    right,
    escape,
    ret,
};

const Key = union(enum) {
    char: u8,
    movement: Movement,
    delete: void,
};
