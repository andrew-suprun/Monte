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

        pub const ChildNode = struct {
            move: Game.Move,
            node: Node,

            pub fn init(self: *ChildNode, move: Game.Move, rollout_winner: Player, terminal: bool) Node {
                self.move = move;
                if (rollout_winner == .first) {
                    self.node.first_wins = 1;
                    self.node.second_wins = 0;
                } else if (rollout_winner == .second) {
                    self.node.first_wins = 0;
                    self.node.second_wins = 1;
                }
                self.node.total_rollouts = 1;
                self.node.children = []Node{};
                self.node.move_terminal = terminal;
                self.node.node_complete = false;
            }
        };

        pub const Node = struct {
            first_wins: i32,
            second_wins: i32,
            node_rollouts: i32,
            children: ?[]ChildNode,
            move_terminal: bool,
            node_complete: bool,

            pub fn deinit(self: *Node, allocator: Allocator) void {
                if (self.children) |children| {
                    for (children) |*child| {
                        child.node.deinit(allocator);
                    }
                    allocator.free(self.children.?);
                }
            }
        };

        pub fn init() Self {
            return Self{
                .root = Node{
                    .first_wins = 0,
                    .second_wins = 0,
                    .node_rollouts = 0,
                    .children = null,
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

            var node = &tree.root;
            var path = std.ArrayList(*Node).init(allocator);
            defer path.deinit();

            while (node.children != null) {
                var child_node = selectChild(game, node);
                game.make_move(child_node.move);
                node = &child_node.node;
            }

            game.expand(allocator);

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

        fn selectChild(game: Game, parent: *Node) *ChildNode {
            var selected_child = &parent.children.?[0];
            if (selected_child.node.children == null) return selected_child;

            const parent_roolouts: f32 = @floatFromInt(parent.node_rollouts);
            const big_n = @log(parent_roolouts);

            const child_rollouts: f32 = @floatFromInt(selected_child.node.node_rollouts);
            var score = calc_score(game, &selected_child.node);
            var selected_score = score / parent_roolouts + Game.explore_factor * @sqrt(big_n / child_rollouts);

            for (parent.children.?[1..]) |*child| {
                if (child.node.children == null) return child;

                score = calc_score(game, &child.node);

                if ((game.turn == .first and score > selected_score) or
                    (game.turn == .second and score < selected_score))
                {
                    print("### selectChild.3: selected_node {any}; score {}\n", .{ selected_child, selected_score });
                    selected_score = score;
                    selected_child = child;
                }
            }

            return selected_child;
        }
        inline fn calc_score(game: Game, node: *Node) f32 {
            return if (game.turn == .first)
                @as(f32, @floatFromInt(node.node_rollouts + node.first_wins - node.second_wins))
            else
                @as(f32, @floatFromInt(node.node_rollouts + node.second_wins - node.first_wins));
        }
    };
}
