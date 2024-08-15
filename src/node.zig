const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub fn Node(Game: type, Move: type, Player: type, comptime explore_factor: f32) type {
    return struct {
        move: Move = undefined,
        children: []Self = &[_]Self{},
        score: i32 = 0,
        n_extentions: i32 = 0,
        max_result: Player = .first,
        min_result: Player = .second,

        const Self = @This();

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.children) |*child| {
                child.deinit(allocator);
            }
            allocator.free(self.children);
        }

        pub fn bestMove(self: Self) Move {
            var selected_child: *Self = &self.children[0];
            const player = selected_child.move.player;
            for (self.children[1..]) |*child| {
                var score = child.score;
                if (player == .first) {
                    if (child.max_result == .second) {
                        if (child.n_extentions > selected_child.n_extentions) {
                            selected_child = child;
                        }
                        continue;
                    }
                    if (child.min_result == .first) {
                        return child.move;
                    }
                    if (score < 0 and child.min_result == .none) score = 0;
                    if (child.n_extentions > selected_child.n_extentions or
                        child.n_extentions == selected_child.n_extentions and score > selected_child.score)
                    {
                        selected_child = child;
                    }
                } else {
                    if (child.min_result == .first) {
                        if (child.n_extentions > selected_child.n_extentions) {
                            selected_child = child;
                        }
                        continue;
                    }
                    if (child.max_result == .second) {
                        return child.move;
                    }
                    if (score > 0 and child.max_result == .none) score = 0;
                    if (child.n_extentions > selected_child.n_extentions or
                        child.n_extentions == selected_child.n_extentions and score < selected_child.score)
                    {
                        selected_child = child;
                    }
                }
            }

            return selected_child.move;
        }

        pub fn selectChild(self: Self, comptime player: Player) *Self {
            const big_n = @log(@as(f32, @floatFromInt(self.n_extentions)));
            var selected_child: ?*Self = null;
            var selected_score: f32 = -std.math.inf(f32);
            for (self.children) |*child| {
                if (child.n_extentions == 0) return child;
                if (child.max_result != child.min_result) {
                    var score = @as(f32, @floatFromInt(child.score));
                    if (player == .first and score < 0 or player == .second and score > 0) score = 0;
                    const child_score = if (player == .first)
                        explore_factor * @sqrt(big_n / @as(f32, @floatFromInt(child.n_extentions))) + score
                    else
                        explore_factor * @sqrt(big_n / @as(f32, @floatFromInt(child.n_extentions))) - score;
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                } else {
                    if (child.max_result == player) return child;
                    if (child.max_result != .none) continue;
                    unreachable;
                }
            }

            return selected_child.?;
        }

        pub fn updateStats(self: *Self) void {
            self.n_extentions += 1;
            if (self.move.player == .second) {
                self.score = std.math.minInt(i32);
                self.max_result = .second;
                self.min_result = .second;

                for (self.children) |child| {
                    self.score = @max(self.score, child.score);
                    self.max_result = @enumFromInt(@max(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@max(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                }
            } else {
                self.score = std.math.maxInt(i32);
                self.max_result = .first;
                self.min_result = .first;

                for (self.children) |child| {
                    self.score = @min(self.score, child.score);
                    self.max_result = @enumFromInt(@min(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@min(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                }
            }
        }

        pub fn debugSelfCheckRecursive(self: Self, game: Game) void {
            if (self.children.len == 0) return;

            const player = self.children[0].move.player;
            var max: Player = undefined;
            var min: Player = undefined;
            var score: i32 = undefined;

            if (player == .first) {
                score = std.math.minInt(i32);
                max = .second;
                min = .second;
            } else {
                score = std.math.maxInt(i32);
                max = .first;
                min = .first;
            }
            if (player == .first) {
                for (self.children) |child| {
                    score = @max(score, child.score);
                    max = @enumFromInt(@max(@intFromEnum(max), @intFromEnum(child.max_result)));
                    min = @enumFromInt(@max(@intFromEnum(min), @intFromEnum(child.min_result)));
                }
            } else {
                for (self.children) |child| {
                    score = @min(score, child.score);
                    max = @enumFromInt(@min(@intFromEnum(max), @intFromEnum(child.max_result)));
                    min = @enumFromInt(@min(@intFromEnum(min), @intFromEnum(child.min_result)));
                }
            }
            if (self.score != score or self.max_result != max or self.min_result != min) {
                print("\nscore = {d} max = {s} min = {s}", .{ score, max.str(), min.str() });
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
            self.debugPrintLevel(level);
            if (self.children.len == 0) return;

            for (self.children) |child| {
                child.debugPrintRecursive(level + 1);
            }
        }

        pub fn debugPrintLevel(self: Self, level: usize) void {
            print("\n", .{});
            for (0..level) |_| print("| ", .{});
            print("lvl{d} ", .{level + 1});
            self.debugPrint();
        }

        pub fn debugPrint(self: Self) void {
            self.move.print();
            print(" | score: {d}", .{self.score});
            print(" | min: {s}", .{self.min_result.str()});
            print(" | max: {s}", .{self.max_result.str()});
            print(" | extentions: {d}", .{self.n_extentions});
            print(" | children {d}", .{self.children.len});
        }
    };
}
