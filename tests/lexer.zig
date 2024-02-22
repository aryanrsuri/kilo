const std = @import("std");
const fmt = std.fmt;
const ascii = std.ascii;
const token = @import("token.zig");

pub const Lexer = struct {
    buffer: []const u8,
    curr: usize = 0,
    peek: usize = 0,
    char: u8 = 0,

    const self = @This();
    pub fn init(input: []const u8) self {
        var lexer = Lexer{ .buffer = input };
        lexer.read();
        return lexer;
    }

    pub fn read(lexer: *self) void {
        if (lexer.peek >= lexer.buffer.len) {
            lexer.char = 0;
        } else {
            lexer.char = lexer.buffer[lexer.peek];
        }

        lexer.curr = lexer.peek;
        lexer.peek = lexer.peek + 1;
    }

    pub fn pk(lexer: *self) u8 {
        if (lexer.peek >= lexer.buffer.len) {
            return 0;
        } else {
            return lexer.buffer[lexer.peek];
        }
    }

    pub fn integer(lexer: *self) []const u8 {
        var pos: usize = lexer.curr;
        while (ascii.isDigit(lexer.char)) {
            lexer.read();
        }

        return lexer.buffer[pos..lexer.curr];
    }
    pub fn identifier(lexer: *self) []const u8 {
        var pos: usize = lexer.curr;
        while (ascii.isAlphabetic(lexer.char)) {
            lexer.read();
        }

        return lexer.buffer[pos..lexer.curr];
    }

	
    pub fn advance(lexer: *self) token.Token {
        var _token: token.Token = .{ .kind = .illegal, .literal = "" };
        while (ascii.isWhitespace(lexer.char)) {
            lexer.read();
        }
        switch (lexer.char) {
            '=' => {
                if (lexer.pk() == '=') {
                    lexer.read();
                    _token.literal = "==";
                    _token.kind = .equal;
                } else {
                    _token.kind = .assign;
                }
            },
            '!' => {
                if (lexer.pk() == '=') {
                    lexer.read();
                    _token.literal = "!=";
                    _token.kind = .not_equal;
                } else {
                    _token.kind = .bang;
                }
            },
            ';' => _token.kind = .semicolon,
            '(' => _token.kind = .lparen,
            ')' => _token.kind = .rparen,
            ',' => _token.kind = .comma,
            '+' => _token.kind = .plus,
            '-' => _token.kind = .minus,
            '/' => _token.kind = .slash,
            '*' => _token.kind = .asterisk,
            '<' => _token.kind = .ltag,
            '>' => _token.kind = .rtag,
            '{' => _token.kind = .lbrace,
            '}' => _token.kind = .rbrace,
            'a'...'z', 'A'...'Z', '_' => {
                _token.literal = lexer.identifier();
                _token.kind = token.Token.keywords.get(_token.literal) orelse .ident;
            },
            '0'...'9' => {
                _token.literal = lexer.integer();
                _token.kind = .int;
            },
            0 => _token.kind = .eof,
            else => _token.kind = .illegal,
        }

        lexer.read();
        return _token;
    }
};
