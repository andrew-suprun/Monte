const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Player = enum { second, none, first };
const Stats = struct {};

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

            fn update_stats(node: *Node, game: Game) void {
                node.first_wins = 0;
                node.second_wins = 0;
                node.n_rollouts = 0;
                node.max_result = .second;
                node.min_result = .first;

                if (game.next_player() == .first) {
                    for (node.children) |child| {
                        node.first_wins += child.first_wins;
                        node.second_wins += child.second_wins;
                        node.n_rollouts += node.children.len;
                        node.max_result = @enumFromInt(@max(@intFromEnum(node.max_result), @intFromEnum(child.max_result)));
                        node.min_result = @enumFromInt(@max(@intFromEnum(node.min_result), @intFromEnum(child.min_result)));
                    }
                } else {
                    for (node.children) |child| {
                        node.first_wins += child.first_wins;
                        node.second_wins += child.second_wins;
                        node.n_rollouts += node.children.len;
                        node.max_result = @enumFromInt(@min(@intFromEnum(node.max_result), @intFromEnum(child.max_result)));
                        node.min_result = @enumFromInt(@min(@intFromEnum(node.min_result), @intFromEnum(child.min_result)));
                    }
                }
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

        fn exand_node(self: *Self, game: *Game, node: *Node) void {
            if (node.children.len > 0) {
                const child = selectChild(game, node);
                _ = game.make_move(child.move);
                self.exand_node(child, game);
                node.update_stats();
            }

            const moves = game.possible_moves(self.allocator);
            defer self.allocator.free(moves);

            node.children = self.allocator.alloc(Node, moves.len);
            for (0..moves.len) |i| {
                node.children[i] = Node(moves[i]);
            }

            for (node.children) |*child| {
                var rollout = game.clone();
                const move_result = rollout.make_move(child.move);
                if (move_result) |result| {
                    child.max_result = result;
                    child.min_result = result;
                    if (move_result == game.previous_player()) {
                        return;
                    }
                }
                switch (game.rollout()) {
                    .first => {
                        node.first_wins += 1;
                        child.first_wins = 1;
                    },
                    .second => {
                        node.second_wins += 1;
                        child.second_wins = 1;
                    },
                }
            }
            node.update_stats();
        }

        fn selectChild(game: Game, parent: *Node) struct { move: Game.Move, node: *Node } {
            var selected_child: ?*Node = null;
            // TODO: Complete

            if (!selected_child.node_complete and selected_child.child_moves.len == 0)
                return .{ .move = Game.Move{}, .node = selected_child };

            const parent_rollouts: f32 = @floatFromInt(parent.n_rollouts);
            const big_n = @log(parent_rollouts);

            const child_rollouts: f32 = @floatFromInt(selected_child.n_rollouts);
            var score = calc_score(game, selected_child);
            var selected_score = score / parent_rollouts + Game.explore_factor * @sqrt(big_n / child_rollouts);

            for (parent.child_moves[1..], parent.children[1..]) |move, *child| {
                if (child.node_complete) continue;
                if (child.child_moves.len == 0)
                    return .{ .move = move, .node = child };

                score = calc_score(game, child);

                if (score > selected_score) {
                    print("### selectChild.3: selected_node {any}; score {}\n", .{ selected_child, selected_score });
                    selected_score = score;
                    selected_child = child;
                }
            }

            return .{ .move = Game.Move{}, .node = selected_child };
        }

        inline fn calc_score(game: Game, node: *Node) f32 {
            return if (game.turn() == .first)
                @as(f32, @floatFromInt(node.n_rollouts + node.first_wins - node.second_wins))
            else
                @as(f32, @floatFromInt(node.n_rollouts + node.second_wins - node.first_wins));
        }
    };
}

test SearchTree {
    var tree = SearchTree().init(std.testing.allocator);
    defer tree.deinit();
}
