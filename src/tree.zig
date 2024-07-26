const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const node = @import("node.zig");
pub const Player = node.Player;

pub fn SearchTree(comptime Game: type) type {
    const Node = node.Node(Game);
    return struct {
        root: Node,
        game: Game,
        allocator: Allocator,

        const Self = SearchTree(Game); // ###

        pub fn init(game: Game, allocator: Allocator) Self {
            return Self{
                .game = game,
                .root = Node.init(undefined),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
        }

        pub fn expand(self: *Self) ?Player {
            print("\n\n=== EXPAND ROOT ===\n", .{});
            var new_game = self.game;
            return self.root.expand(&new_game, self.allocator);
        }
    };
}

test SearchTree {
    var tree = SearchTree().init(std.testing.allocator);
    defer tree.deinit();
    tree.expand();
}
