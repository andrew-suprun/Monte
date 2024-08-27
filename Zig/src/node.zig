const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum {
    none,
    first,
    second,

    pub fn next(self: Player) Player {
        return if (self == .first) .second else .first;
    }

    fn max(self: Player, other: Player) Player {
        switch (self) {
            .none => if (other == .first) return .first else return .none,
            .first => return self,
            .second => return other,
        }
    }

    fn min(self: Player, other: Player) Player {
        switch (self) {
            .none => if (other == .second) return .second else return .none,
            .first => return other,
            .second => return self,
        }
    }

    pub fn str(self: @This()) []const u8 {
        return switch (self) {
            .none => "=",
            .first => "X",
            .second => "O",
        };
    }
};

pub fn Node(Game: type) type {
    const Move = Game.Move;

    return struct {
        move: Move,
        player: Player,
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
            var selected_node: *Self = &self.children[0];
            for (self.children[1..]) |*child| {
                var score = child.score;
                if (self.player == .second) {
                    if (child.max_result == .second) {
                        if (child.n_extentions > selected_node.n_extentions) {
                            selected_node = child;
                        }
                        continue;
                    }
                    if (child.min_result == .first) {
                        return child.move;
                    }
                    if (score < 0 and child.min_result == .none) score = 0;
                    if (score > selected_node.score) {
                        selected_node = child;
                    }
                } else {
                    if (child.min_result == .first) {
                        if (child.n_extentions > selected_node.n_extentions) {
                            selected_node = child;
                        }
                        continue;
                    }
                    if (child.max_result == .second) {
                        return child.move;
                    }
                    if (score > 0 and child.max_result == .none) score = 0;
                    if (score < selected_node.score) {
                        selected_node = child;
                    }
                }
            }

            return selected_node.move;
        }

        pub fn selectChild(self: Self, comptime player: Player) *Self {
            var selected_node: ?*Self = null;
            var selected_score: i32 = std.math.minInt(i32);
            for (self.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = if (player == .first)
                        child.score - child.n_extentions
                    else
                        -child.score - child.n_extentions;
                    if (selected_node == null or selected_score < child_score) {
                        selected_node = child;
                        selected_score = child_score;
                    }
                } else {
                    if (player == child.max_result) return child;
                }
            }

            return selected_node.?;
        }

        pub fn updateStats(self: *Self) void {
            self.n_extentions += 1;
            if (self.player == .second) {
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

            const player = self.player;
            var max: Player = undefined;
            var min: Player = undefined;
            var score: i32 = undefined;

            if (player == .second) {
                score = std.math.minInt(i32);
                max = .second;
                min = .second;
                for (self.children) |child| {
                    score = @max(score, child.score);
                    max = max.max(child.max_result);
                    min = min.max(child.min_result);
                }
            } else {
                score = std.math.maxInt(i32);
                max = .first;
                min = .first;
                for (self.children) |child| {
                    score = @min(score, child.score);
                    max = max.min(child.max_result);
                    min = min.min(child.min_result);
                }
            }
            if (self.score != score or self.max_result != max or self.min_result != min) {
                print("\nSelf Check: score = {d} min = {s} max = {s}", .{ score, min.str(), max.str() });
                self.debugPrintRecursive(0);
                std.debug.panic("", .{});
            }

            for (self.children) |child| {
                var child_game = game;
                _ = child_game.makeMove(child.move);
                child.debugSelfCheckRecursive(child_game);
            }
        }

        pub fn debugPrintRecursive(self: Self, level: usize) void {
            self.debugPrintLevel(self.move, level);

            for (self.children) |child| {
                child.debugPrintRecursive(level + 1);
            }
        }

        pub fn debugPrintLevel(self: Self, move: Move, level: usize) void {
            print("\n", .{});
            for (0..level) |_| print("| ", .{});
            print("lvl{d} ", .{level + 1});
            move.print();
            self.debugPrint();
        }

        pub fn debugPrint(self: Self) void {
            print(" | player: {s}", .{self.player.str()});
            print(" | score: {d}", .{self.score});
            print(" | min: {s}", .{self.min_result.str()});
            print(" | max: {s}", .{self.max_result.str()});
            print(" | extentions: {d}", .{self.n_extentions});
            print(" | children {d}", .{self.children.len});
        }

        pub fn debugPrintChildren(self: Self) void {
            print("\n", .{});
            self.debugPrint();
            for (self.children) |child| {
                child.debugPrintLevel(child.move, 0);
            }
        }
    };
}
