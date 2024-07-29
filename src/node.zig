const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum(u8) {
    second,
    none,
    first,

    pub fn print(player: Player) void {
        const str = switch (player) {
            .first => "first",
            .second => "second",
            .none => "none",
        };
        std.debug.print("{s}", .{str});
    }
};

pub fn Node(comptime Game: type, comptime explore_factor: f32) type {
    return struct {
        move: Game.Move = undefined,
        children: []Self = &[_]Self{},
        stats: Stats = Stats{},
        max_result: Player = .first,
        min_result: Player = .second,

        const Self = Node(Game, explore_factor);

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

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.children) |*child| {
                child.deinit(allocator);
            }
            allocator.free(self.children);
        }

        pub inline fn expand(self: *Self, game: *Game, allocator: Allocator) void {
            var stats = Stats{};
            self.expandWithStats(game, allocator, &stats);
        }

        pub fn expandWithStats(self: *Self, game: *Game, allocator: Allocator, stats: *Stats) void {
            const next_player = game.nextPlayer();
            defer self.updateStats(stats, next_player);

            if (self.children.len > 0) {
                const child = self.selectChild(game.*);

                if (game.makeMove(child.move) == null) {
                    child.expandWithStats(game, allocator, stats);
                }
                return;
            }

            var buf: [Game.max_moves]Game.Move = undefined;
            const moves = game.possibleMoves(&buf);

            self.children = allocator.alloc(Self, moves.len) catch unreachable;
            for (self.children, moves) |*child, move| {
                child.* = Self{};
                child.move = move;
            }

            stats.n_rollouts = @floatFromInt(self.children.len);
            for (self.children) |*child| {
                var rollout = game.*;
                const move_result = rollout.makeMove(child.move);
                if (move_result) |result| {
                    child.max_result = result;
                    child.min_result = result;
                    if (result == rollout.previousPlayer()) {
                        return;
                    }
                    continue;
                }
                const rollout_result = rollout.rollout();
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

        fn selectChild(self: *Self, game: Game) *Self {
            const big_n = @log(self.stats.n_rollouts);

            var selected_child: ?*Self = null;
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = child.calcScore(game) + explore_factor * @sqrt(big_n / child.stats.n_rollouts);
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                }
            }

            return selected_child.?;
        }

        pub fn bestMove(self: Self, game: Game) Game.Move {
            const player = game.nextPlayer();

            // {
            //     print("\n>> best move from: ", .{});
            //     self.move.print();
            //     print(" | child ", .{});
            //     player.print();
            // }

            var selected_child: *Self = &self.children[0];
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
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

        inline fn calcScore(self: Self, game: Game) f32 {
            return if (game.previousPlayer() == .first)
                (self.stats.first_wins - self.stats.second_wins) / self.stats.n_rollouts
            else
                (self.stats.second_wins - self.stats.first_wins) / self.stats.n_rollouts;
        }

        fn updateStats(self: *Self, stats: *Stats, next_player: Player) void {
            self.stats.first_wins += stats.first_wins;
            self.stats.second_wins += stats.second_wins;
            self.stats.n_rollouts += stats.n_rollouts;
            if (next_player == .first) {
                self.max_result = .second;
                self.min_result = .second;

                for (self.children) |child| {
                    self.max_result = @enumFromInt(@max(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@max(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                }
            } else {
                self.max_result = .first;
                self.min_result = .first;

                for (self.children) |child| {
                    self.max_result = @enumFromInt(@min(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@min(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                }
            }
        }

        pub fn debugSelfCheck(self: Self, game: Game) void {
            const player = game.nextPlayer();
            var max: Player = undefined;
            var min: Player = undefined;

            if (self.children.len == 0) return;

            if (player == .first) {
                max = .second;
                min = .second;
            } else {
                max = .first;
                min = .first;
            }
            if (player == .first) {
                for (self.children) |child| {
                    max = @enumFromInt(@max(@intFromEnum(max), @intFromEnum(child.max_result)));
                    min = @enumFromInt(@max(@intFromEnum(min), @intFromEnum(child.min_result)));
                }
            } else {
                for (self.children) |child| {
                    max = @enumFromInt(@min(@intFromEnum(max), @intFromEnum(child.max_result)));
                    min = @enumFromInt(@min(@intFromEnum(min), @intFromEnum(child.min_result)));
                }
            }
            if (self.max_result != max or self.min_result != min) {
                self.debugPrint(game, "FAILURE");
                std.debug.panic("", .{});
            }

            for (self.children) |child| {
                if (self.children.len > 0) {
                    var child_game = game;
                    _ = child_game.makeMove(child.move);
                    child.debugSelfCheck(child_game);
                }
            }
        }

        pub fn debugPrint(self: Self, game: Game, comptime prefix: []const u8) void {
            print("\n--- " ++ prefix ++ " ---", .{});
            self.debugPrintRecursive(game, 0);
        }

        fn debugPrintRecursive(self: Self, game: Game, level: usize) void {
            print("\n", .{});
            for (0..level) |_| print("| ", .{});
            print("lvl{d} ", .{level});
            self.move.print();
            print(" | ", .{});
            self.stats.debugPrint();
            print(" | score: {d:6.3}", .{self.calcScore(game)});
            print(" | max: ", .{});
            self.max_result.print();
            print(" | min: ", .{});
            self.min_result.print();
            print(" | children {d}", .{self.children.len});

            for (self.children) |child| {
                var child_game = game;
                _ = child_game.makeMove(child.move);
                child.debugPrintRecursive(child_game, level + 1);
            }
        }
    };
}

test Node {
    // const Game = @import("RandomGame.zig");
    // var root = Node(Game){};

    // const Game = @import("TicTacToe.zig");
    // var root = Node(Game){};

    const Game = @import("connect6.zig").C6(19);
    var root = Node(Game){};

    defer root.deinit(std.testing.allocator);

    for (0..100) |i| {
        var game = Game.init();
        print("\nEXPAND {d} | player ", .{i});
        root.move.player.print();
        _ = root.expand(&game, std.testing.allocator);
        root.debugPrint("", .first);
        if (root.min_result == root.max_result) break;
    }
}
