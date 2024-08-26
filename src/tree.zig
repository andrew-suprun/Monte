const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub fn SearchTree(Game: type) type {
    const Move = Game.Move;

    return struct {
        root: Node,
        acc: i32 = Game.empty_board_score,
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

            if (node.child_moves.len > 0) {
                const child = if (node.child_moves[0].player == .first)
                    node.selectChild(.first)
                else
                    node.selectChild(.second);

                game.makeMove(child.move);
                self.expandRecursive(game, child.node, acc + child.move.score);
                game.undoMove(child.move);
                return;
            }

            node.child_moves = game.possibleMoves(self.allocator);

            node.child_nodes = self.allocator.alloc(Node, node.child_moves.len) catch unreachable;
            for (node.child_moves, node.child_nodes) |move, *child| {
                child.* = Node{};
                child.score = @divTrunc(move.score, 2) + acc;
                if (move.winner) |w| {
                    child.max_result = w;
                    child.min_result = w;
                }
            }
        }

        pub fn bestMove(self: Self) Move {
            return self.root.bestMove();
        }

        pub fn bestLine(self: Self, game: Game, buf: []Move) []Move {
            var clone = game;
            var node = self.root;
            for (0..buf.len) |i| {
                if (node.child_moves.len == 0) {
                    return buf[0..i];
                }
                const move = node.bestMove();
                for (node.child_moves, node.child_nodes) |child_move, child_node| {
                    if (child_move.eql(move)) {
                        buf[i] = move;
                        node = child_node;
                        _ = clone.makeMove(child_move);
                        break;
                    }
                } else {
                    unreachable;
                }
            }
            return buf;
        }

        pub fn makeMove(self: *Self, move: Move) void {
            self.acc += move.score;
            var new_root: ?Node = null;
            for (self.root.child_moves, self.root.child_nodes) |child_move, *child_node| {
                if (child_move.eql(move)) {
                    new_root = child_node.*;
                    child_node.child_moves = &[_]Move{};
                    child_node.child_nodes = &[_]Node{};
                    break;
                }
            }
            self.deinit();
            if (new_root) |root| {
                self.root = root;
            } else {
                self.root = Node{};
            }
        }

        pub fn debugSelfCheck(self: Self, game: Game) void {
            self.root.debugSelfCheckRecursive(game);
        }

        pub fn debugPrint(self: Self) void {
            self.root.debugPrint();
            for (self.root.child_moves, self.root.child_nodes) |child_move, child_node| {
                child_node.debugPrintRecursive(child_move, 0);
            }
        }

        pub fn debugPrintChildren(self: Self) void {
            self.root.debugPrintChildren();
        }
    };
}
