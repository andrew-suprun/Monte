const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum { second, none, first };

// const Game = @import("connect6.zig").C6(19); // ###
// const Game = @import("TicTacToe.zig"); // ###
const Game = @import("RandomGame.zig"); // ###
const Node = @import("node.zig").Node(Game);

// pub fn SearchTree(comptime Game: type) type { // ###
pub fn SearchTree() type {
    return struct {
        root: Node,
        allocator: Allocator,

        const Self = SearchTree();
        // const Self = SearchTree(Game); // ###

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .root = Node.init(undefined),
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
        }

        pub fn expand(self: *Self) void {
            var game = Game.init();
            self.root.expand(&game);
        }
    };
}

test SearchTree {
    var tree = SearchTree().init(std.testing.allocator);
    defer tree.deinit();
    tree.expand();
}
