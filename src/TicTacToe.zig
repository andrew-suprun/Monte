board: [3][3]Player,
turn: Player,
moves_played: u8,

const std = @import("std");
const print = std.debug.print;
const Prng = std.rand.Random.DefaultPrng;

const Self = @This();
const Player = @import("tree.zig").Player;

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

pub fn clone(self: Self) Self {
    return self;
}

pub fn make_move(self: *Self, move: Move) ?Player {
    self.board[move.y][move.x] = self.turn;
    self.turn = if (self.turn == .first) .second else .first;
    self.moves_played += 1;
    return self.outcome(move);
}

fn outcome(self: Self, move: Move) ?Player {
    if (self.moves_played == 9) return .none;
    const x = move.x;
    const y = move.y;
    const turn = self.previous_player();
    if ((self.board[0][x] == turn and self.board[1][x] == turn and self.board[2][x] == turn) or
        (self.board[y][0] == turn and self.board[y][1] == turn and self.board[y][2] == turn) or
        (self.board[0][0] == turn and self.board[1][1] == turn and self.board[2][2] == turn) or
        (self.board[0][2] == turn and self.board[1][1] == turn and self.board[0][2] == turn)) return turn;

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
    return moves.toOwnedSlice() catch unreachable;
}

pub fn rollout(self: *Self) Player {
    var rand = Prng.init(@intCast(std.time.milliTimestamp()));

    while (true) {
        if (self.make_move(self.select_random_move(&rand))) |winner| {
            return winner;
        }
    }
}

pub inline fn next_player(self: Self) Player {
    return if (self.moves_played % 2 == 1) .first else .second;
}

pub inline fn previous_player(self: Self) Player {
    return if (self.moves_played % 2 == 0) .first else .second;
}

fn select_random_move(self: Self, rng: anytype) Move {
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

fn print_board(self: Self) void {
    for (0..3) |y| {
        for (0..3) |x| {
            switch (self.board[y][x]) {
                .none => print(" .", .{}),
                .first => print(" X", .{}),
                .second => print(" O", .{}),
            }
        }
        print("\n", .{});
    }
    print("------\n", .{});
}

test "TicTacToe" {
    var game = Self.init();
    const result = game.rollout(Move{ .x = 1, .y = 1 });
    print("result {any}\n", .{result});
}
