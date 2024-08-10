const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum(u8) {
    second,
    none,
    first,

    pub fn str(self: @This()) []const u8 {
        return switch (self) {
            .second => "O",
            .none => "-",
            .first => "X",
        };
    }
};

pub fn SearchTree(Game: type) type {
    return struct {
        root: Node,
        game: Game,
        allocator: Allocator,

        const Self = @This();
        const Node = @import("node_b.zig").Node(Game, Player);
        const Stats = @import("stats.zig").Stats(Player);

        pub fn init(allocator: Allocator) Self {
            return Self{
                .root = Node{ .move = std.mem.zeroInit(Game.Move, .{}) },
                .game = Game{},
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
            var expand_game = self.game;
            self.expandRecursive(&self.root, &expand_game);
        }

        pub fn expandRecursive(self: *Self, node: *Node, game: *Game) void {
            if (node.children.len > 0) {
                const child = if (node.children[0].move.player == .first)
                    node.selectChild(.first)
                else
                    node.selectChild(.second);

                game.makeMove(child.move);
                self.expandRecursive(child, game);
                node.updateStats();
                return;
            }

            var buf: [Game.maxMoves()]Game.Move = undefined;
            const moves = game.possibleMoves(&buf);

            node.children = self.allocator.alloc(Node, moves.len) catch unreachable;
            for (node.children, moves) |*child, move| {
                child.* = Node{ .move = move };
            }
        }

        pub fn bestMove(self: Self) Game.Move {
            return self.root.bestMove();
        }

        pub fn bestLine(self: Self, buf: []Game.Move) []Game.Move {
            var game = self.game;
            var node = self.root;
            for (0..buf.len) |i| {
                if (node.children.len == 0) {
                    return buf[0..i];
                }
                const move = Self.bestMove(node, game);
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

        pub fn commitMove(self: *Self, move: Game.Move) void {
            self.game.makeMove(move);
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

        pub fn debugSelfCheck(self: Self) void {
            self.root.debugSelfCheckRecursive(self.game);
        }

        pub fn debugPrint(self: Self) void {
            self.root.debugPrintRecursive(0);
        }

        pub fn debugPrintChildren(self: Self) void {
            print("\n", .{});
            self.root.debugPrint(0);
            for (self.root.children) |child| {
                print("\n  ", .{});
                child.debugPrint(1);
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
    tree.expand();
}
