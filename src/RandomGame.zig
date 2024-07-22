moves_played: usize = 0,

const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Prng = std.rand.Random.DefaultPrng;
var rng: Prng = Prng.init(4);
var move_id: usize = 0;

const Self = @This();
const Player = @import("node.zig").Player;
pub const max_moves: usize = 5;
pub const explore_factor: f32 = 2;

pub const Move = usize;

pub fn init() Self {
    return Self{};
}

pub fn clone(self: Self) Self {
    return self;
}

pub fn possibleMoves(_: *Self, buf: []Move) []Move {
    const n_moves = rng.next() % max_moves + 1;
    for (0..n_moves) |i| {
        move_id += 1;
        buf[i] = move_id;
    }
    return buf[0..n_moves];
}

pub fn makeMove(self: *Self, _: Move) ?Player {
    self.moves_played += 1;
    const result: ?Player = switch (rng.next() % 10) {
        0 => .none,
        1 => .first,
        2 => .second,
        else => null,
    };
    // print("\n    RandomGame: makeMove result {any}", .{result});
    return result;
}

pub fn rollout(_: *Self) Player {
    const result: Player = switch (rng.next() % 3) {
        1 => .first,
        2 => .second,
        else => .none,
    };
    // print("\n    RandomGame: makeMove rollout {any}", .{result});
    return result;
}

pub inline fn nextPlayer(self: Self) Player {
    return if (self.moves_played % 2 == 0) .first else .second;
}
