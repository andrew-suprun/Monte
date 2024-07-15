const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub const Player = enum { second, none, first };

// const Game = @import("connect6.zig").C6(19); // ###
// const Game = @import("TicTacToe.zig"); // ###
const Game = @import("RandomGame.zig"); // ###
// pub fn SearchTree(comptime Game: type) type { // ###
pub fn SearchTree() type {
    return struct {
        root: Node,
        allocator: Allocator,

        const Self = SearchTree();
        // const Self = SearchTree(Game); // ###

        pub const Node = struct {
            move: Game.Move,
            children: []Node = &[_]Node{},
            first_wins: f32 = 0,
            second_wins: f32 = 0,
            n_rollouts: f32 = 0,
            max_result: Player = .first,
            min_result: Player = .second,

            pub fn init(move: Game.Move) Node {
                return .{ .move = move };
            }

            pub fn deinit(self: *Node, allocator: Allocator) void {
                for (self.children) |*child| {
                    child.deinit(allocator);
                }
                allocator.free(self.children);
            }

            fn exand(self: *Node, game: *Game) void {
                if (self.children.len > 0) {
                    const child = self.selectChild(game);
                    _ = game.makeMove(child.move);
                    self.exand_node(child, game);
                    self.updateStats();
                }

                var buf: [Game.max_moves]Game.Move = undefined;
                const moves = game.possibleMoves(&buf);

                self.children = self.allocator.alloc(Node, moves.len);
                for (0..moves.len) |i| {
                    self.children[i] = Node(moves[i]);
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
                    }
                }
                self.updateStats();
            }

            fn updateStats(self: *Node, game: Game) void {
                self.first_wins = 0;
                self.second_wins = 0;
                self.n_rollouts = 0;
                self.max_result = .second;
                self.min_result = .first;

                if (game.nextPlayer() == .first) {
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

            fn selectChild(self: *Node, game: Game) struct { move: Game.Move, node: *Node } {
                var selected_child: ?*Node = null;
                // TODO: Complete

                if (!selected_child.node_complete and selected_child.child_moves.len == 0)
                    return .{ .move = Game.Move{}, .node = selected_child };

                const parent_rollouts: f32 = @floatFromInt(self.n_rollouts);
                const big_n = @log(parent_rollouts);

                const child_rollouts: f32 = @floatFromInt(selected_child.n_rollouts);
                var score = selected_child.calcScore(game);
                var selected_score = score / parent_rollouts + Game.explore_factor * @sqrt(big_n / child_rollouts);

                for (self.child_moves[1..], self.children[1..]) |move, *child| {
                    if (child.node_complete) continue;
                    if (child.child_moves.len == 0)
                        return .{ .move = move, .node = child };

                    score = child.calcScore(game);

                    if (score > selected_score) {
                        print("### selectChild.3: selected_node {any}; score {}\n", .{ selected_child, selected_score });
                        selected_score = score;
                        selected_child = child;
                    }
                }

                return .{ .move = Game.Move{}, .node = selected_child };
            }

            inline fn calcScore(self: Node, game: Game) f32 {
                return if (game.turn() == .first)
                    @as(f32, @floatFromInt(self.n_rollouts + self.first_wins - self.second_wins))
                else
                    @as(f32, @floatFromInt(self.n_rollouts + self.second_wins - self.first_wins));
            }
        };

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .root = Node.init(undefined),
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
        }

        pub fn expand(self: *Self) void {
            var game = Game.init();
            self.expand_node(&game, &self.root);
        }
    };
}

test SearchTree {
    var tree = SearchTree().init(std.testing.allocator);
    defer tree.deinit();
}
