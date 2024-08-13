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
        acc: i32 = 0,
        allocator: Allocator,

        const Self = @This();
        const Node = @import("node.zig").Node(Game, Player);

        pub fn init(allocator: Allocator) Self {
            return Self{
                .root = Node{ .move = undefined },
                .game = Game{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.root.children) |*child| {
                child.deinit(self.allocator);
            }
        }

        pub fn expand(self: *Self) void {
            var expand_game = self.game;
            self.expandRecursive(&self.root, &expand_game, self.acc);
        }

        pub fn expandRecursive(self: *Self, node: *Node, game: *Game, acc: i32) void {
            defer node.updateStats();

            if (node.children.len > 0) {
                const child = if (node.children[0].move.player == .first)
                    node.selectChild(.first)
                else
                    node.selectChild(.second);

                game.makeMove(child.move);
                self.expandRecursive(child, game, acc + child.move.score);
                return;
            }

            var buf: [Game.maxMoves()]Game.Move = undefined;
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
                        break;
                    }
                } else {
                    unreachable;
                }
            }
            return buf;
        }

        pub fn commitMove(self: *Self, move: Game.Move) void {
            self.acc += move.score;
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
            self.root.debugPrintLevel(0);
            for (self.root.children) |child| {
                child.debugPrintLevel(1);
            }
        }
    };
}
