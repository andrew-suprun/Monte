const std = @import("std");
const Allocator = std.mem.Allocator;
const Prng = std.rand.Random.DefaultPrng;
const print = std.debug.print;

const node = @import("node.zig");
pub const Player = node.Player;

pub fn SearchTree(comptime Game: type) type {
    const Node = node.Node(Game);
    return struct {
        root: Node,
        game: Game,
        allocator: Allocator,

        const Self = SearchTree(Game);

        pub fn init(allocator: Allocator) Self {
            return Self{
                .root = Node{},
                .game = Game.init(),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.root.children) |*child| {
                child.deinit(self.allocator);
            }
            self.allocator.free(self.root.children);
        }

        pub fn expand(self: *Self) ?Player {
            var new_game = self.game;
            return self.root.expand(&new_game, self.allocator);
        }

        pub fn bestMove(self: Self, comptime player: Player) Game.Move {
            return self.root.bestMove(player);
        }

        pub inline fn nextPlayer(self: Self) Player {
            return self.game.nextPlayer();
        }

        pub fn randomMove(self: Self) ?Game.Move {
            return self.game.randomMove();
        }

        pub fn printBoard(self: *Self, move: Game.Move) void {
            self.game.printBoard(move);
        }

        pub fn commitMove(self: *Self, move: Game.Move) void {
            _ = self.game.makeMove(move);
            var new_root: ?Node = null;
            for (self.root.children) |*child| {
                if (child.move.eql(move)) {
                    new_root = child.*;
                    child.children = &[_]Node{};
                    break;
                }
            }
            self.deinit();
            if (new_root) |root| {
                self.root = root;
            } else {
                self.root = Node{};
                self.root.move = move;
            }
        }
    };
}

test SearchTree {
    const Game = struct {
        pub const Move = void;
    };
    const game = Game{};
    var tree = SearchTree(Game).init(game, std.testing.allocator);
    defer tree.deinit();
    _ = tree.expand();
}
