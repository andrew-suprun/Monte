const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const tree = @import("tree_b.zig");
const Game = @import("connect6_d.zig").C6(tree.Player, 19, 6);
// const Game = @import("ttt.zig").TicTacToe(tree.Player);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const Tree = tree.SearchTree(Game);

    var first = Tree.init(allocator);
    first.deinit();

    var second = Tree.init(allocator);
    second.deinit();

    const result = main_loop: {
        var move = Game.Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first, .min_result = .second, .max_result = .first };
        first.game.makeMove(move);
        second.game.makeMove(move);

        move = Game.Move{ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second, .min_result = .second, .max_result = .first };
        first.game.makeMove(move);
        second.game.makeMove(move);

        while (true) {
            for (0..1000) |_| {
                if (first.root.min_result == first.root.max_result) {
                    break :main_loop first.root.min_result;
                }
                first.expand();
            }
            move = first.bestMove();
            if (move.max_result == move.min_result) break :main_loop move.max_result;
            first.commitMove(move);
            second.commitMove(move);
            print("\n----------\nmove: ", .{});
            move.print();
            first.game.printBoard(move);
            second.expand();
            move = second.bestMove();
            if (move.max_result == move.min_result) break :main_loop move.max_result;
            first.commitMove(move);
            second.commitMove(move);
            print("\n----------\nmove: ", .{});
            move.print();
            first.game.printBoard(move);
        }
    };
    print("\nresult = {s}", .{result.str()});
}

test {
    // std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
