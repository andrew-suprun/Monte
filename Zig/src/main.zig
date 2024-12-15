const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

const C6 = @import("Connect6.zig");
const Tree = @import("tree.zig").SearchTree(C6);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var tree = Tree.init(allocator);
    defer tree.deinit();

    var game = C6{};
    var move = try game.initMove("j10+j10");
    tree.makeMove(&game, move);
    move = try game.initMove("i9+i11");
    tree.makeMove(&game, move);
    game.printBoard();

    while (true) {
        for (0..10_000) |i| {
            if (tree.root.conclusive) {
                std.debug.print("\nexpand n: {d} score: {d}", .{ i, tree.root.score });
                break;
            }
            tree.expand(&game);
        }
        move = tree.bestNode().move;
        std.debug.print("\n", .{});
        move.print();
        tree.root.debugPrintChildren();
        tree.makeMove(&game, move);
        game.printBoard();
        if (!move.terminal) break;
    }
    std.debug.print("\nDONE\n", .{});
}

test {
    // std.testing.refAllDecls(@This());
    std.testing.refAllDeclsRecursive(@This());
}

test "makeMove" {
    const Prng = std.rand.Random.DefaultPrng;
    var rng = Prng.init(1);

    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    var game = C6{};
    var move = try game.initMove("j10+j10");
    tree.makeMove(&game, move);

    for (0..30) |_| {
        var places: [2]C6.Place = undefined;
        var selected: usize = 0;
        while (selected < 2) {
            const x = rng.next() % C6.board_size;
            const y = rng.next() % C6.board_size;
            if (game.board[y][x] != .none) continue;
            places[selected] = C6.Place.init(x, y);
            selected += 1;
        }

        move = game.initMoveFromPlaces(places[0], places[1]);
        tree.makeMove(&game, move);

        tree.debugSelfCheck(game);
    }
    game.printBoard();
}

test "expand" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    var game = C6{};
    var move = try game.initMove("j10+j10");
    tree.makeMove(&game, move);
    std.debug.print("\nacc = {d}\n", .{tree.acc});

    move = try game.initMove("i9+i11");
    tree.makeMove(&game, move);
    std.debug.print("acc = {d}\n", .{tree.acc});

    for (0..30) |i| {
        tree.expand(&game);
        std.debug.print("\n----\n expand {}", .{i});
        tree.debugPrint();
        tree.debugSelfCheck(game);
    }
}
