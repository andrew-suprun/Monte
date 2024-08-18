allocator: std.mem.Allocator,
in: std.fs.File.Reader,
out: std.fs.File.Writer,
engine: Engine,

const std = @import("std");
const print = std.debug.print;
const Self = @This();
const tree = @import("tree.zig");
const c6 = @import("connect6.zig");
const Game = c6.C6(tree.Player, 19, 128);
const Move = c6.Move(tree.Player);
const Engine = tree.SearchTree(Game, Move);

pub fn init(allocator: std.mem.Allocator, in: std.fs.File.Reader, out: std.fs.File.Writer) Self {
    return .{
        .allocator = allocator,
        .in = in,
        .out = out,
        .engine = Engine.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.engine.deinit();
}

pub fn run(self: *Self) !void {
    while (true) {
        var line = std.ArrayList(u8).init(self.allocator);
        line.deinit();
        self.in.streamUntilDelimiter(line.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) {
                return;
            }
            unreachable;
        };
        try self.handleCommand(line.items);
    }
}

fn handleCommand(self: *Self, line: []u8) !void {
    var tokens = std.mem.tokenizeScalar(u8, line, ' ');
    if (tokens.next()) |command| {
        if (std.mem.eql(u8, command, "move")) self.handleMove(&tokens);
    }
}

fn handleMove(self: *Self, tokens: *std.mem.TokenIterator(u8, .scalar)) void {
    _ = self;
    _ = tokens;
    print("\nmove: ", .{});
    // var coords: [2][2]u8 = undefined;
    // for (0..2) |i| {
    //     if (tokens.next()) |token| {
    //         coords[i] = parsePlace(token) catch |_| {
    //             self.replyError("invalid move");
    //         };
    //     } else {
    //         self.replyError("invalid move");
    //         return;
    //     }
    // }
    // const move = self.engine.game.initMove(coords[0][0], coords[0][1], coords[1][0], coords[1][1]);
    // while (tokens.next()) |token| {
    //     print("\n   token {s}", .{token});
    // }
}
