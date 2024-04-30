const Scores = @This();
const std = @import("std");
const config = @import("config.zig");
const Board = @import("Board.zig");
const BoardSize = config.BoardSize;
const Place = config.Place;
const Move = config.Move;
const Player = config.Player;
const Score = i64;

const RolloutResult = union(enum) {
    final: Player,
    nonterminal: Player,
};

pub const empty_scores = blk: {
    var scores = Scores{
        .board = Board.empty_board,
    };
    for (config.row_config) |row_config| {
        _ = scores.score_row(row_config, false);
    }
    break :blk scores;
};

places: [BoardSize][BoardSize]Score = [1][BoardSize]Score{[1]Score{0} ** BoardSize} ** BoardSize,
board: Board,
turn: Player = .first,

pub fn clone(self: Scores) Scores {
    return Scores{
        .places = self.places,
        .board = self.board.clone(),
    };
}

inline fn get(self: Scores, place: Place) Score {
    return self.places[@intCast(place.x)][@intCast(place.y)];
}

inline fn inc(self: *Scores, place: Place, value: Score) void {
    self.places[@intCast(place.x)][@intCast(place.y)] += value;
}

pub inline fn make_move(scores: *Scores, move: Move) bool {
    inline for (move) |place| {
        inline for (config.raw_indices(place)) |idx| {
            _ = scores.score_row(config.row_config[idx], true);
            scores.board.set_place(place, scores.turn);
            if (scores.score_row(config.row_config[idx], false)) return true;
        }
    }
    scores.turn = if (scores.turn == .first) .second else .first;
    return false;
}

fn score_row(scores: *Scores, row_config: config.RowConfig, comptime clear: bool) bool {
    if (row_config.count == 0) return false;

    var x = row_config.x;
    var y = row_config.y;
    const dx = row_config.dx;
    const dy = row_config.dy;

    var sum: usize = @intFromEnum(scores.board.get(.{ .x = x, .y = y })) +
        @intFromEnum(scores.board.get(.{ .x = x + dx, .y = y + dy })) +
        @intFromEnum(scores.board.get(.{ .x = x + 2 * dx, .y = y + 2 * dy })) +
        @intFromEnum(scores.board.get(.{ .x = x + 3 * dx, .y = y + 3 * dy })) +
        @intFromEnum(scores.board.get(.{ .x = x + 4 * dx, .y = y + 4 * dy })) +
        @intFromEnum(scores.board.get(.{ .x = x + 5 * dx, .y = y + 5 * dy }));

    const values = [_]Score{ 1, 4, 16, 64, 256, 1024, 32768 };
    var i: u8 = 0;
    while (true) {
        const v: Score = if (sum & 0x70 == 0) values[sum] else if (sum & 0x07 == 0) values[sum >> 4] else 0;
        if (v >= 32768) return true;
        const value = if (clear) -v else v;

        scores.inc(.{ .x = x, .y = y }, value);
        scores.inc(.{ .x = x + dx, .y = y + dy }, value);
        scores.inc(.{ .x = x + 2 * dx, .y = y + 2 * dy }, value);
        scores.inc(.{ .x = x + 3 * dx, .y = y + 3 * dy }, value);
        scores.inc(.{ .x = x + 4 * dx, .y = y + 4 * dy }, value);
        scores.inc(.{ .x = x + 5 * dx, .y = y + 5 * dy }, value);
        i += 1;
        if (i == row_config.count) {
            break;
        }
        sum -= @intFromEnum(scores.board.get(.{ .x = x, .y = y }));
        x += dx;
        y += dy;
        sum += @intFromEnum(scores.board.get(.{ .x = x + 5 * dx, .y = y + 5 * dy }));
    }
    return false;
}

fn print(self: Scores) void {
    for (0..BoardSize) |j| {
        for (0..BoardSize) |i| {
            std.debug.print("{:3} ", .{self.places[i][j]});
        }
        std.debug.print("\n", .{});
    }
}
