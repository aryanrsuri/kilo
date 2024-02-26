const std = @import("std");
const os = std.os;

const reader = std.io.getStdIn().reader();
const writer = std.io.getStdOut().writer();
const stdin_fd = std.io.getStdIn().handle;

pub const BUFFER_MAX: comptime_int = 1048576;
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
    // buffer: std.ArrayList([1048576]u8),
    // buffer: std.ArrayList([]u8),
    // buffer: std.ArrayList(std.ArrayList(u8)),
    buffer: []u8,
    eof: usize = 0,
    lines: usize,
    filepath: []const u8 = "No name",
    curr_key: Key = Key.inv,

    pub fn init(allocator: std.mem.Allocator) !Self {
        const size: Size = try get_size();
        // const buffer: std.ArrayList([1048576]u8) = std.ArrayList([1048576]u8).init(allocator);
        // const buffer = std.ArrayList([]u8).init(allocator);
        // const buffer: std.ArrayList(strs) = std.ArrayList(lines.items).init(allocator);

        var editor: Editor = .{
            .alloc = allocator,
            .rows = size.rows - 1,
            .cols = size.cols,
            .cx = 0,
            .cy = 0,
            .row_offset = 0,
            .col_offset = 0,
            .lines = 0,
            .buffer = try allocator.alloc(u8, BUFFER_MAX),
        };

        editor.buffer[0] = 0;
        return editor;
    }

    pub fn deinit(self: *Self) void {
        try self.buffer.deinit();
        try self.bufferv2.deinit();
        self.* = undefined;
    }

    pub fn get_size() !Size {
        // var ws = std.mem.zeroes(os.system.winsize);
        var ws: os.system.winsize = undefined;
        switch (std.os.system.getErrno(os.system.ioctl(stdin_fd, os.system.T.IOCGWINSZ, @intFromPtr(&ws)))) {
            .SUCCESS => {
                return Size{ .rows = ws.ws_row, .cols = ws.ws_col };
            },
            else => return error.SizeNotFound,
        }
    }

    pub fn process(self: *Self) !void {
        const key: Key = try self.read();
        self.curr_key = key;
        switch (key) {
            .char => |c| try self.insert(c),
            .movement => |m| self.move_cursor(m),
            .delete => {},
            .inv => {},
        }
    }

    pub fn get_raw_x(self: *Self) u16 {
        const COLS: i16 = @bitCast(self.cols);
        const RAW: u16 = @bitCast((self.cx * COLS) + self.cy);
        return RAW;
    }

    pub fn insert(self: *Self, char: u8) !void {
        // TODO : use raw x function
        const COLS: i16 = @bitCast(self.cols);
        const RAW: u16 = @bitCast((self.cx * COLS) + self.cy);
        self.buffer[RAW] = char;
        self.eof += 1;
        self.cx += 1;
        if (char == '\n') {
            self.rows += 1;
            self.lines += 1;
            self.cx = 0;
        }
        //
        // try self.render_rows();
    }
    pub fn move_cursor(self: *Self, mov: Movement) void {
        // var CY: u16 = @bitCast(self.cy);
        // var curr = if (self.cy >= self.buffer.items.len) null else self.buffer.items[CY];
        switch (mov) {
            .left => {
                if (self.cx > 0) {
                    self.cx -= 1;
                    // } else if (self.cy > 0) {
                    // self.cy -= 1;
                    // CY = @bitCast(self.cy);
                    // const LEN: u16 = @truncate(self.buffer.items[CY].len);
                    // const CX: i16 = @bitCast(LEN);
                    // self.cx = CX;
                }
            },
            .right => {
                // if (curr) |c| {
                // if (self.cx < c.len) {
                self.cx += 1;
                // } else if (self.cx == c.len) {
                // self.cy += 1;
                // self.cx = 0;
                // }
                // }
            },
            .up => {
                if (self.cy > 0) self.cy -= 1;
            },
            .down => {
                self.cy += 1;
            },
            // .up_10 => {
            // if (self.cy > 0 and self.cy - 10 > 0) self.cy -= 10;
            // },
            // .down_10 => {
            // if (self.cy + 10 < self.buffer.items.len) self.cy += 10;
            // },
            .zero_cx => {
                if (self.cx > 0) self.cx = 0;
            },
            // .zero_cx_cy => {
            // if (self.cy < self.buffer.items.len) {
            // self.cx = 0;
            // self.cy = 0;
            // }
            // },
            .ret => {},
            else => self.cx -= 1,
        }

        // CY = @bitCast(self.cy);
        // curr = if (self.cy >= self.buffer.items.len) null else self.buffer.items[CY];
        // if (curr) |c| {
        //     if (self.cx > c.len) {
        //         const CL: u16 = @truncate(c.len);
        //         const CX: i16 = @bitCast(CL);
        //         self.cx = CX;
        //     }
        // }
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

    pub fn render_status(self: *Self) !void {
        try writer.writeAll("\x1b[K");
        var ch = switch (self.curr_key) {
            .char => self.curr_key.char,
            else => '.',
        };
        try writer.print("{s}\t\t\t{c}\t\t\t[{s}]\t\t\t{d}:{d}:{d}L", .{ @tagName(self.mode), ch, self.filepath, self.cy, self.cx, self.lines });
        try writer.writeAll("\x1b[m");
    }

    pub fn render_rows(self: *Self) !void {
        var i: usize = 0;
        // while (i < self.rows) : (i += 1) {
        //     var frow = i + self.row_offset;
        //     _ = frow;
        //
        //     try writer.writeAll("\x1B[K");
        //     try writer.writeAll("\r\n");
        // }
        while (i < self.rows) : (i += 1) {
            var file_row = i + self.row_offset;
            if (file_row >= self.lines) {
                try writer.writeAll("~");
            } else {
                try writer.writeAll("testing");
                // for (self.buffer) |ch| {
                //     if (ch != 170) {
                //         try writer.print("{c}", .{ch});
                //     }
                // }
            }
            try writer.writeAll("\x1B[K");
            try writer.writeAll("\r\n");
        }
        // var i: usize = 0;
        // while (i < self.rows) : (i += 1) {
        //     var file_row = i + self.row_offset;
        //     if (file_row >= self.lines) {
        //         if (self.buffer.len == 0 and i == @divFloor(self.rows, 3)) {
        //             const bytes: []const u8 = "Vi Editor written in Zig, in less than 1000 lines!";
        //             var padding = (self.cols - bytes.len) / 2;
        //             if (padding > 0) {
        //                 try writer.writeAll("~");
        //                 padding -= 1;
        //             }
        //             while (padding > 0) : (padding -= 1) {
        //                 try writer.writeAll(" ");
        //             }
        //             try writer.print("{s}", .{bytes});
        //         } else {
        //             try writer.writeAll("~");
        //         }
        //     } else {
        //         for (self.buffer) |ch| {
        //             if (ch != 170) {
        //                 try writer.writeByte(ch);
        //             }
        //         }
        //     }
        //     try writer.writeAll("\x1B[K");
        //     try writer.writeAll("\r\n");
        // }
    }
    pub fn refresh(self: *Self) !void {
        self.scroll();
        try writer.writeAll("\x1B[?25l");
        try writer.writeAll("\x1B[H");
        try self.render_rows();
        try self.render_status();
        const RO: i16 = @intCast(self.row_offset);
        const CO: i16 = @intCast(self.col_offset);
        try writer.print("\x1b[{d};{d}H", .{ (self.cy - RO) + 1, (self.cx - CO) + 1 });
        try writer.writeAll("\x1b[?25h");
    }

    pub fn open(self: *Self, filename: []const u8) !void {
        self.filepath = filename;
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        while (try file.reader().readUntilDelimiterOrEofAlloc(self.alloc, '\n', BUFFER_MAX)) |line| {
            for (line) |ch| {
                self.buffer[self.eof] = ch;
                self.eof += 1;
            }
            self.buffer[self.eof] = '\n';
            self.eof += 1;
            self.lines += 1;
        }
    }

    pub fn insert_char_at(self: *Self, pos: usize) !void {
        _ = pos;
        _ = self;
    }
    pub fn read(self: *Self) !Key {
        const ch = try reader.readByte();
        switch (self.mode) {
            .Command, .Visual => {
                switch (ch) {
                    'j' => return .{ .movement = .down },
                    '}' => return .{ .movement = .down_10 },
                    'k' => return .{ .movement = .up },
                    '{' => return .{ .movement = .up_10 },
                    'h' => return .{ .movement = .left },
                    'l' => return .{ .movement = .right },
                    '0' => return .{ .movement = .zero_cx },
                    'a', 'i' => self.mode = .Insert,
                    'v' => self.mode = .Visual,
                    'g' => {
                        const nch = reader.readByte() catch return .{ .movement = .escape };
                        switch (nch) {
                            'g' => return .{ .movement = .zero_cx_cy },
                            else => {},
                        }
                    },
                    '\x3a' => {
                        const nch = reader.readByte() catch return .{ .movement = .escape };
                        switch (nch) {
                            '\x71' => self.exit = true,
                            else => {},
                        }
                    },
                    // '\x0A', '\x0C', '\x0D' => return .{ .movement = .ret },
                    '\x1b' => self.mode = .Command,
                    else => {},
                }
            },
            .Insert => {
                switch (ch) {
                    '\x1b' => self.mode = .Command,
                    '\x7F' => return Key.delete,
                    else => return .{ .char = ch },
                }
            },
        }
        return Key.inv;
    }
    pub fn dump(self: *Self) !void {
        try self.enable_raw_mode();
        defer self.disable_raw_mode();

        while (true) {
            try self.refresh();
            try self.process();
            if (self.exit == true) break;
        }
        // self.deinit();
        try writer.writeAll("\x1b[2J");
        try writer.writeAll("\x1b[H");
    }

    pub fn repl(self: *Self) !void {
        // while (true) {
        for (self.buffer) |ch| {
            if (ch != 170) {
                try writer.writeByte(ch);
            }
        }
        // std.debug.print("{any}\n", .{try self.process()});
        // try self.process();
        // self.open(filename: []const u8)
        // if (self.exit == true) break;
        // }
    }

    pub fn enable_raw_mode(self: *Self) !void {
        self.termios = try std.os.tcgetattr(stdin_fd);
        var raw = self.termios;
        raw.lflag &= ~@as(os.system.tcflag_t, os.system.ECHO | os.system.ICANON | os.system.IEXTEN | os.system.ISIG);
        raw.oflag &= ~@as(os.system.tcflag_t, os.system.OPOST);
        raw.iflag &= ~@as(os.system.tcflag_t, os.system.ICRNL | os.system.IXON);
        raw.cflag |= os.system.CS8;
        // raw.cc[os.system.V.MIN] = 0;
        // raw.cc[os.system.V.TIME] = 1;
        try std.os.tcsetattr(stdin_fd, .FLUSH, raw);
    }

    pub fn disable_raw_mode(self: *Self) void {
        std.os.tcsetattr(stdin_fd, .FLUSH, self.termios) catch @panic("disble raw failed");
    }
};

const Size = struct { rows: u16, cols: u16 };
const Mode = enum { Command, Insert, Visual };
const Movement = enum {
    down,
    down_10,
    up,
    up_10,
    left,
    right,
    escape,
    ret,
    zero_cx,
    zero_cx_cy,
};

const Key = union(enum) {
    char: u8,
    movement: Movement,
    delete: void,
    inv: void,
};

pub const TITLE =
    \\                VERSION 0.0.1 \n
    \\      ___                       ___       ___     \n
    \\     /\  \          ___        /\__\     /\  \    \n
    \\     \:\  \        /\  \      /:/  /    /::\  \   \n
    \\      \:\  \       \:\  \    /:/  /    /:/\:\  \  \n
    \\       \:\  \      /::\__\  /:/  /    /:/  \:\  \ \n
    \\ _______\:\__\  __/:/\/__/ /:/__/    /:/__/ \:\__\\n
    \\ \::::::::/__/ /\/:/  /    \:\  \    \:\  \ /:/  /\n
    \\  \:\~~\~~     \::/__/      \:\  \    \:\  /:/  / \n
    \\   \:\  \       \:\__\       \:\  \    \:\/:/  /  \n
    \\    \:\__\       \/__/        \:\__\    \::/  /   \n
    \\     \/__/                     \/__/     \/__/    \n
;
