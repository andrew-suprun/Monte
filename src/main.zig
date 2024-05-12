const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Prng = std.rand.Random.DefaultPrng;

const tree = @import("tree.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const search_tree = tree.SearchTree(tree.TestGame).init(allocator);
    _ = search_tree;
}

var prng: Prng = Prng.init(0);

pub const TestGame = struct {
    allocator: Allocator,

    pub const Move = struct {
        score: f32,
    };

    pub const explore_factor: f32 = 2.0;

    pub fn init(allocator: Allocator) TestGame {
        print("TestGame.init\n", .{});
        return TestGame{
            .allocator = allocator,
        };
    }

    pub fn make_move(game: TestGame, move: TestGame.Move, turn: tree.Player) void {
        print("TestGame.make_move: move {any} turn {any}\n", .{ move, turn });
        _ = game;
    }

    pub fn rollout(game: TestGame) std.ArrayListUnmanaged(tree.SearchTree(TestGame).Node) {
        const moves = prng.next() % 5 + 1;
        const result = std.ArrayListUnmanaged(tree.SearchTree(TestGame).Node).initCapacity(game.allocator, moves) catch unreachable;
        // for (0..moves) |_| {
        //     result.append(game.allocator, prng.next() % 10);
        // }
        print("TestGame.rollout\n", .{});
        return result;
    }
};

test "SearchTree" {
    var search_tree = tree.SearchTree(TestGame).init(std.testing.allocator);
    defer search_tree.deinit();
    try search_tree.expand();
    try search_tree.expand();
    try search_tree.expand();
    print("done", .{});
}
