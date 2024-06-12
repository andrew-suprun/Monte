board: [3][3]Player,
turn: Player,
moves_played: u8,

const Self = @This();
const Player = @import("tree.zig").SearchTree(Self).Player;
const Allocator = std.mem.Allocator;

pub const explore_factor: f32 = 2;

pub const Move = struct { x: u8, y: u8 };

pub fn init() Self {
    return .{
        .board = [1][3]Player{[1]Player{.none} ** 3} ** 3,
        .turn = .first,
        .moves_played = 0,
    };
}

pub fn make_move(self: *Self, move: Move) void {
    self.board[move.y][move.x] = self.turn;
    self.turn = if (self.turn == .first) .second else .first;
    self.moves_played += 1;
}

fn outcome(self: Self, move: Move) ?Player {
    const x = move.x;
    const y = move.y;
    const turn: Player = if (self.turn == .first) .second else .first;
    if ((self.board[0][x] == turn and self.board[1][x] == turn and self.board[2][x] == turn) or
        (self.board[y][0] == turn and self.board[y][1] == turn and self.board[y][2] == turn) or
        (self.board[0][0] == turn and self.board[1][1] == turn and self.board[2][2] == turn) or
        (self.board[0][2] == turn and self.board[1][1] == turn and self.board[0][2] == turn)) return turn;

    if (self.moves_played == 8) return .none;
    return null;
}

pub fn possible_moves(self: Self, allocator: Allocator) []Move {
    var moves = std.ArrayList(Move).init(allocator);
    for (self.board, 0..) |row, y| {
        for (row, 0..) |place, x| {
            if (place == .none) {
                moves.append(Move{ .x = @intCast(x), .y = @intCast(y) }) catch unreachable;
            }
        }
    }
    return moves.toOwnedSlice();
}

pub fn select_random_move(self: Self, rng: anytype) Move {
    var move = Move{ .x = 0, .y = 0 };

    var prob: u64 = 1;
    for (self.board, 0..) |row, y| {
        for (row, 0..) |place, x| {
            if (place == .none) {
                const random = rng.next();
                if (random % prob == 0) {
                    move = Move{ .x = @intCast(x), .y = @intCast(y) };
                }
                prob += 1;
            }
        }
    }
    return move;
}

const std = @import("std");
const print = std.debug.print;
const Prng = std.rand.Random.DefaultPrng;

const Moves = struct {
    fn next(self: Moves, move: ?Move) void {
        _ = self;
        print("move {any}\n", .{move});
    }
};

test "TicTacToe" {
    var game = Self.init();

    const moves = [_]Move{
        .{ .x = 1, .y = 1 },
        .{ .x = 1, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 1 },
        .{ .x = 2, .y = 2 },
    };

    for (moves) |move| {
        game.make_move(move);
        const result = game.outcome(move);
        print("move {any} outcome {any}\n", .{ move, result });
    }

    game.possible_moves(Moves{});
}
