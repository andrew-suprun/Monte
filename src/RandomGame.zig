moves_played: usize = 0,
rng: Prng,

const std = @import("std");
const Allocator = std.mem.Allocator;
const Prng = std.rand.Random.DefaultPrng;

const Self = @This();
const Player = @import("tree.zig").Player;

pub const Move = isize;

pub fn init() Self {
    return Self{ .rng = Prng.init(0) };
}

pub fn clone(self: Self) Self {
    return self;
}

pub fn possible_moves(self: Self, allocator: Allocator) []Move {
    const n_moves = self.rng.next() % 5 + 1;
    var result = allocator.alloc(Move, n_moves);
    for (0..n_moves) |i| {
        result[i] = i;
    }
    return result;
}

pub fn make_move(self: *Self, _: Move) ?Player {
    switch (self.rng.next() % 10) {
        0 => return .none,
        1 => return .first,
        2 => return .second,
    }
    return null;
}

pub fn rollout(self: *Self) Player {
    switch (self.rng.next() % 3) {
        1 => return .first,
        2 => return .second,
        else => return .none,
    }
}

pub inline fn next_player(self: Self) Player {
    return if (self.moves_played % 2 == 1) .first else .second;
}

pub inline fn previous_player(self: Self) Player {
    return if (self.moves_played % 2 == 0) .first else .second;
}
