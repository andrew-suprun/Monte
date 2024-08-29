const std = @import("std");
const Allocator = std.mem.Allocator;
const Prng = std.rand.Random.DefaultPrng;

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
        n_expansions: i32 = 0,
        conclusive: bool = false,

        const Self = @This();

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.children) |*child| {
                child.deinit(allocator);
            }
            allocator.free(self.children);
        }

        pub fn bestNode(self: Self, rng: *Prng) Self {
            var best_node: *Self = &self.children[0];
            var prob: usize = 2;
            for (self.children[1..]) |*child| {
                if (best_node.score < child.score) {
                    best_node = child;
                    prob = 2;
                } else if (best_node.score == child.score and rng.next() % prob == 0) {
                    best_node = child;
                    prob += 1;
                }
            }

            return best_node.*;
        }

        pub fn selectChild(self: Self, comptime player: Player) *Self {
            var selected_node: ?*Self = null;
            var selected_score: i32 = std.math.minInt(i32);
            for (self.children) |*child| {
                if (!child.conclusive) {
                    const child_score = if (player == .first)
                        child.score - child.n_expansions
                    else
                        -child.score - child.n_expansions;
                    if (selected_node == null or selected_score < child_score) {
                        selected_node = child;
                        selected_score = child_score;
                    }
                }
            }

            return selected_node.?;
        }

        pub fn updateStats(self: *Self) void {
            self.n_expansions += 1;
            self.conclusive = true;
            if (self.player == .second) {
                self.score = std.math.minInt(i32);

                for (self.children) |child| {
                    self.score = @max(self.score, child.score);
                    self.conclusive = self.conclusive and child.conclusive;
                }
            } else {
                self.score = std.math.maxInt(i32);

                for (self.children) |child| {
                    self.score = @min(self.score, child.score);
                    self.conclusive = self.conclusive and child.conclusive;
                }
            }
        }

        pub fn debugSelfCheckRecursive(self: Self, game: Game) void {
            if (self.children.len == 0) return;

            const player = self.player;
            var max: Player = undefined;
            var min: Player = undefined;
            var score: i32 = undefined;

            var conclusive = true;
            if (player == .second) {
                score = std.math.minInt(i32);
                for (self.children) |child| {
                    score = @max(score, child.score);
                    conclusive = conclusive and child.conclusive;
                }
            } else {
                score = std.math.maxInt(i32);
                max = .first;
                min = .first;
                for (self.children) |child| {
                    score = @min(score, child.score);
                    conclusive = conclusive and child.conclusive;
                }
            }
            if (self.score != score or self.conclusive != conclusive) {
                std.debug.print("\nSelf Check: score = {d} conclusive = {any}", .{ score, conclusive });
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
            std.debug.print("\n", .{});
            for (0..level) |_| std.debug.print("| ", .{});
            std.debug.print("lvl{d} ", .{level + 1});
            move.print();
            self.debugPrint();
        }

        pub fn debugPrint(self: Self) void {
            std.debug.print(" | player: {s}", .{self.player.str()});
            std.debug.print(" | score: {d}", .{self.score});
            std.debug.print(" | conclusive: {any}", .{self.conclusive});
            std.debug.print(" | expansions: {d}", .{self.n_expansions});
            std.debug.print(" | children {d}", .{self.children.len});
        }

        pub fn debugPrintChildren(self: Self) void {
            std.debug.print("\n", .{});
            self.debugPrint();
            for (self.children) |child| {
                child.debugPrintLevel(child.move, 0);
            }
        }
    };
}
