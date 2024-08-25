const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;

const C6 = @import("Connect6.zig");
const Tree = @import("tree.zig").SearchTree(C6);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var tree = Tree.init(allocator);
    defer tree.deinit();

    var game = C6.init();

    const mid = C6.board_size / 2;
    var move = C6.Move{ .places = .{ .{ .x = mid, .y = mid }, .{ .x = mid, .y = mid } }, .score = 0, .player = .first };
    tree.makeMove(move);
    game.makeMove(move);

    // move = C6.Move{ .places = .{ .{ .x = mid - 1, .y = mid }, .{ .x = mid - 1, .y = mid - 1 } }, .score = 0, .player = .second };
    // tree.makeMove(move);
    // game.makeMove(move);

    while (true) {
        for (0..100_000) |i| {
            if (tree.root.min_result == tree.root.max_result) {
                print("\nexpand n: {d} winner: {s} move: ", .{ i, tree.root.max_result.str() });
                move.print();
                tree.debugPrintChildren();
                print("\n", .{});
                break;
            }
            tree.expand(&game);
        }
        move = tree.bestMove();
        tree.makeMove(move);
        game.makeMove(move);
        move.print();
        game.printBoard(move);
        if (move.winner) |_| break;
    }
    print("\nDONE\n", .{});
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

    var game = C6.init();

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

        const move = game.initMoveFromPlaces(places);
        tree.makeMove(move);
        game.makeMove(move);

        tree.debugSelfCheck(game);
    }
    game.printBoard(game.initMoveFromPlaces(.{ C6.Place.init(5, 5), C6.Place.init(9, 9) }));
}

test "expand" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    var game = C6.init();

    const move = game.initMoveFromPlaces(.{ C6.Place.init(5, 5), C6.Place.init(5, 5) });
    print("\n move: ", .{});
    move.print();
    tree.makeMove(move);
    game.makeMove(move);
    game.printBoard(move);

    for (0..30) |i| {
        tree.expand(&game);
        print("\n----\n expand {}", .{i});
        tree.debugPrint();
        tree.debugSelfCheck(game);
    }
    game.printBoard(game.initMoveFromPlaces(.{ C6.Place.init(5, 5), C6.Place.init(9, 9) }));
}
