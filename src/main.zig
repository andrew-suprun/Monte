const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const C6 = @import("Connect6.zig");
const Tree = @import("tree.zig").SearchTree(C6);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var tree = Tree.init(allocator);
    defer tree.deinit();

    var game = C6{};

    const mid = C6.board_size / 2;
    var move = C6.Move{ .places = .{ .{ .x = mid, .y = mid }, .{ .x = mid, .y = mid } }, .score = 0, .player = .first };
    tree.makeMove(move);
    game.makeMove(move);

    move = C6.Move{ .places = .{ .{ .x = mid - 1, .y = mid }, .{ .x = mid - 1, .y = mid - 1 } }, .score = 0, .player = .second };
    tree.makeMove(move);
    game.makeMove(move);

    while (true) {
        for (0..100_000) |i| {
            if (tree.root.min_result == tree.root.max_result) {
                print("\n expands.1 n: {d} move: ", .{i});
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

test "expand" {
    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    var game = C6{};

    var move = C6.Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    tree.makeMove(move);
    game.makeMove(move);

    move = C6.Move{ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
    tree.makeMove(move);
    game.makeMove(move);

    move = C6.Move{ .places = .{ .{ .x = 8, .y = 10 }, .{ .x = 9, .y = 10 } }, .score = 71, .player = .first };
    tree.makeMove(move);
    game.makeMove(move);

    move = C6.Move{ .places = .{ .{ .x = 9, .y = 8 }, .{ .x = 7, .y = 10 } }, .score = -87, .player = .second };
    tree.makeMove(move);
    game.makeMove(move);

    var timer = try std.time.Timer.start();
    for (0..1000) |_| {
        if (tree.root.max_result == tree.root.min_result) break;
        tree.expand(&game);
    }
    print("\ntime {}ms", .{timer.read() / 1_000_000});
    tree.debugSelfCheck(game);

    print("\n\nbest line\n", .{});
    var buf: [20]C6.Move = undefined;
    const moves = tree.bestLine(game, &buf);
    for (moves) |m| {
        print("\nmove ", .{});
        m.print();
        tree.makeMove(m);
        game.makeMove(m);
        game.printBoard(m);
    }

    print("\n\n", .{});
}
