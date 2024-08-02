const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;
const Prng = std.rand.Random.DefaultPrng;

const tree = @import("tree.zig");
const Game = @import("connect6.zig").C6(tree.Player, 19, 31);
// const Game = @import("ttt.zig").TicTacToe(tree.Player);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var rng = Prng.init(@intCast(std.time.microTimestamp()));

    const Tree = tree.SearchTree(Game, 2);

    var first = Tree.init(allocator);
    first.deinit();

    var second = Tree.init(allocator);
    second.deinit();

    var result: tree.Player = undefined;
    var move: Game.Move = undefined;
    main_loop: while (true) {
        const player = first.game.nextPlayer();
        if (player == .first) {
            for (0..10_000) |_| {
                if (first.root.min_result == first.root.max_result) {
                    result = first.root.min_result;
                    if (debug) first.debugSelfCheck();
                    break :main_loop;
                }
                first.expand();
            }
            move = first.bestMove();
            _ = second.game.makeMove(move);
        } else {
            var places: [2]Game.Place = undefined;
            inline for (0..2) |i| {
                const place = second.game.rolloutPlace(&rng);
                if (place) |p| {
                    places[i] = p;
                    _ = second.game.addStone(p, Game.stoneFromPlayer(.second));
                } else {
                    result = .none;
                    break :main_loop;
                }
            }
            move = Game.Move{
                .player = .second,
                .next_player = .first,
                .places = .{ places[0], places[1] },
            };
        }
        _ = first.commitMove(move);

        if (debug) first.debugSelfCheck();

        print("\n----------\nmove: ", .{});
        move.print();
        first.game.printBoard(move);
        // first.game.printScores(engine.game.scores, "");
        // first.debugPrint();
        // if (result) |winner| {
        //     print("\nWinner {any}\n", .{winner});
        //     break :main_loop;
        // }
    }
    print("\nWinner: {s}", .{Game.playerStr(result)});

    print("\n\n########################\n", .{});

    for (0..10) |_| {
        move = first.bestMove();
        const winner = first.commitMove(move);
        print("\n----------\nmove: ", .{});
        move.print();
        first.game.printBoard(move);
        if (winner != null) break;
    }
    print("\n===\n", .{});
}

test {
    // std.testing.refAllDecls(@This());
    // std.testing.refAllDeclsRecursive(@This()); ???
}
