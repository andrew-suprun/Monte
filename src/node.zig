const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub fn Node(Game: type, Player: type, comptime explore_factor: f32) type {
    return struct {
        move: Game.Move = undefined,
        children: []Self = &[_]Self{},
        stats: Stats = Stats{},
        max_result: Player = .first,
        min_result: Player = .second,

        const Self = @This();
        const Stats = @import("stats.zig").Stats(Player);

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.children) |*child| {
                child.deinit(allocator);
            }
            allocator.free(self.children);
        }

        pub fn bestMove(self: Self) Game.Move {
            const player = self.move.next_player;

            var selected_child: *Self = &self.children[0];
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
                var score = -std.math.inf(f32);
                if (player == .first) {
                    if (child.max_result == .second) continue;
                    if (child.min_result == .first) {
                        return child.move;
                    }
                    score = child.stats.rollout_diff / child.stats.n_rollouts;
                    if (score < 0 and child.min_result == .none)
                        score = 0;
                } else {
                    if (child.min_result == .first) continue;
                    if (child.max_result == .second) {
                        return child.move;
                    }
                    score = -child.stats.rollout_diff / child.stats.n_rollouts;
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

        pub fn selectChild(self: Self) *Self {
            const big_n = @log(self.stats.n_rollouts);

            var selected_child: ?*Self = null;
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = child.stats.calcScore(self.move.player) + explore_factor * @sqrt(big_n / child.stats.n_rollouts);
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                }
            }

            return selected_child.?;
        }

        pub fn updateStats(self: *Self, stats: *Stats) void {
            self.stats.rollout_diff += stats.rollout_diff;
            self.stats.n_rollouts += stats.n_rollouts;
            if (self.move.next_player == .first) {
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

        pub fn debugSelfCheckRecursive(self: Self, game: Game) void {
            const player = self.move.next_player;
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
                print("\nmax = {s} min = {s}", .{ Game.playerStr(max), Game.playerStr(min) });
                self.debugPrintRecursive(0);
                std.debug.panic("", .{});
            }

            for (self.children) |child| {
                if (self.children.len > 0) {
                    var child_game = game;
                    _ = child_game.makeMove(child.move);
                    child.debugSelfCheckRecursive(child_game);
                }
            }
        }

        pub fn debugPrintRecursive(self: Self, level: usize) void {
            self.debugPrint(level);
            if (self.children.len == 0) return;

            const best_move = self.bestMove();
            for (self.children) |child| {
                if (child.move.eql(best_move)) {
                    child.debugPrintRecursive(level + 1);
                } else {
                    child.debugPrint(level + 1);
                }
            }
        }

        pub fn debugPrint(self: Self, level: usize) void {
            const player = self.move.player;
            print("\n", .{});
            for (0..level) |_| print("| ", .{});
            print("lvl{d} ", .{level + 1});
            self.move.print();
            print(" | ", .{});
            self.stats.debugPrint();
            print(" | score: {d:6.3}", .{self.stats.calcScore(player)});
            print(" | max: {s}", .{Game.playerStr(self.max_result)});
            print(" | min: {s}", .{Game.playerStr(self.min_result)});
            print(" | children {d}", .{self.children.len});
        }
    };
}
