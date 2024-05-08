const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Prng = std.rand.Random.DefaultPrng;
const Allocator = std.mem.Allocator;
const Pool = @import("std.heap").MemoryPool;
pub const Player = enum(u8) { first = 0x01, second = 0x10, none = 0x00 };
const List = std.ArrayListUnmanaged;

fn Node(comptime Game: type) type {
    return struct {
        child: ?*Node(Game) = null,
        next_sibling: ?*Node(Game) = null,
        n_children: usize = 0,
        score: Game.Score,
        move: Game.Move,
    };
}

fn SearchTree(comptime Game: type) type {
    return struct {
        allocator: Allocator,
        pool: std.heap.MemoryPool(Node(Game)),
        root: *Node(Game),

        pub fn init(allocator: Allocator) SearchTree(Game) {
            var pool = std.heap.MemoryPool(Node(Game)).init(allocator);
            const root = pool.create() catch unreachable;
            root.child = null;
            root.next_sibling = null;
            root.n_children = 0;
            root.score = 0;
            root.move = Game.Move{};

            return SearchTree(Game){
                .allocator = allocator,
                .pool = pool,
                .root = root,
            };
        }

        fn deinit(tree: *SearchTree(Game)) void {
            tree.pool.deinit();
        }

        pub fn expand(tree: *SearchTree(Game)) !void {
            print("### 1\n", .{});
            const game = Game.init(tree.allocator);
            print("### 2\n", .{});

            var leaf = tree.root;
            var turn = Player.first;

            while (leaf.child != null) {
                leaf = selectChild(leaf, turn);
                _ = game.make_move(leaf.move, turn);
                turn = if (turn == .first) .second else .first;
            }

            var score = if (turn == .first) Game.min_score else Game.max_score;
            var leaf_children = game.rollout();
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

        fn selectChild(node: *Node(Game), turn: Player) *Node(Game) {
            print("### 3 node {?any}\n", .{node});
            const big_n = @log(@as(f64, @floatFromInt(node.n_children)));
            print("### 4 node.child {?any}\n", .{node.child});

            var selected_node = node.child.?;
            print("### 5 selected_node {any}\n", .{selected_node});
            var selected_score = @as(f64, @floatFromInt(selected_node.score)) + Game.explore_factor * @sqrt(big_n / @as(f64, @floatFromInt(selected_node.n_children)));
            print("### 6\n", .{});
            if (selected_node.next_sibling == null)
                return selected_node;

            print("### 7\n", .{});
            var maybe_child = node.child.?.next_sibling;
            print("### 8\n", .{});

            while (maybe_child != null) {
                const child = maybe_child.?;
                if (child.n_children == 0) return child;
                const score = @as(f64, @floatFromInt(child.score)) + Game.explore_factor * @sqrt(big_n / @as(f64, @floatFromInt(child.n_children)));
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

const TestGame = struct {
    allocator: Allocator,
    prng: Prng,

    const Move = struct {};
    const Score = u64;
    const explore_factor: f64 = 2.0;
    const min_score: i64 = math.minInt(i64);
    const max_score: i64 = math.maxInt(i64);

    fn init(allocator: Allocator) TestGame {
        print("TestGame.init\n", .{});
        return TestGame{
            .allocator = allocator,
            .prng = Prng.init(0),
        };
    }

    fn make_move(game: TestGame, move: TestGame.Move, turn: Player) void {
        print("TestGame.make_move: move {any} turn {any}\n", .{ move, turn });
        _ = game;
    }

    fn rollout(game: TestGame) std.ArrayListUnmanaged(Node(TestGame)) {
        const moves = game.prng.next() % 5 + 1;
        var result = std.ArrayListUnmanaged(Node(TestGame)).initCapacity(game.allocator, moves) catch unreachable;
        for (0..moves) |_| {
            result.append(game.prng.next() % 10);
        }
        print("TestGame.rollout\n", .{});
        return result;
    }
};

test SearchTree {
    var tree = SearchTree(TestGame).init(std.testing.allocator);
    defer tree.deinit();
    try tree.expand();
}
