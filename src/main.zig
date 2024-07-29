const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const tree = @import("tree.zig");
// const Game = @import("connect6.zig").C6(tree.Player, 19);
const Game = @import("ttt.zig").TicTacToe(tree.Player);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var first = tree.SearchTree(Game, 2).init(allocator);
    first.deinit();

    var second = tree.SearchTree(Game, 2).init(allocator);
    second.deinit();

    var move: Game.Move = undefined;
    while (true) {
        const player = first.root.move.next_player;
        const expantions: usize = if (player == .first) 10 else 10;
        var engine = if (player == .first) &first else &second;
        for (0..expantions) |_| {
            if (engine.root.min_result == engine.root.max_result) {
                print("\nWinner: ", .{});
                engine.root.min_result.print();
                print(" | Selected move: ", .{});
                engine.bestMove().print();
                print("\n", .{});

                // engine.debugPrint("TREE");
                if (debug) engine.root.debugSelfCheck();
                return;
            }
            engine.expand();
        }
        move = engine.bestMove();
        if (first.commitMove(move)) |winner| {
            print("\nWinner {any}\n", .{winner});
            return;
        }
        _ = second.commitMove(move);
        first.printBoard(move);
    }
}

test {
    // std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
