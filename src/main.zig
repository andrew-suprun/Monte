const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const c6 = @import("connect6.zig");

const tree = @import("tree.zig");

// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();

//     var search_tree = tree.SearchTree(c6.C6(Player, 19)).init();
//     defer search_tree.deinit(allocator);

//     try search_tree.expand(allocator);
// }

const Prng = std.rand.Random.DefaultPrng;

pub fn main() !void {
    var prng = Prng.init(0);

    const Game = c6.C6(19);
    var game = Game.init();
    var results: [3]u32 = .{ 0, 0, 0 };

    for (0..100_000) |_| {
        const result = game.rollout(.{ .x = @intCast(prng.next() % 9), .y = @intCast(prng.next() % 9) });
        // const result = game.rollout(.{ .x = 8, .y = 8 });
        // const result = game.rollout(.{ .x = 0, .y = 0 });
        switch (result) {
            .none => results[0] += 1,
            .first => results[1] += 1,
            .second => results[2] += 1,
        }
    }

    print("rollout results draw: {} first: {} second: {}\n", .{ results[0], results[1], results[2] });
}
