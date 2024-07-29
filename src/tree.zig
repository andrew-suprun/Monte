const std = @import("std");
const Allocator = std.mem.Allocator;
const Prng = std.rand.Random.DefaultPrng;
const print = std.debug.print;

pub const Player = @import("node.zig").Player;

pub fn SearchTree(comptime Game: type, comptime explore_factor: f32) type {
    const Node = @import("node.zig").Node(Game, explore_factor);
    return struct {
        root: Node,
        game: Game,
        allocator: Allocator,

        const Self = SearchTree(Game, explore_factor);

        pub fn init(allocator: Allocator) Self {
            return Self{
                .root = Node{ .move = std.mem.zeroInit(Game.Move, .{}) },
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

        pub fn expand(self: *Self) void {
            var new_game = self.game;
            self.root.expand(&new_game, self.allocator);
        }

        pub fn bestMove(self: Self) Game.Move {
            return self.root.bestMove(self.game);
        }

        pub fn bestLine(self: Self, buf: []Game.Move) []Game.Move {
            var game = self.game;
            var node = self.root;
            for (0..buf.len) |i| {
                if (node.children.len == 0) {
                    return buf[0..i];
                }
                const move = node.bestMove();
                for (node.children) |child| {
                    if (child.move.eql(move)) {
                        buf[i] = move;
                        node = child;
                        _ = game.makeMove(node.move);
                        // game.printBoard(node.move);
                        break;
                    }
                } else {
                    unreachable;
                }
            }
            return buf;
        }

        pub fn debugPrint(self: Self, comptime prefix: []const u8) void {
            self.root.debugPrint(prefix);
        }

        pub fn randomMove(self: Self) ?Game.Move {
            return self.game.randomMove();
        }

        pub fn printBoard(self: *Self, move: Game.Move) void {
            self.game.printBoard(move);
        }

        pub fn commitMove(self: *Self, move: Game.Move) ?Player {
            if (self.game.makeMove(move)) |winner| return winner;
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
            return null;
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
    tree.expand();
}
