const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Pool = @import("std.heap").MemoryPool;
pub const Player = enum(u8) { first = 0x01, second = 0x10, none = 0x00 };
const List = std.ArrayListUnmanaged;

pub fn SearchTree(comptime Game: type) type {
    return struct {
        allocator: Allocator,
        pool: std.heap.MemoryPool(Node),
        root: *Node,

        const Self = @This();

        pub const Node = struct {
            child: ?*Node = null,
            next_sibling: ?*Node = null,
            n_descendants: f32 = 0,
            move: Game.Move,
        };

        pub fn init(allocator: Allocator) Self {
            var pool = std.heap.MemoryPool(Node).init(allocator);
            const root = pool.create() catch unreachable;
            root.child = null;
            root.next_sibling = null;
            root.n_descendants = 0;
            root.move = Game.Move{ .score = 0 };

            return Self{
                .allocator = allocator,
                .pool = pool,
                .root = root,
            };
        }

        pub fn deinit(tree: *Self) void {
            tree.pool.deinit();
        }

        pub fn expand(tree: *Self) !void {
            print("### 1\n", .{});
            const game = Game.init(tree.allocator);
            print("### 2\n", .{});

            var leaf = tree.root;
            var turn = Player.first;
            var path = std.ArrayList(*Node).init(tree.allocator);
            defer path.deinit();

            while (leaf.child != null) {
                leaf = selectChild(leaf, turn);
                _ = game.make_move(leaf.move, turn);
                turn = if (turn == .first) .second else .first;
            }

            var score = if (turn == .first) math.floatMin(f32) else math.floatMax(f32);
            var leaf_children = game.rollout();
            defer leaf_children.deinit(tree.allocator);
            const descendants = @as(f32, @floatFromInt(leaf_children.items.len));
            leaf.n_descendants = descendants;
            for (leaf_children.items) |child| {
                if ((turn == .first and score < child.move.score) or (turn == .second and score < child.move.score)) {
                    score = child.move.score;
                }
            }

            leaf.move.score = score;
            // TODO: propagate to the root
        }

        fn selectChild(node: *Node, turn: Player) *Node {
            print("### 3 node {?any}\n", .{node});

            var selected_node = node.child.?;
            if (selected_node.n_descendants == 0) return selected_node;
            print("### 5 selected_node {any}\n", .{selected_node});
            var selected_score = selected_node.move.score + Game.explore_factor * @sqrt(node.n_descendants / selected_node.n_descendants);
            print("### 6\n", .{});
            if (selected_node.next_sibling == null)
                return selected_node;

            print("### 7\n", .{});
            var maybe_child = node.child.?.next_sibling;
            print("### 8\n", .{});

            while (maybe_child != null) {
                const child = maybe_child.?;
                if (child.n_descendants == 0) return child;
                const score = child.move.score + Game.explore_factor * @sqrt(node.n_descendants / child.n_descendants);
                if ((turn == .first and score > selected_score) or (turn == .second and score < selected_score)) {
                    selected_score = score;
                    selected_node = child;
                }
                maybe_child = child.next_sibling;
            }

            return selected_node;
        }
    };
}
