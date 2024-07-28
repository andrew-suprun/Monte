const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
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
    print("\nNode size is {d}.\n", .{@sizeOf(@import("node.zig").Node(Game))});
    while (true) {
        const player = first.root.move.next_player;
        print("\nplayer {any}", .{player});
        if (player == .first) {
            for (1..10_000) |i| {
                first.expand();
                if (first.root.min_result == first.root.max_result) {
                    print("\nexpand {d} | Winner {any}\n", .{ i, first.root.min_result });
                    var buf: [10]Game.Move = undefined;
                    const line = first.bestLine(&buf);
                    print("\n best line", .{});
                    for (line) |line_move| {
                        print(" - ", .{});
                        line_move.print();
                    }
                    return;
                }
            }
            move = first.bestMove();
            print("\n>> first move ", .{});
            move.print();
            first.debugPrint("TREE");
        } else {
            if (second.randomMove()) |m| {
                move = m;
                print("\n>> second move ", .{});
                move.print();
            } else {
                print("\nNo more moves", .{});
                return;
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
