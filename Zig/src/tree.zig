const std = @import("std");
const Allocator = std.mem.Allocator;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;
const Prng = std.rand.Random.DefaultPrng;

pub fn SearchTree(Game: type) type {
    const Move = Game.Move;

    return struct {
        root: Node,
        acc: i32 = 0,
        allocator: Allocator,
        rng: Prng,

        const Self = @This();
        const Node = @import("node.zig").Node(Game);

        pub fn init(allocator: Allocator) Self {
            return Self{
                .root = Node{ .player = .second, .move = undefined },
                .allocator = allocator,
                .rng = Prng.init(@intCast(std.time.microTimestamp())),
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
                const child = if (node.player == .second)
                    node.selectChild(.first)
                else
                    node.selectChild(.second);

                game.makeMove(child.move);
                self.expandRecursive(game, child, acc + child.move.score);
                game.undoMove(child.move);
                return;
            }

            const next_player = node.player.next();
            var buf: [Game.max_moves]Move = undefined;
            const child_moves = game.possibleMoves(&buf);
            node.children = self.allocator.alloc(Node, child_moves.len) catch unreachable;
            for (node.children, child_moves) |*child, move| {
                child.* = Node{ .player = next_player, .move = move };
                child.conclusive = move.terminal;
                if (move.terminal) {
                    child.score = move.score;
                } else {
                    child.score = @divTrunc(move.score, 2) + acc;
                }
            }
        }

        pub fn bestNode(self: *Self) Node {
            return self.root.bestNode(&self.rng);
        }

        pub fn bestLine(self: Self, game: Game, buf: []Move) []Move {
            var clone = game;
            var node = self.root;
            for (0..buf.len) |i| {
                if (node.child_moves.len == 0) {
                    return buf[0..i];
                }
                const move = node.bestMove();
                for (node.children) |child| {
                    if (child.move.eql(move)) {
                        buf[i] = move;
                        node = child;
                        _ = clone.makeMove(child.move);
                        break;
                    }
                } else {
                    unreachable;
                }
            }
            return buf;
        }

        pub fn makeMove(self: *Self, game: *Game, move: Move) void {
            game.makeMove(move);
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
                self.root = Node{ .player = self.root.player.next(), .move = undefined };
                self.acc = game.scoreBoard();
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
