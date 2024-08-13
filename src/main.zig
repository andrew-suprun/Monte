const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const tree = @import("tree.zig");
const Game = @import("connect6.zig").C6(tree.Player, 19, 100);
// const Game = @import("ttt.zig").TicTacToe(tree.Player);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const Tree = tree.SearchTree(Game);

    var first = Tree.init(allocator);
    defer first.deinit();

    var second = Tree.init(allocator);
    defer second.deinit();

    var stree: *Tree = undefined;
    const result = main_loop: {
        var move = Game.Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
        first.commitMove(move);
        second.commitMove(move);

        move = Game.Move{ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
        first.commitMove(move);
        second.commitMove(move);

        while (true) {
            for (0..1000) |_| {
                if (first.root.min_result == first.root.max_result) {
                    print("\nfirst ", .{});
                    stree = &first;
                    break :main_loop first.root.min_result;
                }
                first.expand();
            }
            move = first.bestMove();
            // first.debugPrintChildren();
            if (move.winner) |w| break :main_loop w;
            first.commitMove(move);
            second.commitMove(move);
            print("\n----------\nmove: ", .{});
            move.print();
            first.game.printBoard(move);

            for (0..1000) |_| {
                if (second.root.min_result == second.root.max_result) {
                    print("\nsecond ", .{});
                    stree = &second;
                    break :main_loop second.root.min_result;
                }
                second.expand();
            }
            move = second.bestMove();
            if (move.winner) |w| break :main_loop w;
            first.commitMove(move);
            second.commitMove(move);
            print("\n----------\nmove: ", .{});
            move.print();
            second.game.printBoard(move);
        }
    };
    stree.root.debugPrint();
    print("\n\nresult = {s}", .{result.str()});

    // stree.debugPrintChildren();

    var buf: [20]Game.Move = undefined;
    const moves = stree.bestLine(&buf);
    print("\nbest line: moves {d}\n", .{moves.len});
    for (moves) |m| {
        print("\n\nmove ", .{});
        m.print();
        // stree.debugPrintChildren();
        stree.commitMove(m);
        stree.game.printBoard(m);
    }
    print("\nDONE\n", .{});
}

// test {
// std.testing.refAllDecls(@This());
// std.testing.refAllDeclsRecursive(@This()); ???
// }

test "expand" {
    const Tree = tree.SearchTree(Game);

    var stree = Tree.init(std.testing.allocator);
    defer stree.deinit();

    var move = Game.Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    stree.commitMove(move);

    move = Game.Move{ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
    stree.commitMove(move);

    move = Game.Move{ .places = .{ .{ .x = 8, .y = 10 }, .{ .x = 9, .y = 10 } }, .score = 71, .player = .first };
    stree.commitMove(move);

    move = Game.Move{ .places = .{ .{ .x = 9, .y = 8 }, .{ .x = 7, .y = 10 } }, .score = -87, .player = .second };
    stree.commitMove(move);

    for (0..1011) |_| {
        stree.expand();
    }
    stree.root.debugSelfCheckRecursive(stree.game);
    stree.game.printBoard(undefined);
    stree.debugPrintChildren();

    print("\n\nbest line\n", .{});
    var buf: [20]Game.Move = undefined;
    const moves = stree.bestLine(&buf);
    for (moves) |m| {
        print("\nmove ", .{});
        m.print();
        stree.commitMove(m);
        stree.game.printBoard(m);
    }

    print("\n\n", .{});
    stree.debugPrintChildren();
    print("\n", .{});
}
