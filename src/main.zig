const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Game = @import("connect6.zig").C6(19);
// const Game = @import("RandomGame.zig");
// const Game = @import("TicTacToe.zig");

const tree = @import("tree.zig");

// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();

//     var search_tree = tree.SearchTree(c6.C6(19)).init();
//     defer search_tree.deinit(allocator);

//     try search_tree.expand(allocator);
// }

pub fn main() !void {
    const game = Game.init();
    var results: [3]u32 = .{ 0, 0, 0 };

    for (0..100_000) |_| {
        var game_clone = game;
        const result = game_clone.rollout();
        switch (result) {
            .none => results[0] += 1,
            .first => results[1] += 1,
            .second => results[2] += 1,
        }
    }

    print("rollout results draw: {} first: {} second: {}\n", .{ results[0], results[1], results[2] });
}
