const std = @import("std");
const print = std.debug.print;

const Place = struct {
    x: u8,
    y: u8,
};

const Move = [2]Place;

const Stone = enum(u8) { none = 0x00, black = 0x01, white = 0x10 };

pub fn C6(comptime Player: type, comptime BoardSize: usize) type {
    _ = Player;
    const Board = [BoardSize][BoardSize]Stone;
    const Scores = [BoardSize][BoardSize]i32;
    return struct {
        board: Board,
        scores: Scores,
        last_played: Stone,

        const Self = @This();

        pub fn init() Self {
            var self = Self{
                .board = [1][BoardSize]Stone{[1]Stone{.none} ** BoardSize} ** BoardSize,
                .scores = [1][BoardSize]i32{[1]i32{0} ** BoardSize} ** BoardSize,
                .last_played = .black,
            };
            calc_scores(self.board, &self.scores);
            _ = self.place_stone(Place{ .x = BoardSize / 2, .y = BoardSize / 2 }, .black);

            return self;
        }

        fn place_stone(self: *Self, place: Place, stone: Stone) ?Stone {
            print("place_stone: place={any} stone={any}\n", .{ place, stone });
            const x = place.x;
            const y = place.y;
            {
                const start_x: usize = @max(x, 5) - 5;
                const endX: usize = @min(x, BoardSize - 5) + 1;
                var stones: i32 = @intFromEnum(self.board[y][start_x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[y][start_x + i]);
                }
                for (start_x..endX) |dx| {
                    stones += @intFromEnum(self.board[y][dx + 5]);
                    const d = calc_delta(stones, stone);
                    if (d.winner != .none) return d.winner;
                    for (0..6) |c| {
                        self.scores[y][dx + c] += d.score;
                    }
                    stones -= @intFromEnum(self.board[y][dx]);
                }
            }

            {
                const start_y: usize = @max(y, 5) - 5;
                const endY: usize = @min(y, BoardSize - 5) + 1;
                var stones: i32 = @intFromEnum(self.board[start_y][x]);
                for (1..5) |i| {
                    stones += @intFromEnum(self.board[start_y + i][x]);
                }
                for (start_y..endY) |dy| {
                    stones += @intFromEnum(self.board[dy + 5][x]);
                    const d = calc_delta(stones, stone);
                    if (d.winner != .none) return d.winner;
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
                    if (d.winner != .none) return d.winner;
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
                    stones += @intFromEnum(self.board[start_y + 5][start_x - 5]);
                    const d = calc_delta(stones, stone);
                    if (d.winner != .none) return d.winner;
                    for (0..6) |e| {
                        self.scores[start_y + c + e][start_x - c - e] += d.score;
                    }
                    stones -= @intFromEnum(self.board[start_y + c][start_x - c]);
                }
            }

            self.board[y][x] = stone;
            return .none;
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
                0x01, 0x10 => 2,
                0x02, 0x20 => 4,
                0x03, 0x30 => 8,
                0x04, 0x40 => 16,
                0x05, 0x50 => 32,
                else => 0,
            };
        }

        fn calc_delta(stones: i32, stone: Stone) struct { score: i32, winner: Stone } {
            if (stone == .black) {
                const score: i32 = switch (stones) {
                    0x00 => 1,
                    0x01 => 2,
                    0x02 => 4,
                    0x03 => 8,
                    0x04 => 16,
                    0x05 => return .{ .score = 0, .winner = .black },
                    0x10 => -2,
                    0x20 => -4,
                    0x30 => -8,
                    0x40 => -16,
                    0x50 => -32,
                    else => 0,
                };
                return .{ .score = score, .winner = .none };
            } else {
                const score: i32 = switch (stones) {
                    0x00 => 1,
                    0x01 => -2,
                    0x02 => -4,
                    0x03 => -8,
                    0x04 => -16,
                    0x05 => -32,
                    0x10 => 2,
                    0x20 => 4,
                    0x30 => 8,
                    0x40 => 16,
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
            for (scores, 0..) |row, y| {
                for (row, 0..) |score, x| {
                    switch (self.board[y][x]) {
                        .black => print("  X", .{}),
                        .white => print("  O", .{}),
                        else => if (score > 0) print("{:3}", .{@as(u32, @intCast(score))}) else print("  .", .{}),
                    }
                }
                print("\n", .{});
            }
        }
    };
}

const RowConfig = struct { x: usize, y: usize, count: usize };

const TestPlayer = enum { first, second };

test "calc_scores" {
    print("\n", .{});
    const Game = C6(TestPlayer, 19);
    var c6 = Game.init();
    c6.test_scores();
    _ = c6.place_stone(Place{ .x = 8, .y = 9 }, .white);
    c6.print_scores(c6.scores, "Final");
    c6.test_scores();
}
