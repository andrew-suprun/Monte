const std = @import("std");
const Prng = std.rand.Random.DefaultPrng;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub fn C6(comptime Player: type, comptime board_size: usize) type {
    return struct {
        board: Board,
        scores: Scores,
        move_number: u32,

        pub const Stone = enum(u8) { none = 0x00, black = 0x01, white = 0x10 };
        pub const Move = struct {
            x: u8,
            y: u8,

            pub inline fn eql(self: @This(), other: @This()) bool {
                return self.x == other.x and self.y == other.y;
            }
        };
        pub const max_moves: usize = 32;
        pub const explore_factor: f32 = 2;

        const Self = @This();
        const Board = [board_size][board_size]Stone;
        const Scores = [board_size][board_size]i32;
        const Heap = @import("heap.zig").Heap(Move, Scores, cmp, max_moves);

        fn cmp(scores: Scores, a: Move, b: Move) bool {
            return scores[a.y][a.x] < scores[b.y][b.x];
        }

        pub fn init() Self {
            var self = Self{
                .board = [1][board_size]Stone{[1]Stone{.none} ** board_size} ** board_size,
                .scores = [1][board_size]i32{[1]i32{0} ** board_size} ** board_size,
                .move_number = 0,
            };
            calcScores(self.board, &self.scores);
            _ = self.makeMove(Move{ .x = board_size / 2, .y = board_size / 2 });

            return self;
        }

        pub fn possibleMoves(self: Self, buf: []Move) []Move {
            var heap = Heap.init(self.scores);

            for (0..board_size) |y| {
                for (0..board_size) |x| {
                    if (self.board[y][x] == .none) {
                        heap.add(.{ .x = @intCast(x), .y = @intCast(y) });
                    }
                }
            }

            return heap.sorted(buf);
        }

        pub fn makeMove(self: *Self, move: Move) ?Player {
            const x = move.x;
            const y = move.y;
            const stone = self.nextStone();
            var check_scores = true;
            defer if (debug and check_scores) self.testScores();

            {
                const start_x: usize = @max(x, 5) - 5;
                const end_x: usize = @min(x + 1, board_size - 5);
                var stones: i32 = @intFromEnum(self.board[y][start_x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[y][start_x + i]);
                }
                for (start_x..end_x) |dx| {
                    stones += @intFromEnum(self.board[y][dx + 5]);
                    const d = calcDelta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return playerFromStone(d.winner);
                    }
                    inline for (0..6) |c| {
                        self.scores[y][dx + c] += d.score;
                    }
                    stones -= @intFromEnum(self.board[y][dx]);
                }
            }

            {
                const start_y: usize = @max(y, 5) - 5;
                const end_y: usize = @min(y + 1, board_size - 5);
                var stones: i32 = @intFromEnum(self.board[start_y][x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[start_y + i][x]);
                }
                for (start_y..end_y) |dy| {
                    stones += @intFromEnum(self.board[dy + 5][x]);
                    const d = calcDelta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return playerFromStone(d.winner);
                    }
                    inline for (0..6) |c| {
                        self.scores[dy + c][x] += d.score;
                    }
                    stones -= @intFromEnum(self.board[dy][x]);
                }
            }

            b1: {
                const min: usize = @min(x, y, 5);
                const max: usize = @max(x, y);

                if (max - min >= board_size - 5) break :b1;

                const start_x = x - min;
                const start_y = y - min;
                const count = @min(min + 1, board_size - max, board_size - 5 + min - max);

                var stones: i32 = @intFromEnum(self.board[start_y][start_x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[start_y + i][start_x + i]);
                }
                for (start_x.., start_y.., 0..count) |xx, yy, _| {
                    stones += @intFromEnum(self.board[yy + 5][xx + 5]);
                    const d = calcDelta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return playerFromStone(d.winner);
                    }
                    inline for (0..6) |e| {
                        self.scores[yy + e][xx + e] += d.score;
                    }
                    stones -= @intFromEnum(self.board[yy][xx]);
                }
            }

            b2: {
                const rev_x = board_size - 1 - x;
                const min: usize = @min(rev_x, y, 5);
                const max: usize = @max(rev_x, y);

                if (max - min >= board_size - 5) break :b2;

                const start_x = x + min;
                const start_y = y - min;
                const count = @min(min + 1, board_size - max, board_size - 5 + min - max);

                var stones: i32 = @intFromEnum(self.board[start_y][start_x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[start_y + i][start_x - i]);
                }
                for (0..count) |c| {
                    stones += @intFromEnum(self.board[start_y + 5 + c][start_x - 5 - c]);
                    const d = calcDelta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return playerFromStone(d.winner);
                    }
                    inline for (0..6) |e| {
                        self.scores[start_y + c + e][start_x - c - e] += d.score;
                    }
                    stones -= @intFromEnum(self.board[start_y + c][start_x - c]);
                }
            }

            self.board[y][x] = stone;
            self.move_number += 1;
            return null;
        }

        pub fn rollout(self: *Self) Player {
            while (true) {
                if (self.randomMove()) |place| {
                    if (self.makeMove(place)) |winner| return winner;
                } else {
                    return .none;
                }
            }
        }

        inline fn nextStone(self: Self) Stone {
            return if ((self.move_number + 3) & 2 == 2) .black else .white;
        }

        pub inline fn nextPlayer(self: Self) Player {
            return playerFromStone(self.nextStone());
        }

        inline fn playerFromStone(stone: Stone) Player {
            return switch (stone) {
                .none => .none,
                .black => .first,
                .white => .second,
            };
        }

        pub fn randomMove(self: Self) ?Move {
            var rand = Prng.init(@intCast(std.time.milliTimestamp()));

            var best_move = Move{ .x = 0, .y = 0 };
            var best_score: i32 = 0;
            var prob: u64 = 2;
            for (0..board_size) |y| {
                for (0..board_size) |x| {
                    if (self.board[y][x] != .none) continue;
                    const score = self.scores[y][x];
                    if (score > best_score) {
                        best_score = score;
                        best_move = Move{ .x = @intCast(x), .y = @intCast(y) };
                        prob = 2;
                    } else if (score == best_score) {
                        if (rand.next() % prob == 0) {
                            best_move = Move{ .x = @intCast(x), .y = @intCast(y) };
                            prob += 1;
                        }
                    }
                }
            }
            if (best_score < 22) return null;
            return best_move;
        }

        fn calcScores(board: Board, scores: *Scores) void {
            for (scores) |*row| {
                for (row) |*place| {
                    place.* = 0;
                }
            }

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
                    const eScore = calcScore(hStones);
                    const sScore = calcScore(vStones);
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
                    const swScore = calcScore(swStones);
                    const neScore = calcScore(neStones);
                    const nwScore = calcScore(nwStones);
                    const seScore = calcScore(seStones);
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
                const nwseScore = calcScore(nwseStones);
                const neswScore = calcScore(neswStones);
                inline for (0..6) |c| {
                    scores[b + c][b + c] += nwseScore;
                    scores[b + c][board_size - 1 - b - c] += neswScore;
                }
                nwseStones -= @intFromEnum(board[b][b]);
                neswStones -= @intFromEnum(board[b][board_size - 1 - b]);
            }
        }

        const zero_stones = 1;
        const one_stone = 2;
        const two_stones = 4;
        const three_stones = 8;
        const four_stones = 32;
        const five_stones = 64;

        fn calcScore(stones: i32) i32 {
            return switch (stones) {
                0x00 => zero_stones,
                0x01, 0x10 => one_stone,
                0x02, 0x20 => two_stones,
                0x03, 0x30 => three_stones,
                0x04, 0x40 => four_stones,
                0x05, 0x50 => five_stones,
                else => 0,
            };
        }

        fn calcDelta(stones: i32, stone: Stone) struct { score: i32, winner: Stone } {
            if (stone == .black) {
                const score: i32 = switch (stones) {
                    0x00 => one_stone - zero_stones,
                    0x01 => two_stones - one_stone,
                    0x02 => three_stones - two_stones,
                    0x03 => four_stones - three_stones,
                    0x04 => five_stones - four_stones,
                    0x05 => return .{ .score = 0, .winner = .black },
                    0x10 => -one_stone,
                    0x20 => -two_stones,
                    0x30 => -three_stones,
                    0x40 => -four_stones,
                    0x50 => -five_stones,
                    else => 0,
                };
                return .{ .score = score, .winner = .none };
            } else {
                const score: i32 = switch (stones) {
                    0x00 => one_stone - zero_stones,
                    0x01 => -one_stone,
                    0x02 => -two_stones,
                    0x03 => -three_stones,
                    0x04 => -four_stones,
                    0x05 => -five_stones,
                    0x10 => two_stones - one_stone,
                    0x20 => three_stones - two_stones,
                    0x30 => four_stones - three_stones,
                    0x40 => five_stones - four_stones,
                    0x50 => return .{ .score = 0, .winner = .white },
                    else => 0,
                };
                return .{ .score = score, .winner = .none };
            }
        }

        fn testScores(self: Self) void {
            var scores = [1][board_size]i32{[1]i32{0} ** board_size} ** board_size;
            calcScores(self.board, &scores);
            var failed = false;
            for (0..board_size) |y| {
                for (0..board_size) |x| {
                    if (self.board[y][x] == .none and self.scores[y][x] != scores[y][x]) {
                        print("Failure: x={} y={} expected={} actual={}\n", .{ x, y, scores[y][x], self.scores[y][x] });
                        failed = true;
                    }
                }
            }
            if (failed) {
                self.printScores(scores, "Expected");
                self.printScores(self.scores, "Actual");
                std.debug.panic("Failed\n", .{});
            }
        }

        pub fn printScores(self: Self, scores: Scores, prefix: []const u8) void {
            print("\n{s}\n", .{prefix});
            print("\n   |   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18 |", .{});
            print("\n---+-----------------------------------------------------------------------------+---", .{});
            for (scores, 0..) |row, y| {
                print("\n{:2} |", .{y});
                for (row, 0..) |score, x| {
                    switch (self.board[y][x]) {
                        .black => print("   X", .{}),
                        .white => print("   O", .{}),
                        else => if (score > 0) print("{:4}", .{@as(u32, @intCast(score))}) else print("   .", .{}),
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

        fn strFromStone(stone: Stone) []const u8 {
            return switch (stone) {
                .none => " ",
                .black => "X",
                .white => "O",
            };
        }
    };
}

test "calcScores" {
    const Player = enum(u2) { seconf, none, first };
    print("\n", .{});
    const Game = C6(Player, 19);
    var c6 = Game.init();
    _ = c6.makeMove(.{ .player = .first, .x = 18, .y = 18 });
    const result = c6.rollout();
    print("rollout result {any}\n", .{result});
}

test "possibleMoves" {
    const Player = enum(u2) { seconf, none, first };
    const Game = C6(Player, 19);
    var c6 = Game.init();
    var buf: [Game.max_moves]Game.Move = undefined;
    const moves = c6.possibleMoves(&buf);

    for (moves, 0..) |move, i| {
        print("{} - {}:{}\n", .{ i + 1, move.x, move.y });
    }
}
