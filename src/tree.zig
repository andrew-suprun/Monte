const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum(u8) { second, none, first };

pub fn SearchTree(Game: type, comptime explore_factor: f32) type {
    return struct {
        root: Node,
        game: Game,
        allocator: Allocator,

        const Self = SearchTree(Game, explore_factor);
        const Node = @import("node.zig").Node(Game, Player, explore_factor);
        const Stats = @import("stats.zig").Stats(Player);

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
            var expand_game = self.game;
            var stats = Stats{};
            self.expandWithStats(&self.root, &expand_game, &stats);
        }

        pub fn expandWithStats(self: *Self, node: *Node, game: *Game, stats: *Stats) void {
            defer node.updateStats(stats);

            if (node.children.len > 0) {
                const child = node.selectChild();

                if (game.makeMove(child.move) == null) {
                    self.expandWithStats(child, game, stats);
                }
                return;
            }

            var buf: [Game.maxMoves()]Game.Move = undefined;
            const moves = game.possibleMoves(&buf);

            node.children = self.allocator.alloc(Node, moves.len) catch unreachable;
            for (node.children, moves) |*child, move| {
                child.* = Node{};
                child.move = move;
            }

            stats.n_rollouts = @floatFromInt(node.children.len);
            for (node.children) |*child| {
                var rollout_game = game.*;
                const move_result = rollout_game.makeMove(child.move);
                if (move_result) |result| {
                    child.max_result = result;
                    child.min_result = result;
                    if (result == child.move.player) {
                        return;
                    }
                    continue;
                }
                const rollout_result = rollout_game.rollout();
                switch (rollout_result) {
                    .first => {
                        child.stats.rollout_diff = 1;
                        stats.rollout_diff += 1;
                    },
                    .second => {
                        child.stats.rollout_diff = -1;
                        stats.rollout_diff -= 1;
                    },
                    else => {},
                }
            }
            return;
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

        pub fn debugSelfCheck(self: Self) void {
            Self.debugSelfCheckRecursive(self, self.root, self.game);
        }

        pub fn debugSelfCheckRecursive(self: Self, node: Node, game: Game) void {
            const player = game.nextPlayer();
            var max: Player = undefined;
            var min: Player = undefined;

            if (node.children.len == 0) return;

            if (player == .first) {
                max = .second;
                min = .second;
            } else {
                max = .first;
                min = .first;
            }
            if (player == .first) {
                for (node.children) |child| {
                    max = @enumFromInt(@max(@intFromEnum(max), @intFromEnum(child.max_result)));
                    min = @enumFromInt(@max(@intFromEnum(min), @intFromEnum(child.min_result)));
                }
            } else {
                for (node.children) |child| {
                    max = @enumFromInt(@min(@intFromEnum(max), @intFromEnum(child.max_result)));
                    min = @enumFromInt(@min(@intFromEnum(min), @intFromEnum(child.min_result)));
                }
            }
            if (node.max_result != max or node.min_result != min) {
                self.debugPrint();
                std.debug.panic("", .{});
            }

            for (node.children) |child| {
                if (node.children.len > 0) {
                    var child_game = game;
                    _ = child_game.makeMove(child.move);
                    self.debugSelfCheckRecursive(child, child_game);
                }
            }
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
