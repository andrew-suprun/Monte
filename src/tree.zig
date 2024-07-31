const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum(u8) { second, none, first };

pub fn SearchTree(comptime Game: type, comptime explore_factor: f32) type {
    return struct {
        root: Node,
        game: Game,
        allocator: Allocator,

        const Self = SearchTree(Game, explore_factor);
        const Node = struct {
            move: Game.Move = undefined,
            children: []Node = &[_]Node{},
            stats: Stats = Stats{},
            max_result: Player = .first,
            min_result: Player = .second,

            fn deinit(node: *Node, allocator: Allocator) void {
                for (node.children) |*child| {
                    child.deinit(allocator);
                }
                allocator.free(node.children);
            }
        };

        const Stats = struct {
            first_wins: f32 = 0,
            second_wins: f32 = 0,
            n_rollouts: f32 = 1,

            fn debugPrint(self: Stats) void {
                print("first: {d:3} | second: {d:3} | rollouts: {d:4}", .{
                    self.first_wins,
                    self.second_wins,
                    self.n_rollouts,
                });
            }
        };

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
            const next_player = game.nextPlayer();
            defer Self.updateStats(node, stats, next_player);

            if (node.children.len > 0) {
                const child = Self.selectChild(node.*, game.*);

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
                    if (result == rollout_game.previousPlayer()) {
                        return;
                    }
                    continue;
                }
                const rollout_result = Self.rollout(&rollout_game);
                switch (rollout_result) {
                    .first => {
                        child.stats.first_wins = 1;
                        stats.first_wins += 1;
                    },
                    .second => {
                        child.stats.second_wins = 1;
                        stats.second_wins += 1;
                    },
                    else => {},
                }
            }
            return;
        }

        fn selectChild(node: Node, game: Game) *Node {
            const big_n = @log(node.stats.n_rollouts);

            var selected_child: ?*Node = null;
            var selected_score = -std.math.inf(f32);
            for (node.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = Self.calcScore(child.*, game) + explore_factor * @sqrt(big_n / child.stats.n_rollouts);
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                }
            }

            return selected_child.?;
        }

        inline fn calcScore(node: Node, game: Game) f32 {
            return if (game.previousPlayer() == .first)
                (node.stats.first_wins - node.stats.second_wins) / node.stats.n_rollouts
            else
                (node.stats.second_wins - node.stats.first_wins) / node.stats.n_rollouts;
        }

        fn updateStats(node: *Node, stats: *Stats, next_player: Player) void {
            node.stats.first_wins += stats.first_wins;
            node.stats.second_wins += stats.second_wins;
            node.stats.n_rollouts += stats.n_rollouts;
            if (next_player == .first) {
                node.max_result = .second;
                node.min_result = .second;

                for (node.children) |child| {
                    node.max_result = @enumFromInt(@max(@intFromEnum(node.max_result), @intFromEnum(child.max_result)));
                    node.min_result = @enumFromInt(@max(@intFromEnum(node.min_result), @intFromEnum(child.min_result)));
                }
            } else {
                node.max_result = .first;
                node.min_result = .first;

                for (node.children) |child| {
                    node.max_result = @enumFromInt(@min(@intFromEnum(node.max_result), @intFromEnum(child.max_result)));
                    node.min_result = @enumFromInt(@min(@intFromEnum(node.min_result), @intFromEnum(child.min_result)));
                }
            }
        }

        pub fn rollout(game: *Game) Player {
            while (true) {
                if (game.makeMove(game.rolloutMove())) |winner| {
                    return winner;
                }
            }
        }

        pub fn bestMove(self: Self) Game.Move {
            return bestNodeMove(self.root, self.game);
        }

        pub fn bestNodeMove(node: Node, game: Game) Game.Move {
            const player = game.nextPlayer();

            var selected_child: *Node = &node.children[0];
            var selected_score = -std.math.inf(f32);
            for (node.children) |*child| {
                var score = -std.math.inf(f32);
                if (player == .first) {
                    if (child.max_result == .second) continue;
                    if (child.min_result == .first) {
                        return child.move;
                    }
                    score = (child.stats.first_wins - child.stats.second_wins) / child.stats.n_rollouts;
                    if (score < 0 and child.min_result == .none)
                        score = 0;
                } else {
                    if (child.min_result == .first) continue;
                    if (child.max_result == .second) {
                        return child.move;
                    }
                    score = (child.stats.second_wins - child.stats.first_wins) / child.stats.n_rollouts;
                    if (score < 0 and child.max_result == .none)
                        score = 0;
                }
                if (selected_score < score) {
                    selected_child = child;
                    selected_score = score;
                }
            }

            return selected_child.move;
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
            self.debugPrintRecursive(self.root, self.game, 0);
        }

        fn debugPrintRecursive(self: Self, node: Node, game: Game, level: usize) void {
            Self.debugPrintNode(node, game, level);
            if (node.children.len == 0) return;

            const best_move = Self.bestNodeMove(node, game);
            for (node.children) |child| {
                var child_game = game;
                _ = child_game.makeMove(child.move);
                if (child.move.eql(best_move)) {
                    self.debugPrintRecursive(child, child_game, level + 1);
                } else {
                    Self.debugPrintNode(child, child_game, level + 1);
                }
            }
        }

        pub fn debugPrintNode(node: Node, game: Game, level: usize) void {
            print("\n", .{});
            for (0..level) |_| print("| ", .{});
            print("lvl{d} ", .{level + 1});
            node.move.print(game.previousPlayer());
            print(" | ", .{});
            node.stats.debugPrint();
            print(" | score: {d:6.3}", .{Self.calcScore(node, game)});
            print(" | max: {s}", .{Game.playerStr(node.max_result)});
            print(" | min: {s}", .{Game.playerStr(node.min_result)});
            print(" | children {d}", .{node.children.len});
        }

        pub fn debugPrintChildren(self: Self) void {
            print("\n", .{});
            Self.debugPrintNode(self.root, self.game);
            for (self.root.children) |child| {
                var child_game = self.game;
                _ = child_game.makeMove(child.move);
                print("\n  ", .{});
                Self.debugPrintNode(child, child_game);
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
