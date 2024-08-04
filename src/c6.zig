const std = @import("std");
// const Prng = std.rand.Random.DefaultPrng;
const print = std.debug.print;
// const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub fn C6(comptime board_size: comptime_int) type {
    return struct {
        board: Board = [1][board_size]Stone{[1]Stone{.none} ** board_size} ** board_size,
        moves_played: u32 = 1,

        const Self = @This();
        const Stone = enum(u8) { none = 0x00, black = 0x01, white = 0x10 };
        const Board = [board_size][board_size]Stone;
        const Scores = [board_size][board_size]i32;

        pub const Move = struct { x: u8, y: u8 };

        pub fn init() Self {
            var self = Self{};
            _ = self.addStone(Move{
                .x = board_size / 2,
                .y = board_size / 2,
            }, .black);

            return self;
        }

        fn addStone(self: *Self, move: Move, stone: Stone) ?Stone {
            const x = move.x;
            const y = move.y;

            defer self.board[y][x] = stone;

            // ...

            return .none;
        }

        fn testCalcScores(board: Board, comptime stone: Stone) Scores {
            var scores = [1][board_size]i32{[1]i32{0} ** board_size} ** board_size;

            for (0..board_size) |a| {
                var hStones: i32 = @intFromEnum(board[a][0]);
                var vStones: i32 = @intFromEnum(board[0][a]);
                for (1..5) |b| {
                    hStones += @intFromEnum(board[a][b]);
                    vStones += @intFromEnum(board[b][a]);
                }
                for (0..board_size - 5) |b| {
                    hStones += @intFromEnum(board[a][b + 5]);
                    vStones += @intFromEnum(board[b + 5][a]);
                    const eScore = calcScore(stone, hStones);
                    const sScore = calcScore(stone, vStones);
                    inline for (0..6) |c| {
                        scores[a][b + c] += eScore;
                        scores[b + c][a] += sScore;
                    }
                    hStones -= @intFromEnum(board[a][b]);
                    vStones -= @intFromEnum(board[b][a]);
                }
            }

            for (1..board_size - 5) |a| {
                var swStones: i32 = @intFromEnum(board[a][0]);
                var neStones: i32 = @intFromEnum(board[0][a]);
                var nwStones: i32 = @intFromEnum(board[board_size - 1 - a][0]);
                var seStones: i32 = @intFromEnum(board[a][board_size - 1]);
                for (1..5) |b| {
                    swStones += @intFromEnum(board[a + b][b]);
                    neStones += @intFromEnum(board[b][a + b]);
                    nwStones += @intFromEnum(board[board_size - 1 - a - b][b]);
                    seStones += @intFromEnum(board[a + b][board_size - 1 - b]);
                }

                for (0..board_size - 5 - a) |b| {
                    swStones += @intFromEnum(board[a + b + 5][b + 5]);
                    neStones += @intFromEnum(board[b + 5][a + b + 5]);
                    nwStones += @intFromEnum(board[board_size - 6 - a - b][b + 5]);
                    seStones += @intFromEnum(board[a + b + 5][board_size - 6 - b]);
                    const swScore = calcScore(stone, swStones);
                    const neScore = calcScore(stone, neStones);
                    const nwScore = calcScore(stone, nwStones);
                    const seScore = calcScore(stone, seStones);
                    inline for (0..6) |c| {
                        scores[a + b + c][b + c] += swScore;
                        scores[b + c][a + b + c] += neScore;
                        scores[board_size - 1 - a - b - c][b + c] += nwScore;
                        scores[a + b + c][board_size - 1 - b - c] += seScore;
                    }
                    swStones -= @intFromEnum(board[a + b][b]);
                    neStones -= @intFromEnum(board[b][a + b]);
                    nwStones -= @intFromEnum(board[board_size - 1 - a - b][b]);
                    seStones -= @intFromEnum(board[a + b][board_size - 1 - b]);
                }
            }
            var nwseStones: i32 = @intFromEnum(board[0][0]);
            var neswStones: i32 = @intFromEnum(board[0][board_size - 1]);
            for (1..5) |a| {
                nwseStones += @intFromEnum(board[a][a]);
                neswStones += @intFromEnum(board[a][board_size - 1 - a]);
            }
            for (0..board_size - 5) |b| {
                nwseStones += @intFromEnum(board[b + 5][b + 5]);
                neswStones += @intFromEnum(board[b + 5][board_size - 6 - b]);
                const nwseScore = calcScore(stone, nwseStones);
                const neswScore = calcScore(stone, neswStones);
                inline for (0..6) |c| {
                    scores[b + c][b + c] += nwseScore;
                    scores[b + c][board_size - 1 - b - c] += neswScore;
                }
                nwseStones -= @intFromEnum(board[b][b]);
                neswStones -= @intFromEnum(board[b][board_size - 1 - b]);
            }
            return scores;
        }

        // TODO: fine-tune this
        const one_stone = 1;
        const two_stones = 3;
        const three_stones = 7;
        const four_stones = 31;
        const five_stones = 63;
        const six_stones = 1024;

        // const one_stone = 1;
        // const two_stones = 2;
        // const three_stones = 4;
        // const four_stones = 8;
        // const five_stones = 32;
        // const six_stones = 1024;

        fn calcScore(comptime stone: Stone, stones: i32) i32 {
            return if (stone == .black)
                switch (stones) {
                    0x00 => one_stone,
                    0x01 => two_stones - one_stone,
                    0x02 => three_stones - two_stones,
                    0x03 => four_stones - three_stones,
                    0x04 => five_stones - four_stones,
                    0x05 => five_stones - four_stones,
                    0x10 => one_stone,
                    0x20 => two_stones,
                    0x30 => three_stones,
                    0x40 => four_stones,
                    0x50 => five_stones,
                    else => 0,
                }
            else switch (stones) {
                0x00 => -one_stone,
                0x01 => -one_stone,
                0x02 => -two_stones,
                0x03 => -three_stones,
                0x04 => -four_stones,
                0x05 => -five_stones,
                0x10 => one_stone - two_stones,
                0x20 => two_stones - three_stones,
                0x30 => three_stones - four_stones,
                0x40 => four_stones - five_stones,
                0x50 => five_stones - six_stones,
                else => 0,
            };
        }

        pub fn printScores(self: Self, scores: Scores) void {
            print("\n\n", .{});
            print("\n   |   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18 |", .{});
            print("\n---+-----------------------------------------------------------------------------+---", .{});
            for (scores, 0..) |row, y| {
                print("\n{:2} |", .{y});
                for (row, 0..) |score, x| {
                    switch (self.board[y][x]) {
                        .black => print("   X", .{}),
                        .white => print("   O", .{}),
                        else => if (score != 0) print("{:4}", .{@as(i32, @intCast(score))}) else print("   .", .{}),
                    }
                }
                print(" |", .{});
            }
            print("\n---+-----------------------------------------------------------------------------+---", .{});
            print("\n   |   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18 |\n", .{});
        }

        pub fn printBoard(self: Self, move: Move) void {
            print("\n   |", .{});
            for (0..board_size) |i| {
                print("{:2}", .{i % 10});
            }
            print(" |", .{});

            print("\n---+", .{});
            for (0..board_size) |_| {
                print("--", .{});
            }
            print("-+---", .{});

            for (0..board_size) |y| {
                print("\n{:2} |", .{y});
                for (0..board_size) |x| {
                    switch (self.board[y][x]) {
                        .black => if (move.x == x and move.y == y) print(" #", .{}) else print(" X", .{}),
                        .white => if (move.x == x and move.y == y) print(" @", .{}) else print(" O", .{}),
                        else => print(" .", .{}),
                    }
                }
                print(" | {:2}", .{y});
            }

            print("\n---+", .{});
            for (0..board_size) |_| {
                print("--", .{});
            }
            print("-+---", .{});

            print("\n   |", .{});
            for (0..board_size) |i| {
                print("{:2}", .{i % 10});
            }
            print(" |", .{});
        }
    };
}

test C6 {
    const Game = C6(19);
    var c6 = Game.init();
    // _ = c6.addStone(Game.Move{ .x = 8, .y = 9 }, .white);
    // _ = c6.addStone(Game.Move{ .x = 8, .y = 8 }, .white);
    _ = c6.addStone(Game.Move{ .x = 8, .y = 9 }, .black);
    c6.printBoard(Game.Move{ .x = 0, .y = 0 });

    const scoresX = Game.testCalcScores(c6.board, .black);
    c6.printScores(scoresX);
    const scoresO = Game.testCalcScores(c6.board, .white);
    c6.printScores(scoresO);
}
