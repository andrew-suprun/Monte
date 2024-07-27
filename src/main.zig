const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const tree = @import("tree.zig");
// const Game = @import("connect6.zig").C6(tree.Player, 19);
// const Game = @import("RandomGame.zig");
const Game = @import("TicTacToe.zig");

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
        if (first.nextPlayer() == .first) {
            for (0..10_000) |_| {
                if (first.expand()) |winner| {
                    print("\nWinner {any}\n", .{winner});
                    break;
                }
            }
            move = first.bestMove(.first);
            print("\n>> first move {any}", .{move});
        } else {
            if (second.randomMove()) |m| {
                move = m;
                print("\n>> second move {any}", .{move});
            } else {
                print("\nNo more moves", .{});
                break;
            }
        }
        first.commitMove(move);
        second.commitMove(move);
        first.printBoard(move);
    }
}

test {
    std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
