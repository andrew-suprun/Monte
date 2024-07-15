const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Player = @import("tree.zig").Player;

pub fn Node(comptime Game: type) type {
    return struct {
        move: Game.Move,
        children: []Self = &[_]Self{},
        first_wins: f32 = 0,
        second_wins: f32 = 0,
        n_rollouts: f32 = 0,
        max_result: Player = .first,
        min_result: Player = .second,

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
            if (self.children.len > 0) {
                const child = self.selectChild(game.nextPlayer());
                _ = game.makeMove(child.move);
                child.expand(game, allocator);
                self.updateStats(game.nextPlayer());
            }

            var buf: [Game.max_moves]Game.Move = undefined;
            const moves = game.possibleMoves(&buf);

            self.children = allocator.alloc(Self, moves.len) catch unreachable;
            for (0..moves.len) |i| {
                self.children[i] = Self.init(moves[i]);
            }

            for (self.children) |*child| {
                var rollout = game.clone();
                const move_result = rollout.makeMove(child.move);
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
            self.updateStats(game.nextPlayer());
        }

        fn updateStats(self: *Self, player: Player) void {
            self.first_wins = 0;
            self.second_wins = 0;
            self.n_rollouts = 0;
            self.max_result = .second;
            self.min_result = .first;

            if (player == .first) {
                for (self.children) |child| {
                    self.first_wins += child.first_wins;
                    self.second_wins += child.second_wins;
                    self.n_rollouts += self.children.len;
                    self.max_result = @enumFromInt(@max(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@max(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                }
            } else {
                for (self.children) |child| {
                    self.first_wins += child.first_wins;
                    self.second_wins += child.second_wins;
                    self.n_rollouts += self.children.len;
                    self.max_result = @enumFromInt(@min(@intFromEnum(self.max_result), @intFromEnum(child.max_result)));
                    self.min_result = @enumFromInt(@min(@intFromEnum(self.min_result), @intFromEnum(child.min_result)));
                }
            }
        }

        fn selectChild(self: *Self, player: Player) *Self {
            var selected_child: ?*Self = null;
            // TODO: Complete

            if (!selected_child.node_complete and selected_child.child_moves.len == 0)
                return .{ .move = Game.Move{}, .node = selected_child };

            const parent_rollouts: f32 = @floatFromInt(self.n_rollouts);
            const big_n = @log(parent_rollouts);

            const child_rollouts: f32 = @floatFromInt(selected_child.n_rollouts);
            var score = selected_child.calcScore(player);
            var selected_score = score / parent_rollouts + Game.explore_factor * @sqrt(big_n / child_rollouts);

            for (self.child_moves[1..], self.children[1..]) |move, *child| {
                if (child.node_complete) continue;
                if (child.child_moves.len == 0)
                    return .{ .move = move, .node = child };

                score = child.calcScore(player);

                if (score > selected_score) {
                    print("### selectChild.3: selected_node {any}; score {}\n", .{ selected_child, selected_score });
                    selected_score = score;
                    selected_child = child;
                }
            }

            return selected_child;
        }

        inline fn calcScore(self: Self, player: Player) f32 {
            return if (player == .first)
                @as(f32, @floatFromInt(self.n_rollouts + self.first_wins - self.second_wins))
            else
                @as(f32, @floatFromInt(self.n_rollouts + self.second_wins - self.first_wins));
        }
    };
}

test Node {
    const Game = @import("RandomGame.zig");
    var root = Node(Game).initRoot();
    var game = Game.init();
    root.expand(&game, std.testing.allocator);
}
