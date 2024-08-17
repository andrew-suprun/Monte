const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const tree = @import("tree.zig");
const c6 = @import("connect6.zig");
const Game1 = c6.C6(tree.Player, 19, 128);
const Game2 = c6.C6(tree.Player, 19, 128);
const Move = c6.Move(tree.Player);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var first = tree.SearchTree(Game1, Move).init(allocator);
    defer first.deinit();

    var second = tree.SearchTree(Game2, Move).init(allocator);
    defer second.deinit();

    var move = Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    first.makeMove(move);
    second.makeMove(move);

    move = Move{ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
    first.makeMove(move);
    second.makeMove(move);

    while (true) {
        for (0..100_000) |i| {
            if (first.root.min_result == first.root.max_result) {
                print("\n expands.1 {d}", .{i});
                // first.debugPrintChildren();
                break;
            }
            first.expand();
        }
        move = first.bestMove();
        first.makeMove(move);
        second.makeMove(move);
        print("\n----------\nmove: ", .{});
        move.print();
        first.game.printBoard(move);
        // first.debugPrintChildren();
        if (move.winner) |_| break;

        for (0..100_000) |i| {
            if (second.root.min_result == second.root.max_result) {
                print("\n expands.2 {d}", .{i});
                // second.debugPrintChildren();
                break;
            }
            second.expand();
        }
        move = second.bestMove();
        first.makeMove(move);
        second.makeMove(move);
        print("\n----------\nmove: ", .{});
        move.print();
        second.game.printBoard(move);
        // second.debugPrintChildren();
        if (move.winner) |_| break;
    }
    print("\nDONE\n", .{});
}

test {
    // std.testing.refAllDecls(@This());
    std.testing.refAllDeclsRecursive(@This());
}

test "expand" {
    const Tree = tree.SearchTree(Game1, Move, 16);

    var stree = Tree.init(std.testing.allocator);
    defer stree.deinit();

    var move = Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    stree.makeMove(move);

    move = Move{ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
    stree.makeMove(move);

    move = Move{ .places = .{ .{ .x = 8, .y = 10 }, .{ .x = 9, .y = 10 } }, .score = 71, .player = .first };
    stree.makeMove(move);

    move = Move{ .places = .{ .{ .x = 9, .y = 8 }, .{ .x = 7, .y = 10 } }, .score = -87, .player = .second };
    stree.makeMove(move);

    var timer = try std.time.Timer.start();
    for (0..1000) |_| {
        stree.expand();
    }
    print("\ntime {}ms", .{timer.read() / 1_000_000});
    stree.debugSelfCheck();

    print("\n\nbest line\n", .{});
    var buf: [20]Move = undefined;
    const moves = stree.bestLine(&buf);
    for (moves) |m| {
        print("\nmove ", .{});
        m.print();
        stree.makeMove(m);
        stree.game.printBoard(m);
    }

    print("\n\n", .{});
}
