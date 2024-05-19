turn: SearchTree.Player,
board: [9]SearchTree.Player,
prng: Prng,

const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;
// const math = std.math;
// const List = std.ArrayListUnmanaged;
const Prng = std.rand.Random.DefaultPrng;

const Self = @This();
const SearchTree = @import("tree.zig").SearchTree(Self);
const Node = SearchTree.Node;

pub const explore_factor: f32 = 2;
pub const Move = u8;

pub fn init() Self {
    return Self{
        .turn = .first,
        .board = [_]SearchTree.Player{.none} ** 9,
        .prng = Prng.init(0),
    };
}

pub fn make_move(self: *Self, move: Move) void {
    self.board[move] = self.turn;
    if (self.turn == .first) {
        self.turn = .second;
    } else {
        self.turn = .first;
    }
}

pub fn expand(self: Self, allocator: Allocator) void {
    _ = self;
    _ = allocator;
}

fn rollout(self: Self) SearchTree.Player {
    var game = self;
    while (game.select_random_move()) |move| {
        const turn = self.turn;
        game.make_move(move);
        if ((game[0] == turn and game[1] == turn and game[2] == turn) or
            (game[3] == turn and game[4] == turn and game[5] == turn) or
            (game[6] == turn and game[7] == turn and game[8] == turn) or
            (game[0] == turn and game[3] == turn and game[6] == turn) or
            (game[1] == turn and game[4] == turn and game[7] == turn) or
            (game[2] == turn and game[5] == turn and game[8] == turn) or
            (game[0] == turn and game[4] == turn and game[8] == turn) or
            (game[6] == turn and game[4] == turn and game[2] == turn))
        {
            return turn;
        }
    }
    return SearchTree.Player.none;
}

fn select_random_move(self: Self) ?Move {
    var move = null;
    var prob: u64 = 2;
    for (self.board) |place| {
        if (place == .none) {
            if (move == null) {
                move = place;
            } else {
                if (self.prng.next() % prob) {
                    move = place;
                    prob += 1;
                }
            }
        }
    }
    return move;
}

test "TicTacToe" {
    var search_tree = SearchTree().init(std.testing.allocator);
    defer search_tree.deinit();
    try search_tree.expand();
    try search_tree.expand();
    try search_tree.expand();
    print("done", .{});
}
