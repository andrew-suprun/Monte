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
    const Scores = [BoardSize][BoardSize]u32;
    return struct {
        board: Board,
        scores: Scores,
        last_played: Stone,

        const Self = @This();

        pub fn init() Self {
            var self = Self{
                .board = [1][BoardSize]Stone{[1]Stone{.none} ** BoardSize} ** BoardSize,
                .scores = [1][BoardSize]u32{[1]u32{0} ** BoardSize} ** BoardSize,
                .last_played = .black,
            };
            self.place_stone(Place{ .x = BoardSize / 2, .y = BoardSize / 2 }, .black);

            return self;
        }

        fn place_stone(self: *Self, place: Place, stone: Stone) void {
            self.board[place.y][place.x] = stone;
        }

        const row_config_data = blk: {
            var row_cfg: [BoardSize][BoardSize][4]RowConfig = undefined;
            for (0..BoardSize) |a| {
                for (0..BoardSize) |b| {
                    const ai = @as(isize, @intCast(a));
                    const bi = @as(isize, @intCast(b));

                    const start1 = @max(0, bi - 5);
                    const count1 = @min(b + 1, BoardSize - b, 6);
                    row_cfg[a][b][0] = .{ .x = start1, .y = a, .count = count1 };
                    row_cfg[b][a][1] = .{ .x = a, .y = start1, .count = count1 };

                    const a1 = @max(ai - bi, ai - 5, 0);
                    const startA = if (a1 < 10) a1 else 0;
                    const b1 = @max(bi - ai, bi - 5, 0);
                    const startB = if (b1 < 10) b1 else 0;

                    const count = @max(0, @min(ai + 1, bi + 1, BoardSize - ai, BoardSize - bi, BoardSize - 5 - ai + bi, BoardSize - 5 - bi + ai, 6));

                    row_cfg[a][b][2] = .{ .x = startB, .y = startA, .count = count };
                }
            }

            break :blk row_cfg;
        };
        fn calc_scores(board: Board, scores: *Scores) void {
            for (scores) |*row| {
                for (row) |*place| {
                    place.* = 0;
                }
            }

            for (0..BoardSize) |a| {
                var hStones: u32 = 0;
                var vStones: u32 = 0;
                for (0..5) |b| {
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
                var swStones: u32 = 0;
                var neStones: u32 = 0;
                var nwStones: u32 = 0;
                var seStones: u32 = 0;
                for (0..5) |b| {
                    swStones += @intFromEnum(board[a + b][b]);
                    neStones += @intFromEnum(board[b][a + b]);
                    nwStones += @intFromEnum(board[BoardSize - 1 - a - b][b]);
                    seStones += @intFromEnum(board[a + b][BoardSize - 1 - b]);
                }

                for (0..BoardSize - 5 - a) |b| {
                    swStones += @intFromEnum(board[a + b + 5][b + 5]);
                    neStones += @intFromEnum(board[b + 5][a + b + 5]);
                    nwStones += @intFromEnum(board[BoardSize - a - b - 6][b + 5]);
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
                    swStones -= @intFromEnum(board[a][b]);
                    neStones -= @intFromEnum(board[a][b]);
                    nwStones -= @intFromEnum(board[BoardSize - 1 - a - b][b]);
                    seStones -= @intFromEnum(board[a + b][BoardSize - 1 - b]);
                }
            }
            var nwseStones: u32 = 0;
            var neswStones: u32 = 0;
            for (0..5) |a| {
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

        fn calc_score(stones: u32) u32 {
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
    };
}

const RowConfig = struct { x: usize, y: usize, count: usize };

const TestPlayer = enum { first, second };

test "init C6" {
    const Game = C6(TestPlayer, 19);
    var c6 = Game.init();
    Game.calc_scores(c6.board, &c6.scores);

    print("\n", .{});
    for (c6.scores, 0..) |row, y| {
        for (row, 0..) |score, x| {
            switch (c6.board[y][x]) {
                .black => print("  X", .{}),
                .white => print("  O", .{}),
                else => print("{:3}", .{score}),
            }
        }
        print("\n", .{});
    }
}
