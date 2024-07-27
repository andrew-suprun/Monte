const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum(u8) { second, none, first };

pub fn Node(comptime Game: type) type {
    return struct {
        move: Game.Move = undefined,
        children: []Self = &[_]Self{},
        stats: Stats = Stats{},
        max_result: Player = .first,
        min_result: Player = .second,

        const Self = Node(Game);

        const Stats = struct {
            first_wins: f32 = 0,
            second_wins: f32 = 0,
            n_rollouts: f32 = 1,

            fn debugPrint(self: Stats) void {
                print("first: {d} | second: {d} | rollouts: {d}", .{
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

        pub inline fn expand(self: *Self, game: *Game, allocator: Allocator) ?Player {
            var stats = Stats{};
            return self.expandWithStats(game, allocator, &stats);
        }

        pub fn expandWithStats(self: *Self, game: *Game, allocator: Allocator, stats: *Stats) ?Player {
            const next_player = game.nextPlayer();
            defer self.updateStats(next_player, stats);

            if (self.children.len > 0) {
                const child = if (next_player == .first)
                    self.selectChild(.first)
                else
                    self.selectChild(.second);

                if (game.makeMove(child.move)) |winner| {
                    return winner;
                }
                return child.expandWithStats(game, allocator, stats);
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
                    if (move_result == next_player) {
                        return result;
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
            return null;
        }

        fn selectChild(self: *Self, comptime player: Player) *Self {
            const big_n = @log(self.stats.n_rollouts);

            var selected_child: ?*Self = null;
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = child.calcScore(player) + Game.explore_factor * @sqrt(big_n / child.stats.n_rollouts);
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                }
            }

            return selected_child.?;
        }

        pub fn bestMove(self: Self, comptime player: Player) Game.Move {
            var selected_child: ?*Self = null;
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = child.calcScore(player);
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                }
            }

            return selected_child.?.move;
        }

        inline fn calcScore(self: Self, comptime player: Player) f32 {
            const sum = if (player == .first)
                self.stats.n_rollouts + self.stats.first_wins - self.stats.second_wins
            else
                self.stats.n_rollouts + self.stats.second_wins - self.stats.first_wins;
            return sum / self.stats.n_rollouts;
        }

        fn updateStats(self: *Self, player: Player, stats: *Stats) void {
            self.stats.first_wins += stats.first_wins;
            self.stats.second_wins += stats.second_wins;
            self.stats.n_rollouts += stats.n_rollouts;
            if (player == .first) {
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

        pub fn debugPrint(self: Self, comptime prefix: []const u8, player: Player) void {
            print("\n--- " ++ prefix ++ " --- next player {s}", .{playerStr(player)});
            self.debugPrintIndented(0);
        }

        fn debugPrintIndented(self: Self, level: usize) void {
            print("\n", .{});
            for (0..level) |_| print("| ", .{});
            print("| move {any} | ", .{self.move});
            self.stats.debugPrint();
            print(" | max {s}", .{playerStr(self.max_result)});
            print(" | min {s}", .{playerStr(self.min_result)});
            for (self.children) |child| {
                child.debugPrintIndented(level + 1);
            }
        }
    };
}

fn playerStr(player: Player) []const u8 {
    return switch (player) {
        .first => "first",
        .second => "second",
        .none => "none",
    };
}

test Node {
    // const Game = @import("RandomGame.zig");
    // var root = Node(Game){};

    // const Game = @import("TicTacToe.zig");
    // var root = Node(Game){};

    // const Game = @import("connect6.zig").C6(19);
    // var root = Node(Game){};

    // defer root.deinit(std.testing.allocator);

    // for (0..100) |i| {
    //     var game = Game.init();
    //     print("\nEXPAND {d} | player {s}", .{ i, playerStr(game.nextPlayer()) });
    //     _ = root.expand(&game, std.testing.allocator);
    //     root.debugPrint("", .first);
    //     if (root.min_result == root.max_result) break;
    // }

    const M = struct {
        player: u8,
        x: u8,
        y: u8,
    };

    const Stats = struct {
        first_wins: f32 = 0,
        second_wins: f32 = 0,
        n_rollouts: f32 = 1,
    };

    const N = struct {
        move: M = undefined,
        children: []@This() = &[_]@This(){},
        stats: Stats = Stats{},
        max_result: Player = .first,
        min_result: Player = .second,
    };

    print("\nsize {d}\n", .{@sizeOf(N)});
}
