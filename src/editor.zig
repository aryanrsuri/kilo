const std = @import("std");
const os = std.os;

const reader = std.io.getStdIn().reader();
const writer = std.io.getStdOut().writer();
const stdin_fd = std.io.getStdIn().handle;

pub const Editor = struct {
    const Self = @This();
    termios: os.termios = undefined,
    exit: bool = false,
    mode: Mode = .Command,
    alloc: std.mem.Allocator,
    // Terminal Offset
    row_offset: usize,
    col_offset: usize,
    // Terminal Sizes
    rows: u16,
    cols: u16,
    // Cursor Position
    cx: i16,
    cy: i16,
    // Charset buffer
    buffer: std.ArrayList([]const u8),
    filepath: []const u8 = undefined,
    const Size = struct { rows: u16, cols: u16 };
    pub fn init(allocator: std.mem.Allocator) !Self {
        const size: Size = try get_size();
        const buffer: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(allocator);

        return .{
            .alloc = allocator,
            .rows = size.rows,
            .cols = size.cols,
            .cx = 0,
            .cy = 0,
            .row_offset = 0,
            .col_offset = 0,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *Self) void {
        try self.buffer.deinit();
        self.alloc.free(self.buffer);
        self.* = undefined;
    }

    pub fn get_size() !Size {
        var ws = std.mem.zeroes(os.system.winsize);
        // os.system.getErrno(r: usize)
        switch (std.os.system.getErrno(os.system.ioctl(stdin_fd, os.system.T.IOCGWINSZ, &ws))) {
            .SUCCESS => {
                return Size{ .rows = ws.ws_row, .cols = ws.ws_col };
            },
            else => return error.SizeNotFound,
        }
    }

    pub fn process(self: *Self) !void {
        const key: Key = try self.read();
        switch (key) {
            .char => {},
            .movement => |m| self.move_cursor(m),
            .delete => {},
        }
    }
    pub fn move_cursor(self: *Self, mov: Movement) void {
        std.debug.print("\n{any}\n ", .{mov});
        switch (mov) {
            .left => {
                if (self.cx != 0) {
                    self.cx -= 1;
                }
            },
            .right => {
                if (self.cx != self.cols - 1) {
                    self.cx += 1;
                }
            },
            .up => {
                if (self.cy != 0) {
                    self.cy -= 1;
                }
            },
            .down => {
                if (self.cy != (self.buffer.items.len - 1)) {
                    self.cy += 1;
                }
            },
            .ret => {},
            else => self.cx -= 1,
        }
    }

    pub fn scroll(self: *Self) void {
        if (self.cy < self.row_offset) {
            const CY: u16 = @bitCast(self.cy);
            self.row_offset = CY;
        }
        if (self.cy >= self.row_offset + self.rows) {
            const RW: i16 = @bitCast(self.rows);
            const IT: i16 = self.cy - RW + 1;
            const CY: u16 = @bitCast(IT);
            self.row_offset = CY;
        }
    }
    pub fn render_rows(self: *Self) !void {
        var i: usize = 0;
        while (i < self.rows) : (i += 1) {
            var file_row = i + self.row_offset;
            if (file_row >= self.buffer.items.len) {
                if (self.buffer.items.len == 0 and i == @divFloor(self.rows, 3)) {
                    const bytes: []const u8 = "Vi Editor written in Zig, in less than 1000 lines!";
                    var padding = (self.cols - bytes.len) / 2;
                    if (padding > 0) {
                        try writer.writeAll("~");
                        padding -= 1;
                    }
                    while (padding > 0) : (padding -= 1) {
                        try writer.writeAll(" ");
                    }
                    try writer.print("{s}", .{bytes});
                } else {
                    try writer.writeAll("~");
                }
            } else {
                const row = self.buffer.items[file_row];
                var len = row.len;
                if (len > self.cols) len = self.cols;
                try writer.print("{s}", .{row[0..len]});
            }
            try writer.writeAll("\x1B[K");
            if (i < self.rows - 1) {
                try writer.writeAll("\r\n");
            }
        }
        try writer.print(" {s}\t\t{s}\t\t{d}L\t", .{ @tagName(self.mode), self.filepath, self.buffer.items.len });
        // switch (self.mode) {
        //     Mode.command => |val| {
        //         try writer.writeAll(" {s}\t{s}\t{d}\t", .{ val, self.filepath, self.buffer.items.len });
        //     },
        //
        //     else => {},
        // }
    }
    pub fn refresh(self: *Self) !void {
        self.scroll();
        try writer.writeAll("\x1B[?25l");
        try writer.writeAll("\x1B[H");
        try self.render_rows();
        const RO: i16 = @intCast(self.row_offset);
        try writer.print("\x1b[{d};{d}H", .{ (self.cy - RO) + 1, self.cx + 1 });
        try writer.writeAll("\x1B[?25h");
    }

    pub fn open(self: *Self, filename: []const u8) !void {
        self.filepath = filename;
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        while (try file.reader().readUntilDelimiterOrEofAlloc(self.alloc, '\n', 1024 * 1024)) |line| {
            try self.buffer.append(line);
        }
    }

    pub fn read(self: *Self) !Key {
        const ch = try reader.readByte();

        switch (self.mode) {
            .Command, .Visual => {
                switch (ch) {
                    'j' => return .{ .movement = .down },
                    'k' => return .{ .movement = .up },
                    'h' => return .{ .movement = .left },
                    'l' => return .{ .movement = .right },
                    '\x0A', '\x0C', '\x0D' => return .{ .movement = .ret },
                    'i' => self.mode = .Insert,
                    'v' => self.mode = .Visual,
                    ':' => {
                        const nch = reader.readByte() catch return .{ .movement = .escape };
                        switch (nch) {
                            '\x71' => self.exit = true,
                            else => {},
                        }
                    },
                    else => {},
                }
            },
            .Insert => {
                switch (ch) {
                    '\x1b' => {
                        self.mode = .Command;
                        // const nch = reader.readByte() catch return .{ .movement = .escape };
                        // switch (nch) {
                        //     '\x71' => {
                        //         self.exit = true;
                        //     },
                        //     '\x5b' => {
                        //         const nnch = reader.readByte() catch return .{ .movement = .escape };
                        //         if (nnch == '\x33') {
                        //             const nnnch = reader.readByte() catch return .{ .movement = .escape };
                        //             if (nnnch == '\x7e') {
                        //                 return Key.delete;
                        //             }
                        //         }
                        //     },
                        //     else => {},
                        // }
                    },
                    '\x7F' => return Key.delete,
                    else => return .{ .char = ch },
                }
            },
        }
        return .{ .char = ch };
    }
    pub fn dump(self: *Self) !void {
        while (true) {
            try self.refresh();
            try self.process();
            if (self.exit == true) break;
        }
        // self.deinit();
        try writer.writeAll("\x1b[2J");
        try writer.writeAll("\x1b[H");
    }

    pub fn enable_raw_mode(self: *Self) !void {
        self.termios = try std.os.tcgetattr(stdin_fd);
        var raw = self.termios;
        raw.lflag &= ~@as(os.system.tcflag_t, os.system.ECHO | os.system.ICANON | os.system.IEXTEN | os.system.ISIG);
        raw.oflag &= ~@as(os.system.tcflag_t, os.system.OPOST);
        raw.iflag &= ~@as(os.system.tcflag_t, os.system.ICRNL | os.system.IXON);
        try std.os.tcsetattr(stdin_fd, .FLUSH, raw);
    }

    pub fn disable_raw_mode(self: *Self) void {
        std.os.tcsetattr(stdin_fd, .FLUSH, self.termios) catch @panic("disble raw failed");
    }
};

const Mode = enum { Command, Insert, Visual };

const Movement = enum(u16) {
    down = 1000,
    up = 1001,
    left = 1002,
    right = 1003,
    escape = 1004,
    ret = 1005,
};

const Key = union(enum) {
    char: u8,
    movement: Movement,
    delete: void,
};

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
