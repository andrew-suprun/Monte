const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Pool = @import("std.heap").MemoryPool;
pub const Player = enum(u8) { first = 0x01, second = 0x10, none = 0x00 };
const List = std.ArrayListUnmanaged;

fn Node(comptime Policy: type) type {
    return struct {
        child: ?*Node(Policy) = null,
        next_sibling: ?*Node(Policy) = null,
        n_children: usize = 0,
        score: Policy.Score,
        move: Policy.Move,
    };
}

fn SearchTree(comptime Policy: type) type {
    return struct {
        allocator: Allocator,
        pool: std.heap.MemoryPool(Node(Policy)),
        root: *Node(Policy),

        pub fn init(allocator: Allocator) SearchTree(Policy) {
            var pool = std.heap.MemoryPool(Node(Policy)).init(allocator);
            const root = pool.create() catch unreachable;
            root.child = null;
            root.next_sibling = null;
            root.n_children = 0;
            root.score = 0;
            root.move = Policy.Move{};

            return SearchTree(Policy){
                .allocator = allocator,
                .pool = pool,
                .root = root,
            };
        }

        fn deinit(tree: *SearchTree(Policy)) void {
            print("type {}\n", .{@TypeOf(tree.pool)});
            tree.pool.deinit();
        }

        pub fn expand(tree: *SearchTree(Policy)) !void {
            print("### 1\n", .{});
            const policy = Policy.init(tree.allocator);
            print("### 2\n", .{});

            var leaf = tree.root;
            var turn = Player.first;

            while (leaf.child != null) {
                leaf = selectChild(leaf, turn);
                _ = policy.make_move(leaf.move, turn);
                turn = if (turn == .first) .second else .first;
            }

            var score = if (turn == .first) Policy.min_score else Policy.max_score;
            var leaf_children = policy.rollout();
            defer leaf_children.deinit(tree.allocator);
            leaf.n_children = leaf_children.items.len;
            for (leaf_children.items) |child| {
                if ((turn == .first and score < child.score) or (turn == .second and score < child.score)) {
                    score = child.score;
                }
            }
            leaf.score = score;
            // TODO: propagate to the root
        }

        fn selectChild(node: *Node(Policy), turn: Player) *Node(Policy) {
            print("### 3 node {?any}\n", .{node});
            const big_n = @log(@as(f64, @floatFromInt(node.n_children)));
            print("### 4 node.child {?any}\n", .{node.child});

            var selected_node = node.child.?;
            print("### 5 selected_node {any}\n", .{selected_node});
            var selected_score = @as(f64, @floatFromInt(selected_node.score)) + Policy.explore_factor * @sqrt(big_n / @as(f64, @floatFromInt(selected_node.n_children)));
            print("### 6\n", .{});
            if (selected_node.next_sibling == null)
                return selected_node;

            print("### 7\n", .{});
            var maybe_child = node.child.?.next_sibling;
            print("### 8\n", .{});

            while (maybe_child != null) {
                const child = maybe_child.?;
                if (child.n_children == 0) return child;
                const score = @as(f64, @floatFromInt(child.score)) + Policy.explore_factor * @sqrt(big_n / @as(f64, @floatFromInt(child.n_children)));
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

const TestPolicy = struct {
    allocator: Allocator,

    const Move = struct {};
    const Score = i64;
    const explore_factor: f64 = 2.0;
    const min_score: i64 = math.minInt(i64);
    const max_score: i64 = math.maxInt(i64);

    fn init(allocator: Allocator) TestPolicy {
        return TestPolicy{
            .allocator = allocator,
        };
    }

    fn make_move(policy: TestPolicy, move: TestPolicy.Move, turn: Player) void {
        _ = policy;
        _ = move;
        _ = turn;
    }

    fn rollout(policy: TestPolicy) std.ArrayListUnmanaged(Node(TestPolicy)) {
        return List(Node(TestPolicy)).initCapacity(policy.allocator, 0) catch unreachable;
    }
};

test SearchTree {
    var tree = SearchTree(TestPolicy).init(std.testing.allocator);
    defer tree.deinit();
    try tree.expand();
}
