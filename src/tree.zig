const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub fn SearchTree(Game: type) type {
    return struct {
        root: Node,
        acc: i32 = 0,
        allocator: Allocator,

        const Self = @This();
        const Node = @import("node.zig").Node(Game);

        pub fn init(allocator: Allocator) Self {
            return Self{
                .root = Node{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
        }

        pub fn expand(self: *Self, game: *Game) void {
            self.expandRecursive(game, &self.root, self.acc);
            if (debug) self.root.debugSelfCheckRecursive(game.*);
        }

        fn expandRecursive(self: *Self, game: *Game, node: *Node, acc: i32) void {
            defer node.updateStats();

            if (node.children.len > 0) {
                const child = if (node.move.player == .second)
                    node.selectChild(.first)
                else
                    node.selectChild(.second);

                game.makeMove(child.move);
                self.expandRecursive(game, child, acc + child.move.score);
                game.undoMove(child.move);
                return;
            }

            var buf: [Game.max_moves]Game.Move = undefined;
            const moves = game.possibleMoves(&buf);

            node.children = self.allocator.alloc(Node, moves.len) catch unreachable;
            for (node.children, moves) |*child, move| {
                child.* = Node{ .move = move };
                child.score = @divTrunc(move.score, 2) + acc;
                if (child.move.winner) |w| {
                    child.max_result = w;
                    child.min_result = w;
                }
            }
        }

        pub fn bestMove(self: Self) Game.Move {
            return self.root.bestMove();
        }

        pub fn bestLine(self: Self, game: Game, buf: []Game.Move) []Game.Move {
            var clone = game;
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
                        _ = clone.makeMove(node.move);
                        break;
                    }
                } else {
                    unreachable;
                }
            }
            return buf;
        }

        pub fn makeMove(self: *Self, move: Game.Move) void {
            self.acc += move.score;
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
                self.root = Node{ .move = move };
            }
        }

        pub fn debugSelfCheck(self: Self, game: Game) void {
            self.root.debugSelfCheckRecursive(game);
        }

        pub fn debugPrint(self: Self) void {
            self.root.debugPrintRecursive(0);
        }

        pub fn debugPrintChildren(self: Self) void {
            self.root.debugPrintChildren();
        }
    };
}
