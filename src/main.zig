const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Game = @import("connect6.zig").C6(19);
// const Game = @import("RandomGame.zig");
// const Game = @import("TicTacToe.zig");

const tree = @import("tree.zig");

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

    var game = Game.init();

    var first = tree.SearchTree(Game){};
    first.deinit(allocator);

    var second = tree.SearchTree(Game){};
    second.deinit(allocator);

    var move: Game.Move = undefined;
    move.player = .first;
    while (true) {
        if (move.player == .first) {
            for (0..1000) |_| {
                if (first.expand(allocator)) |winner| {
                    print("Winner {any}\n", .{winner});
                    break;
                }
            }
            move = first.selectBestMove(.first);
        } else {}
        if (game.makeMove(move)) |winner| {
            print("Winner {any}\n", .{winner});
            break;
        }
    }
}

test {
    std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
