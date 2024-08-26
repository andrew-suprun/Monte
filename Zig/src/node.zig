const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub fn Node(Game: type) type {
    const Move = Game.Move;
    const Player = Game.Player;

    return struct {
        child_moves: []Move = &[_]Move{},
        child_nodes: []Self = &[_]Self{},
        score: i32 = 0,
        n_extentions: i32 = 0,
        max_result: Player = .first,
        min_result: Player = .second,

        const Self = @This();

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.child_nodes) |*child| {
                child.deinit(allocator);
            }
            allocator.free(self.child_moves);
            allocator.free(self.child_nodes);
        }

        pub fn bestMove(self: Self) Move {
            var selected_node: *Self = &self.child_nodes[0];
            var idx: usize = 0;
            const player = self.child_moves[0].player;
            for (self.child_nodes[1..], 1..) |*child_node, i| {
                var score = child_node.score;
                if (player == .first) {
                    if (child_node.max_result == .second) {
                        if (child_node.n_extentions > selected_node.n_extentions) {
                            selected_node = child_node;
                            idx = i;
                        }
                        continue;
                    }
                    if (child_node.min_result == .first) {
                        return self.child_moves[i];
                    }
                    if (score < 0 and child_node.min_result == .none) score = 0;
                    if (score > selected_node.score) {
                        selected_node = child_node;
                        idx = i;
                    }
                } else {
                    if (child_node.min_result == .first) {
                        if (child_node.n_extentions > selected_node.n_extentions) {
                            selected_node = child_node;
                            idx = i;
                        }
                        continue;
                    }
                    if (child_node.max_result == .second) {
                        return self.child_moves[i];
                    }
                    if (score > 0 and child_node.max_result == .none) score = 0;
                    if (score < selected_node.score) {
                        selected_node = child_node;
                        idx = i;
                    }
                }
            }

            return self.child_moves[idx];
        }

        pub fn selectChild(self: Self, comptime player: Player) struct { move: Move, node: *Self } {
            var selected_node: ?*Self = null;
            var selected_move: ?Move = null;
            var selected_score: i32 = std.math.minInt(i32);
            for (self.child_nodes, 0..) |*child, i| {
                if (child.max_result != child.min_result) {
                    const child_score = if (player == .first)
                        child.score - child.n_extentions
                    else
                        -child.score - child.n_extentions;
                    if (selected_node == null or selected_score < child_score) {
                        selected_node = child;
                        selected_move = self.child_moves[i];
                        selected_score = child_score;
                    }
                } else {
                    if (player == child.max_result) return .{ .move = self.child_moves[i], .node = child };
                }
            }

            return .{ .move = selected_move.?, .node = selected_node.? };
        }

        pub fn updateStats(self: *Self) void {
            self.n_extentions += 1;
            if (self.child_moves[0].player == .first) {
                self.score = std.math.minInt(i32);
                self.max_result = .second;
                self.min_result = .second;

                for (self.child_nodes) |child| {
                    self.score = @max(self.score, child.score);
                    self.max_result = self.max_result.max(child.max_result);
                    self.min_result = self.min_result.max(child.min_result);
                }
                if (self.min_result == .none) self.score = @max(self.score, 0);
            } else {
                self.score = std.math.maxInt(i32);
                self.max_result = .first;
                self.min_result = .first;

                for (self.child_nodes) |child| {
                    self.score = @min(self.score, child.score);
                    self.max_result = self.max_result.min(child.max_result);
                    self.min_result = self.min_result.min(child.min_result);
                }
                if (self.max_result == .none) self.score = @min(self.score, 0);
            }
        }

        pub fn debugSelfCheckRecursive(self: Self, game: Game) void {
            if (self.child_nodes.len == 0) return;

            const player = self.child_moves[0].player;
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
                for (self.child_nodes) |child| {
                    score = @max(score, child.score);
                    max = max.max(child.max_result);
                    min = min.max(child.min_result);
                }
            } else {
                for (self.child_nodes) |child| {
                    score = @min(score, child.score);
                    max = max.min(child.max_result);
                    min = min.min(child.min_result);
                }
            }
            if (self.score != score or self.max_result != max or self.min_result != min) {
                print("\nSelf Check: score = {d} min = {s} max = {s}", .{ score, min.str(), max.str() });
                for (self.child_moves) |child_move| {
                    self.debugPrintRecursive(child_move, 0);
                }
                std.debug.panic("", .{});
            }

            for (self.child_moves, self.child_nodes) |child_move, child_node| {
                var child_game = game;
                _ = child_game.makeMove(child_move);
                child_node.debugSelfCheckRecursive(child_game);
            }
        }

        pub fn debugPrintRecursive(self: Self, move: Move, level: usize) void {
            self.debugPrintLevel(move, level);
            if (self.child_moves.len == 0) return;

            for (self.child_moves, self.child_nodes) |child_move, child_node| {
                child_node.debugPrintRecursive(child_move, level + 1);
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
            print(" | score: {d}", .{self.score});
            print(" | min: {s}", .{self.min_result.str()});
            print(" | max: {s}", .{self.max_result.str()});
            print(" | extentions: {d}", .{self.n_extentions});
            print(" | children {d}", .{self.child_moves.len});
        }

        pub fn debugPrintChildren(self: Self) void {
            print("\n", .{});
            self.debugPrint();
            for (self.child_moves, self.child_nodes) |child_move, child_node| {
                child_node.debugPrintLevel(child_move, 0);
            }
        }
    };
}
