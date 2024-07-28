const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const tree = @import("tree.zig");
// const Game = @import("connect6.zig").C6(tree.Player, 19);
// const Game = @import("RandomGame.zig");
const Game = @import("ttt.zig").TicTacToe(tree.Player);

// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();

//     var search_tree = tree.SearchTree(c6.C6(19)).init();
//     defer search_tree.deinit(allocator);

//     try search_tree.expand(allocator);
// }

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var first = tree.SearchTree(Game).init(allocator);
    first.deinit();

    var second = tree.SearchTree(Game).init(allocator);
    second.deinit();

    var move: Game.Move = undefined;
    while (true) {
        const player = first.root.move.next_player;
        if (player == .first) {
            // first.debugPrint("TREE.1");
            for (0..10_000) |i| {
                if (first.root.min_result == first.root.max_result) {
                    print("\nexpand {d} | Result {any}\n", .{ i, first.root.min_result });
                    print("\n selected move: ", .{});
                    first.bestMove().print();

                    // first.debugPrint("TREE");
                    if (debug) first.root.debugSelfCheck();
                    return;
                }
                first.expand();
            }
            move = first.bestMove();
        } else {
            if (second.randomMove()) |m| {
                move = m;
            } else {
                print("\nNo more moves", .{});
            }
        }
        if (first.commitMove(move)) |winner| {
            print("\nWinner {any}\n", .{winner});
        }
        _ = second.commitMove(move);
        first.printBoard(move);
    }
}

test {
    std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
