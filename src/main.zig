const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const tree = @import("tree.zig");
const Game = @import("connect6.zig").C6(tree.Player, 19);
// const Game = @import("ttt.zig").TicTacToe(tree.Player);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var first = tree.SearchTree(Game, 2).init(allocator);
    first.deinit();

    var second = tree.SearchTree(Game, 2).init(allocator);
    second.deinit();

    var move: Game.Move = undefined;
    main_loop: while (true) {
        const player = first.game.nextPlayer();
        const expantions: usize = if (player == .first) 1000 else 0;
        var engine = if (player == .first) &first else &second;
        for (0..expantions) |_| {
            if (engine.root.min_result == engine.root.max_result) {
                print("\nWinner: {s}", .{Game.playerStr(engine.root.min_result)});

                // engine.debugPrint("TREE");
                if (debug) engine.debugSelfCheck();
                break :main_loop;
            }
            engine.expand();
        }
        if (player == .first) {
            move = engine.bestMove();
        } else {
            move = engine.game.rolloutMove();
        }
        if (first.commitMove(move)) |winner| {
            print("\nWinner {any}\n", .{winner});
            break :main_loop;
        }
        _ = second.commitMove(move);
        first.game.printBoard(move);
    }

    print("\n\n########################\n", .{});

    for (0..3) |_| {
        // while (first.root.children.len > 0) {
        move = first.bestMove();
        print("\nmove {any}", .{move});
        _ = first.commitMove(move);
        first.game.printBoard(move);
    }
}

test {
    // std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
