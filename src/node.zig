const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum(i64) { first = 1, second = -1, none = 0 };

pub fn Node(comptime Game: type) type {
    return struct {
        move: Game.Move,
        children: []Self = &[_]Self{},
        first_wins: f32 = 0,
        second_wins: f32 = 0,
        n_rollouts: f32 = 0,
        max_result: Player = .first,
        min_result: Player = .second,

        fn debugPrintSelf(self: Self) void {
            print("| move: {any} | first: {d} | second: {d} | rollouts: {d} | max: {any} | min: {any}", .{ self.move, self.first_wins, self.second_wins, self.n_rollouts, self.max_result, self.min_result });
        }

        fn debugPrint(self: Self, comptime prefix: []const u8) void {
            print("\n--- " ++ prefix ++ " ---", .{});
            self.debugPrintIndented(0);
        }

        fn debugPrintIndented(self: Self, level: usize) void {
            print("\n", .{});
            for (0..level) |_| print("  ", .{});
            self.debugPrintSelf();
            for (self.children) |child| {
                child.debugPrintIndented(level + 1);
            }
        }

        const Self = Node(Game);

        pub fn initRoot() Self {
            return .{ .move = undefined };
        }

        pub fn init(move: Game.Move) Self {
            return .{ .move = move };
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            for (self.children) |*child| {
                child.deinit(allocator);
            }
            allocator.free(self.children);
        }

        pub fn expand(self: *Self, game: *Game, allocator: Allocator) void {
            const next_player = game.nextPlayer();
            if (self.children.len > 0) {
                const child = if (next_player == .first)
                    self.selectChild(.first)
                else
                    self.selectChild(.second);

                _ = game.makeMove(child.move);
                child.expand(game, allocator);
                self.updateStats(next_player);
            }

            var buf: [Game.max_moves]Game.Move = undefined;
            const moves = game.possibleMoves(&buf);

            self.children = allocator.alloc(Self, moves.len) catch unreachable;
            for (0..moves.len) |i| {
                self.children[i] = Self.init(moves[i]);
            }

            for (self.children) |*child| {
                var rollout = game.clone();
                child.n_rollouts += 1;
                const move_result = rollout.makeMove(child.move);
                print("\n  move {any} | result {any}", .{ child.move, move_result });
                if (move_result) |result| {
                    child.max_result = result;
                    child.min_result = result;
                    if (move_result == game.previousPlayer()) {
                        return;
                    }
                }
                switch (game.rollout()) {
                    .first => {
                        self.first_wins += 1;
                        child.first_wins = 1;
                    },
                    .second => {
                        self.second_wins += 1;
                        child.second_wins = 1;
                    },
                    else => {},
                }
            }
            self.updateStats(next_player);
        }

        fn selectChild(self: *Self, comptime player: Player) *Self {
            const big_n = @log(self.n_rollouts);

            var selected_child: ?*Self = null;
            var selected_score = -std.math.inf(f32);
            for (self.children) |*child| {
                if (child.max_result != child.min_result) {
                    const child_score = child.calcScore(player) / self.n_rollouts + Game.explore_factor * @sqrt(big_n / child.n_rollouts);
                    if (selected_child == null or selected_score < child_score) {
                        selected_child = child;
                        selected_score = child_score;
                    }
                }
            }

            return selected_child.?;
        }

        inline fn calcScore(self: Self, comptime player: Player) f32 {
            return if (player == .first)
                self.n_rollouts + self.first_wins - self.second_wins
            else
                self.n_rollouts + self.second_wins - self.first_wins;
        }

        fn updateStats(self: *Self, player: Player) void {
            self.first_wins = 0;
            self.second_wins = 0;
            self.n_rollouts = 0;
            if (player == .first) {
                self.max_result = .second;
                self.min_result = .second;
            } else {
                self.max_result = .first;
                self.min_result = .first;
            }

            for (self.children) |child| {
                self.first_wins += child.first_wins;
                self.second_wins += child.second_wins;
                self.n_rollouts += child.n_rollouts;
                if (player == .first) {
                    self.max_result = @enumFromInt(@max(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@max(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                } else {
                    self.max_result = @enumFromInt(@min(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@min(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                }
            }
        }
    };
}

test Node {
    const Game = @import("RandomGame.zig");
    var root = Node(Game).initRoot();
    defer root.deinit(std.testing.allocator);

    var game = Game.init();
    for (0..10) |_| {
        root.expand(&game, std.testing.allocator);
    }
}
