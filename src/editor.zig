const std = @import("std");
const os = std.os;

const reader = std.io.getStdIn().reader();
const writer = std.io.getStdOut().writer();
const stdin_fd = std.io.getStdIn().handle;

pub const Editor = struct {
    const Self = @This();

    termios: os.termios = undefined,
    exit: bool = false,
    mode: Mode = .COM,
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
    filepath: []const u8 = "Not named",

    pub fn init(allocator: std.mem.Allocator) !Self {
        const size: Size = try get_size();
        const buffer: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(allocator);

        return .{
            .alloc = allocator,
            .rows = size.rows - 1,
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
        var CY: u16 = @bitCast(self.cy);
        var curr = if (self.cy >= self.buffer.items.len) null else self.buffer.items[CY];
        switch (mov) {
            .left => {
                if (self.cx > 0) {
                    self.cx -= 1;
                } else if (self.cy > 0) {
                    self.cy -= 1;
                    CY = @bitCast(self.cy);
                    const LEN: u16 = @truncate(self.buffer.items[CY].len);
                    const CX: i16 = @bitCast(LEN);
                    self.cx = CX - 1;
                }
            },
            .right => {
                if (curr) |c| {
                    if (self.cx + 1 < c.len) {
                        self.cx += 1;
                    } else if (self.cx + 1 == c.len) {
                        self.cy += 1;
                        self.cx = 0;
                    }
                }
            },
            .up => {
                if (self.cy > 0) self.cy -= 1;
            },
            .down => {
                if (self.cy < self.buffer.items.len) self.cy += 1;
            },
            .up_10 => {
                if (self.cy > 0 and self.cy - 10 > 0) self.cy -= 10;
            },
            .down_10 => {
                if (self.cy + 10 < self.buffer.items.len) self.cy += 10;
            },
            .zero_cx => {
                if (self.cx > 0) self.cx = 0;
            },
            .zero_cx_cy => {
                if (self.cy < self.buffer.items.len) {
                    self.cx = 0;
                    self.cy = 0;
                }
            },
            .ret => {},
            else => self.cx -= 1,
        }

        CY = @bitCast(self.cy);
        curr = if (self.cy >= self.buffer.items.len) null else self.buffer.items[CY];
        if (curr) |c| {
            if (self.cx > c.len) {
                const CL: u16 = @truncate(c.len);
                const CX: i16 = @bitCast(CL);
                self.cx = CX - 1;
            }
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

    pub fn render_status(self: *Self) !void {
        try writer.print("{s}\t\t{s}\t\t{d}:{d}\t", .{ @tagName(self.mode), self.filepath, self.cy + 1, self.cx + 1 });
        try writer.writeAll("\x1b[m");
    }

    pub fn render_rows(self: *Self) !void {
        var i: usize = 0;
        while (i < self.rows) : (i += 1) {
            var file_row = i + self.row_offset;
            if (file_row >= self.buffer.items.len) {
                if (self.buffer.items.len == 0 and i == @divFloor(self.rows, 3)) {
                    // 12
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
                try writer.writeAll(row[0..len]);
            }
            try writer.writeAll("\x1B[K");
            try writer.writeAll("\r\n");
        }
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
        while (try file.reader().readUntilDelimiterOrEofAlloc(self.alloc, '\n', 1024 * 1024)) |line| {
            try self.buffer.append(line);
        }
    }

    pub fn read(self: *Self) !Key {
        const ch = try reader.readByte();

        switch (self.mode) {
            .COM, .VIS => {
                switch (ch) {
                    // TODO : add line skips to movement for command { etc...
                    'j' => return .{ .movement = .down },
                    '}' => return .{ .movement = .down_10 },
                    'k' => return .{ .movement = .up },
                    '{' => return .{ .movement = .up_10 },
                    'h' => return .{ .movement = .left },
                    'l' => return .{ .movement = .right },
                    '0' => return .{ .movement = .zero_cx },
                    'a', 'i' => self.mode = .INS,
                    'v' => self.mode = .VIS,
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
                    '\x0A', '\x0C', '\x0D' => return .{ .movement = .ret },
                    else => {},
                }
            },
            .INS => {
                switch (ch) {
                    '\x1b' => {
                        self.mode = .COM;
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
        while (true) {
            std.debug.print("{any}\n", .{try self.process()});
            // try self.process();
            if (self.exit == true) break;
        }
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

const Size = struct { rows: u16, cols: u16 };
const Mode = enum { COM, INS, VIS };
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
