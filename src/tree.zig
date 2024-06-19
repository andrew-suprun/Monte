const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const List = std.ArrayListUnmanaged;
const print = std.debug.print;

pub fn SearchTree(comptime Game: type) type {
    return struct {
        root: Node,

        const Self = SearchTree(Game);

        pub const Player = enum { none, first, second };

        pub const Node = struct {
            child_moves: []Game.Move,
            child_nodes: []Node,
            first_wins: i32,
            second_wins: i32,
            n_rollouts: i32,
            move_terminal: bool,
            node_complete: bool,

            pub fn deinit(self: *Node, allocator: Allocator) void {
                for (self.child_nodes) |*child| {
                    child.deinit(allocator);
                }
                allocator.free(self.child_moves);
                allocator.free(self.child_nodes);
            }
        };

        pub fn init() Self {
            return Self{
                .root = Node{
                    .child_moves = &[_]Game.Move{},
                    .child_nodes = &[_]Node{},
                    .first_wins = 0,
                    .second_wins = 0,
                    .n_rollouts = 0,
                    .move_terminal = false,
                    .node_complete = false,
                },
            };
        }

        pub fn deinit(tree: *Self, allocator: Allocator) void {
            tree.root.deinit(allocator);
        }

        pub fn expand(tree: *Self, allocator: Allocator) !void {
            var game = Game.init();

            var path = std.ArrayList(Game.Move).init(allocator);
            defer path.deinit();

            var node = &tree.root;
            while (node.child_nodes.len != 0) {
                const child = selectChild(game, node);
                game.make_move(child.move);
                node = child.node;
                path.append(child.move) catch unreachable;
            }

            const moves = game.possible_moves();
            _ = moves;

            // game.expand(allocator);

            // const n_children = node.child_nodes.?.len;

            // TODO: backpropagation

            // var best_child_score = if (game.turn == .first) math.floatMin(f32) else math.floatMax(f32);
            // node.n_descendants = descendants;
            // for (node.children) |child| {
            //     if ((game.turn == .first and best_child_score < child.move.score) or
            //         (game.turn == .second and best_child_score > child.move.score))
            //     {
            //         best_child_score = child.move.score;
            //     }
            // }

            // node.score = best_child_score;
        }

        fn selectChild(game: Game, parent: *Node) struct { move: Game.Move, node: *Node } {
            var selected_child = &parent.child_nodes[0];
            var selected_move = parent.child_moves[0];
            if (!selected_child.node_complete and selected_child.child_moves.len == 0)
                return .{ .move = selected_move, .node = selected_child };

            const parent_rollouts: f32 = @floatFromInt(parent.n_rollouts);
            const big_n = @log(parent_rollouts);

            const child_rollouts: f32 = @floatFromInt(selected_child.n_rollouts);
            var score = calc_score(game, selected_child);
            var selected_score = score / parent_rollouts + Game.explore_factor * @sqrt(big_n / child_rollouts);

            for (parent.child_moves[1..], parent.child_nodes[1..]) |move, *child| {
                if (child.node_complete) continue;
                if (child.child_moves.len == 0)
                    return .{ .move = move, .node = child };

                score = calc_score(game, child);

                if (score > selected_score) {
                    print("### selectChild.3: selected_node {any}; score {}\n", .{ selected_child, selected_score });
                    selected_score = score;
                    selected_move = move;
                    selected_child = child;
                }
            }

            return .{ .move = selected_move, .node = selected_child };
        }

        inline fn calc_score(game: Game, node: *Node) f32 {
            return if (game.turn() == .first)
                @as(f32, @floatFromInt(node.n_rollouts + node.first_wins - node.second_wins))
            else
                @as(f32, @floatFromInt(node.n_rollouts + node.second_wins - node.first_wins));
        }

        const Expander = struct {
            node: *Node,

            pub fn next(self: Expander, move: ?Game.Move) void {
                _ = self;
                print("move {any}\n", .{move});
            }
        };
    };
}
