const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const tree = @import("tree.zig");
const Game = @import("connect6.zig").C6(tree.Player, 19, 31);
// const Game = @import("ttt.zig").TicTacToe(tree.Player);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const Tree = tree.SearchTree(Game, 2);

    var first = Tree.init(allocator);
    first.deinit();

    var second = Tree.init(allocator);
    second.deinit();

    var move: Game.Move = undefined;
    main_loop: while (true) {
        const player = first.game.nextPlayer();
        const expantions: usize = if (player == .first) 1_000 else 0;
        var engine = if (player == .first) &first else &second;
        for (0..expantions) |_| {
            if (engine.root.min_result == engine.root.max_result) {
                print("\nWinner: {s}", .{Game.playerStr(engine.root.min_result)});

                if (debug) engine.debugSelfCheck();
                break :main_loop;
            }
            engine.expand();
        }
        if (player == .first) {
            move = first.bestMove();
        } else {
            move = second.game.rolloutMove();
        }

        const result = first.commitMove(move);
        _ = second.commitMove(move);
        if (debug) first.debugSelfCheck();

        print("\n----------\nmove: ", .{});
        move.print(player);
        first.game.printBoard(move);
        // first.game.printScores(engine.game.scores, "");
        // first.debugPrint();
        if (result) |winner| {
            print("\nWinner {any}\n", .{winner});
            break :main_loop;
        }
    }

    print("\n\n########################\n", .{});

    for (0..10) |_| {
        move = first.bestMove();
        print("\n----------\nmove {any}", .{move});
        first.game.printBoard(move);
        first.game.printScores(first.game.scores, "");
        first.debugPrint();

        if (first.root.children.len > 0) {
            break;
        }
    }
    print("\n===\n", .{});
}

test {
    // std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
