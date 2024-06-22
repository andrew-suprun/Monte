const std = @import("std");
const Prng = std.rand.Random.DefaultPrng;
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

const Stone = enum(u8) { none = 0x00, black = 0x01, white = 0x10 };

pub fn C6(Player: type, comptime BoardSize: usize) type {
    const Board = [BoardSize][BoardSize]Stone;
    const Scores = [BoardSize][BoardSize]i32;

    return struct {
        board: Board,
        scores: Scores,
        move_number: u32,

        const Self = @This();

        pub const Move = struct { x: u8, y: u8 };

        pub const explore_factor: f32 = 2;

        const Heap = std.PriorityDequeue(Move, *Scores, cmp);

        fn cmp(scores: *Scores, a: Move, b: Move) std.math.Order {
            const a_score = scores[a.y][a.x];
            const b_score = scores[b.y][b.x];
            return if (a_score < b_score) .lt else if (a_score > b_score) .gt else .eq;
        }

        pub fn init() Self {
            var self = Self{
                .board = [1][BoardSize]Stone{[1]Stone{.none} ** BoardSize} ** BoardSize,
                .scores = [1][BoardSize]i32{[1]i32{0} ** BoardSize} ** BoardSize,
                .move_number = 0,
            };
            calc_scores(self.board, &self.scores);
            _ = self.place_stone(Move{ .x = BoardSize / 2, .y = BoardSize / 2 });

            return self;
        }

        pub fn make_move(self: *Self, move: Move) ?Player {
            if (self.place_stone(move)) |stone| {
                return switch (stone) {
                    .black => .first,
                    .white => .second,
                    .none => std.debug.panic("impossible winner", .{}),
                };
            }
            return null;
        }

        pub fn possible_moves(self: *Self, allocator: std.mem.Allocator) []Move {
            const max_places = 32;
            var heap = Heap.init(allocator, &self.scores);
            defer heap.deinit();

            var n_places: u64 = 0;

            for (0..BoardSize) |y| {
                for (0..BoardSize) |x| {
                    if (self.board[y][x] == .none) {
                        heap.add(.{ .x = @intCast(x), .y = @intCast(y) }) catch unreachable;
                        n_places += 1;
                    }
                }
            }
            n_places = @min(max_places, n_places);
            var moves = allocator.alloc(Move, n_places) catch unreachable;
            for (0..n_places) |i| {
                moves[i] = heap.removeMax();
            }
            return moves;
        }

        pub fn turn(self: Self) Player {
            return player_from_stone(self.next_stone());
        }

        fn place_stone(self: *Self, place: Move) ?Stone {
            const x = place.x;
            const y = place.y;
            const stone = self.next_stone();
            var check_scores = true;
            defer {
                if (debug) {
                    print("place {s} at {}:{} score={}\n", .{ str_from_stone(stone), x, y, self.scores[y][x] });
                    if (check_scores) self.test_scores();
                    self.print_board();
                    print("\n\n", .{});
                }
            }
            {
                const start_x: usize = @max(x, 5) - 5;
                const endX: usize = @min(x + 1, BoardSize - 5);
                var stones: i32 = @intFromEnum(self.board[y][start_x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[y][start_x + i]);
                }
                for (start_x..endX) |dx| {
                    stones += @intFromEnum(self.board[y][dx + 5]);
                    const d = calc_delta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return d.winner;
                    }
                    for (0..6) |c| {
                        self.scores[y][dx + c] += d.score;
                    }
                    stones -= @intFromEnum(self.board[y][dx]);
                }
            }

            {
                const start_y: usize = @max(y, 5) - 5;
                const endY: usize = @min(y + 1, BoardSize - 5);
                var stones: i32 = @intFromEnum(self.board[start_y][x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[start_y + i][x]);
                }
                for (start_y..endY) |dy| {
                    stones += @intFromEnum(self.board[dy + 5][x]);
                    const d = calc_delta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return d.winner;
                    }
                    for (0..6) |c| {
                        self.scores[dy + c][x] += d.score;
                    }
                    stones -= @intFromEnum(self.board[dy][x]);
                }
            }

            b1: {
                const min: usize = @min(x, y, 5);
                const max: usize = @max(x, y);

                if (max - min >= BoardSize - 5) break :b1;

                const start_x = x - min;
                const start_y = y - min;
                const count = @min(min + 1, BoardSize - max, BoardSize - 5 + min - max);

                var stones: i32 = @intFromEnum(self.board[start_y][start_x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[start_y + i][start_x + i]);
                }
                for (start_x.., start_y.., 0..count) |xx, yy, _| {
                    stones += @intFromEnum(self.board[yy + 5][xx + 5]);
                    const d = calc_delta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return d.winner;
                    }
                    for (0..6) |e| {
                        self.scores[yy + e][xx + e] += d.score;
                    }
                    stones -= @intFromEnum(self.board[yy][xx]);
                }
            }

            b2: {
                const rev_x = BoardSize - 1 - x;
                const min: usize = @min(rev_x, y, 5);
                const max: usize = @max(rev_x, y);

                if (max - min >= BoardSize - 5) break :b2;

                const start_x = x + min;
                const start_y = y - min;
                const count = @min(min + 1, BoardSize - max, BoardSize - 5 + min - max);

                var stones: i32 = @intFromEnum(self.board[start_y][start_x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[start_y + i][start_x - i]);
                }
                for (0..count) |c| {
                    stones += @intFromEnum(self.board[start_y + 5 + c][start_x - 5 - c]);
                    const d = calc_delta(stones, stone);
                    if (d.winner != .none) {
                        check_scores = false;
                        return d.winner;
                    }
                    for (0..6) |e| {
                        self.scores[start_y + c + e][start_x - c - e] += d.score;
                    }
                    stones -= @intFromEnum(self.board[start_y + c][start_x - c]);
                }
            }

            self.board[y][x] = stone;
            self.move_number += 1;
            return null;
        }

        pub fn rollout(self: Self, move: Move) Player {
            var game = self;
            var rand = Prng.init(@intCast(std.time.milliTimestamp()));

            var stone = self.next_stone();
            if (game.place_stone(move)) |winner| return player_from_stone(winner);
            while (true) {
                stone = if (stone == .black) .white else .black;
                if (game.rollout_place(&rand)) |place| {
                    if (game.place_stone(place)) |winner| return player_from_stone(winner);
                } else {
                    return .none;
                }
            }
        }

        inline fn next_stone(self: Self) Stone {
            return if ((self.move_number + 3) & 2 == 2) .black else .white;
        }

        fn rollout_place(self: Self, rand: *Prng) ?Move {
            var best_move = Move{ .x = 0, .y = 0 };
            var best_score: i32 = 0;
            var prob: u64 = 2;
            for (0..BoardSize) |y| {
                for (0..BoardSize) |x| {
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
            if (best_score < 32) return null;
            return best_move;
        }

        inline fn player_from_stone(stone: Stone) Player {
            return switch (stone) {
                .black => .first,
                .white => .second,
                .none => .none,
            };
        }

        fn calc_scores(board: Board, scores: *Scores) void {
            for (scores) |*row| {
                for (row) |*place| {
                    place.* = 0;
                }
            }

            for (0..BoardSize) |a| {
                var hStones: i32 = @intFromEnum(board[a][0]);
                var vStones: i32 = @intFromEnum(board[0][a]);
                for (1..5) |b| {
                    hStones += @intFromEnum(board[a][b]);
                    vStones += @intFromEnum(board[b][a]);
                }
                for (0..BoardSize - 5) |b| {
                    hStones += @intFromEnum(board[a][b + 5]);
                    vStones += @intFromEnum(board[b + 5][a]);
                    const eScore = calc_score(hStones);
                    const sScore = calc_score(vStones);
                    for (0..6) |c| {
                        scores[a][b + c] += eScore;
                        scores[b + c][a] += sScore;
                    }
                    hStones -= @intFromEnum(board[a][b]);
                    vStones -= @intFromEnum(board[b][a]);
                }
            }

            for (1..BoardSize - 5) |a| {
                var swStones: i32 = @intFromEnum(board[a][0]);
                var neStones: i32 = @intFromEnum(board[0][a]);
                var nwStones: i32 = @intFromEnum(board[BoardSize - 1 - a][0]);
                var seStones: i32 = @intFromEnum(board[a][BoardSize - 1]);
                for (1..5) |b| {
                    swStones += @intFromEnum(board[a + b][b]);
                    neStones += @intFromEnum(board[b][a + b]);
                    nwStones += @intFromEnum(board[BoardSize - 1 - a - b][b]);
                    seStones += @intFromEnum(board[a + b][BoardSize - 1 - b]);
                }

                for (0..BoardSize - 5 - a) |b| {
                    swStones += @intFromEnum(board[a + b + 5][b + 5]);
                    neStones += @intFromEnum(board[b + 5][a + b + 5]);
                    nwStones += @intFromEnum(board[BoardSize - 6 - a - b][b + 5]);
                    seStones += @intFromEnum(board[a + b + 5][BoardSize - 6 - b]);
                    const swScore = calc_score(swStones);
                    const neScore = calc_score(neStones);
                    const nwScore = calc_score(nwStones);
                    const seScore = calc_score(seStones);
                    for (0..6) |c| {
                        scores[a + b + c][b + c] += swScore;
                        scores[b + c][a + b + c] += neScore;
                        scores[BoardSize - 1 - a - b - c][b + c] += nwScore;
                        scores[a + b + c][BoardSize - 1 - b - c] += seScore;
                    }
                    swStones -= @intFromEnum(board[a + b][b]);
                    neStones -= @intFromEnum(board[b][a + b]);
                    nwStones -= @intFromEnum(board[BoardSize - 1 - a - b][b]);
                    seStones -= @intFromEnum(board[a + b][BoardSize - 1 - b]);
                }
            }
            var nwseStones: i32 = @intFromEnum(board[0][0]);
            var neswStones: i32 = @intFromEnum(board[0][BoardSize - 1]);
            for (1..5) |a| {
                nwseStones += @intFromEnum(board[a][a]);
                neswStones += @intFromEnum(board[a][BoardSize - 1 - a]);
            }
            for (0..BoardSize - 5) |b| {
                nwseStones += @intFromEnum(board[b + 5][b + 5]);
                neswStones += @intFromEnum(board[b + 5][BoardSize - 6 - b]);
                const nwseScore = calc_score(nwseStones);
                const neswScore = calc_score(neswStones);
                for (0..6) |c| {
                    scores[b + c][b + c] += nwseScore;
                    scores[b + c][BoardSize - 1 - b - c] += neswScore;
                }
                nwseStones -= @intFromEnum(board[b][b]);
                neswStones -= @intFromEnum(board[b][BoardSize - 1 - b]);
            }
        }

        fn calc_score(stones: i32) i32 {
            return switch (stones) {
                0x00 => 1,
                0x01, 0x10 => 4,
                0x02, 0x20 => 16,
                0x03, 0x30 => 64,
                0x04, 0x40 => 256,
                0x05, 0x50 => 1024,
                else => 0,
            };
        }

        fn calc_delta(stones: i32, stone: Stone) struct { score: i32, winner: Stone } {
            if (stone == .black) {
                const score: i32 = switch (stones) {
                    0x00 => 3,
                    0x01 => 12,
                    0x02 => 48,
                    0x03 => 192,
                    0x04 => 768,
                    0x05 => return .{ .score = 0, .winner = .black },
                    0x10 => -4,
                    0x20 => -16,
                    0x30 => -64,
                    0x40 => -256,
                    0x50 => -1024,
                    else => 0,
                };
                return .{ .score = score, .winner = .none };
            } else {
                const score: i32 = switch (stones) {
                    0x00 => 3,
                    0x01 => -4,
                    0x02 => -16,
                    0x03 => -64,
                    0x04 => -256,
                    0x05 => -1024,
                    0x10 => 12,
                    0x20 => 48,
                    0x30 => 192,
                    0x40 => 768,
                    0x50 => return .{ .score = 0, .winner = .white },
                    else => 0,
                };
                return .{ .score = score, .winner = .none };
            }
        }

        fn test_scores(self: Self) void {
            var scores = [1][BoardSize]i32{[1]i32{0} ** BoardSize} ** BoardSize;
            calc_scores(self.board, &scores);
            var failed = false;
            for (0..BoardSize) |y| {
                for (0..BoardSize) |x| {
                    if (self.board[y][x] == .none and self.scores[y][x] != scores[y][x]) {
                        print("Failure: x={} y={} expected={} actual={}\n", .{ x, y, scores[y][x], self.scores[y][x] });
                        failed = true;
                    }
                }
            }
            if (failed) {
                self.print_scores(scores, "Expected");
                self.print_scores(self.scores, "Actual");
                std.debug.panic("Failed\n", .{});
            }
        }

        fn print_scores(self: Self, scores: Scores, prefix: []const u8) void {
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

        fn print_board(self: Self) void {
            print("\n   |                     1 1 1 1 1 1 1 1 1 |", .{});
            print("\n   | 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 |", .{});
            print("\n---+---------------------------------------+---", .{});
            for (0..BoardSize) |y| {
                print("\n{:2} |", .{y});
                for (0..BoardSize) |x| {
                    switch (self.board[y][x]) {
                        .black => print(" X", .{}),
                        .white => print(" O", .{}),
                        else => print(" .", .{}),
                    }
                }
                print(" | {:2}", .{y});
            }
            print("\n---+---------------------------------------+---", .{});
            print("\n   |                     1 1 1 1 1 1 1 1 1 |", .{});
            print("\n   | 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 |\n", .{});
        }

        fn str_from_stone(stone: Stone) []const u8 {
            return switch (stone) {
                .none => " ",
                .black => "X",
                .white => "O",
            };
        }
    };
}

const RowConfig = struct { x: usize, y: usize, count: usize };

const TestPlayer = enum { first, second, none };

test "calc_scores" {
    print("\n", .{});
    const Game = C6(TestPlayer, 19);
    var c6 = Game.init();
    const result = c6.rollout(.{ .x = 8, .y = 8 });
    print("rollout result {any}\n", .{result});
}

test "possible_moves" {
    const Game = C6(TestPlayer, 19);
    var c6 = Game.init();
    const moves = c6.possible_moves(std.testing.allocator);

    for (moves, 0..) |move, i| {
        print("{} - {}:{}\n", .{ i + 1, move.x, move.y });
    }

    std.testing.allocator.free(moves);
}
