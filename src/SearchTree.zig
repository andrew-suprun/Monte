allocator: Allocator,
pool: Pool,
capacity: usize,
size: usize = 0,
scores: Scores = Scores.empty_scores.clone(),
root: *Node,

const SearchTree = @This();
const std = @import("std");
const Scores = @import("Scores.zig");
const math = std.math;
const Pool = std.heap.MemoryPool(Node);
const BoardSize = Scores.BoardSize;
const Player = Scores.Player;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const Move = struct { x1: u8, y1: u8, x2: u8, y2: u8 };
const Node = struct {
    child: ?*Node,
    nextSibling: ?*Node,
    move: Move,
    first_wins: u32 = 0,
    second_wins: u32 = 0,
    draws: u32 = 0,
};

pub fn init(allocator: Allocator, capacity: usize) SearchTree {
    var pool = Pool.init(allocator);
    var root = pool.create() catch unreachable;
    root.child = null;
    root.nextSibling = null;
    root.move = .{ .x1 = 9, .y1 = 9, .x2 = 9, .y2 = 9 };
    root.first_wins = 0;
    root.second_wins = 0;
    root.draws = 0;
    return SearchTree{
        .allocator = allocator,
        .pool = pool,
        .capacity = capacity,
        .root = root,
    };
}

pub fn deinit(tree: *SearchTree) void {
    tree.pool.deinit();
}

pub fn expand(tree: *SearchTree) !void {
    var scores = tree.scores.clone();
    tree.scores.print_scores();

    const leaf = tree.selectLeaf(&scores);
    print("{any}\n", .{leaf});

    // var scores = board.calc_scores();

    // var player: Player = .first;
    // var places_to_consider = std.AutoHashMap(Coord, void).init(tree.allocator);
    // try add_places_to_consider(Coord{ .x = BoardSize / 2, .y = BoardSize / 2 }, &places_to_consider);

    // for (moves) |m| {
    //     board.places[m[0].x][m[0].y] = player;
    //     board.places[m[1].x][m[1].y] = player;

    //     try add_places_to_consider(m[0], &places_to_consider);
    //     try add_places_to_consider(m[1], &places_to_consider);

    //     player = if (player == .first) .second else .first;
    // }

    // for (moves) |m| {
    //     _ = places_to_consider.remove(m[0]);
    //     _ = places_to_consider.remove(m[1]);
    // }
    // _ = places_to_consider.remove(.{ .x = BoardSize / 2, .y = BoardSize / 2 });

    // var places = try std.ArrayList(Coord).initCapacity(allocator, places_to_consider.count());
    // var iter = places_to_consider.keyIterator();
    // while (iter.next()) |place| {
    //     print("place: {}\n", .{place.*});
    //     try places.append(place.*);
    // }
    // print("places = {any}\n\n\n", .{places.items});

    // const scores = calc_scores(&board);

    // var j: Score = 1;
    // for (places.items[0 .. places.items.len - 1], 1..) |one, i| {
    //     for (places.items[i..]) |two| {
    //         print("expand {} {}:{} - {}:{}\n", .{ j, one.x, one.y, two.x, two.y });
    //         j += 1;
    //         _ = rollout(board, scores, player, one, two);
    //     }
    //     print("\n", .{});
    // }

}

fn selectLeaf(tree: SearchTree, scores: *Scores) *Node {
    var node: *Node = tree.root;

    while (node.child != null) {
        node = selectChild(node, scores.turn);
        _ = scores.make_move(.{ .{ .x = node.move.x1, .y = node.move.y1 }, .{ .x = node.move.x2, .y = node.move.y2 } });
    }
    return node;
}

fn selectChild(node: *Node, turn: Player) *Node {
    var min_selection_score: u32 = math.maxInt(u32);
    var child_node = node.child;
    var selected_node = child_node.?;
    if (turn == .first) {
        while (child_node != null) {
            const child = child_node.?;
            const selection_score = child.first_wins + 2 * child.draws + 3 * child.second_wins;
            if (min_selection_score > selection_score) {
                min_selection_score = selection_score;
                selected_node = child;
            }
            child_node = child.nextSibling;
        }
    } else {
        while (child_node != null) {
            const child = child_node.?;
            const selection_score = 3 * child.first_wins + 2 * child.draws + child.second_wins;
            if (min_selection_score > selection_score) {
                min_selection_score = selection_score;
                selected_node = child;
            }
            child_node = child.nextSibling;
        }
    }
    return selected_node;
}
