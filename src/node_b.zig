const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub fn Node(Game: type, Player: type) type {
    return struct {
        move: Game.Move = undefined,
        children: []Self = &[_]Self{},
        score: i32 = undefined,
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

        pub fn bestMove(self: Self) Game.Move {
            var selected_child: *Self = &self.children[0];
            const player = selected_child.move.player;
            for (self.children[1..]) |*child| {
                var score = child.score;
                if (player == .first) {
                    if (child.max_result == .second) continue;
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
                    if (child.min_result == .first) continue;
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
            var selected_child: ?*Self = null;
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = if (player == .first)
                        @as(f32, @floatFromInt(child.move.score - child.n_extentions))
                    else
                        @as(f32, @floatFromInt(child.n_extentions - child.move.score));
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
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
