const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub fn Node(Game: type) type {
    return struct {
        move: Game.Move = undefined,
        children: []Self = &[_]Self{},
        score: i32 = 0,
        n_extentions: i32 = 0,
        max_result: Game.Player = .first,
        min_result: Game.Player = .second,

        const Self = @This();

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.children) |*child| {
                child.deinit(allocator);
            }
            allocator.free(self.children);
        }

        pub fn bestMove(self: Self) Game.Move {
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

        pub fn selectChild(self: Self, comptime player: Game.Player) *Self {
            var selected_child: ?*Self = null;
            var selected_score: i32 = std.math.minInt(i32);
            for (self.children) |*child| {
                if (child.n_extentions == 0) return child;
                if (child.max_result != child.min_result) {
                    const child_score = if (player == .first)
                        child.score - child.n_extentions
                    else
                        -child.score - child.n_extentions;
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                } else {
                    if (player == child.max_result) return child;
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
                    self.max_result = self.max_result.max(child.max_result);
                    self.min_result = self.min_result.max(child.min_result);
                }
                if (self.min_result == .none) self.score = @max(self.score, 0);
            } else {
                self.score = std.math.maxInt(i32);
                self.max_result = .first;
                self.min_result = .first;

                for (self.children) |child| {
                    self.score = @min(self.score, child.score);
                    self.max_result = self.max_result.min(child.max_result);
                    self.min_result = self.min_result.min(child.min_result);
                }
                if (self.max_result == .none) self.score = @min(self.score, 0);
            }
        }

        pub fn debugSelfCheckRecursive(self: Self, game: Game) void {
            if (self.children.len == 0) return;

            const player = self.children[0].move.player;
            var max: Game.Player = undefined;
            var min: Game.Player = undefined;
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
                    max = max.max(child.max_result);
                    min = min.max(child.min_result);
                }
            } else {
                for (self.children) |child| {
                    score = @min(score, child.score);
                    max = max.min(child.max_result);
                    min = min.min(child.min_result);
                }
            }
            if (self.score != score or self.max_result != max or self.min_result != min) {
                print("\nscore = {d} min = {s} max = {s}", .{ score, min.str(), max.str() });
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

        pub fn debugPrintChildren(self: Self) void {
            print("\n", .{});
            self.debugPrintLevel(0);
            for (self.children) |child| {
                child.debugPrintLevel(1);
            }
        }
    };
}
