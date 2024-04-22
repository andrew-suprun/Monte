const std = @import("std");
const Allocator = std.mem.Allocator;
const math = std.math;
const expect = std.testing.expect;
const print = std.debug.print;

pub fn main() !void {
    std.log.debug("DEBUG", .{});
    const c6 = std.log.scoped(.c6);
    c6.debug("C6", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    _ = allocator;
}

const Move = struct { x1: u8, y1: u8, x2: u8, y2: u8 };

const Node = struct {};

const BoardSize = 19;

const place_first = 1;
const place_second = 6;

const Board = struct {
    places: [BoardSize][BoardSize]u8 = ([1][BoardSize]u8){[_]u8{0} ** BoardSize} ** BoardSize,

    fn init() Board {
        var board = Board{};
        board.places[BoardSize / 2][BoardSize / 2] = place_second;
        return board;
    }
};

const Player = enum { first, second, none };

// pub fn rollout(allocator: Allocator, moves: []const Move, move: Move) std.AutoHashMap(Move, Node) {
pub fn rollout(moves: []const Move, move: Move, nodes: std.AutoHashMap(Move, Node)) void {
    var board = Board.init();
    var player: u8 = place_first;

    for (moves) |m| {
        board.places[m.y1][m.x1] = player;
        board.places[m.y2][m.x2] = player;
        player = place_first + place_second - player;
    }
    board.places[move.y1][move.x1] = player;
    board.places[move.y2][move.x2] = player;

    board.places[1][1] = place_first;
    print("{}\n", .{board.places[1][1]});
    print("{}\n", .{board.places[9][9]});
    print("{}\n", .{@sizeOf(Board)});

    _ = .{ moves, move, board, nodes };
}

test Board {
    var moves = std.ArrayList(Move).init(std.testing.allocator);
    try moves.append(.{ .x1 = 10, .y1 = 9, .x2 = 9, .y2 = 10 });
    defer moves.deinit();

    const nodes = std.AutoHashMap(Move, Node).init(std.testing.allocator);
    _ = rollout(moves.items, .{ .x1 = 8, .y1 = 9, .x2 = 9, .y2 = 8 }, nodes);
}

pub const std_options = std.Options{
    .log_level = .info,
    .log_scope_levels = ([_]std.log.ScopeLevel{
        .{ .scope = .c6, .level = .debug },
    })[0..],
};
