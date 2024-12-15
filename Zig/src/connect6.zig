board: [board_size][board_size]Stone = [1][board_size]Stone{[1]Stone{.none} ** board_size} ** board_size,
n_moves: usize = 0,

const std = @import("std");
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub const board_size: comptime_int = 19;
pub const max_moves: comptime_int = if (debug) 6 else 200;
pub const max_places: comptime_int = if (debug) 6 else 100;

const Stone = enum(u8) { none = 0x00, black = 0x01, white = 0x10 };

pub const Move = struct {
    places: [2]Place,
    terminal: bool,
    score: i32,

    pub fn eql(self: @This(), other: @This()) bool {
        const p1 = self.places[0];
        const p2 = self.places[1];
        const o1 = other.places[0];
        const o2 = other.places[1];
        return p1.x == o1.x and p1.y == o1.y and p2.x == o2.x and p2.y == o2.y;
    }

    pub fn str(self: @This(), buf: []u8) []u8 {
        const i = self.places[0].str(buf);
        buf[i] = '+';
        const j = self.places[1].str(buf[i + 1 ..]);
        return buf[0 .. i + j + 1];
    }

    pub fn print(self: @This()) void {
        var buf: [8]u8 = undefined;
        const move_str = self.str(&buf);
        std.debug.print("[{s}, terminal: {any}, score: {d}]", .{
            move_str,
            self.terminal,
            self.score,
        });
    }
};

pub const Place = struct {
    x: u8,
    y: u8,

    pub inline fn init(x: usize, y: usize) @This() {
        return .{ .x = @intCast(x), .y = @intCast(y) };
    }

    pub inline fn eql(self: @This(), other: @This()) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub inline fn less(self: @This(), other: @This()) bool {
        if (self.x < other.x) return true;
        if (self.x > other.x) return false;
        return self.y < other.y;
    }

    fn str(self: @This(), buf: []u8) usize {
        buf[0] = self.x + 'a';
        const y = board_size - self.y;
        if (y >= 10) {
            buf[1] = '1';
            buf[2] = y - 10 + '0';
            return 3;
        } else {
            buf[1] = y + '0';
            return 2;
        }
    }
};

const Self = @This();
const Scores = [board_size][board_size]i32;

pub fn initMove(self: *Self, note: []const u8) !Move {
    var place_tokens = std.mem.tokenizeScalar(u8, note, '+');
    return self.initMoveFromPlaces(
        try parseToken(place_tokens.next()),
        try parseToken(place_tokens.next()),
    );
}

pub fn initMoveFromPlaces(self: *Self, place0: Place, place1: Place) Move {
    const stone = self.nextStone();
    const score1 = if (stone == .black)
        self.ratePlace(place0, .black)
    else
        self.ratePlace(place0, .white);
    const score2 = if (!place0.eql(place1)) blk: {
        self.board[place0.y][place0.x] = stone;
        defer self.board[place0.y][place0.x] = .none;

        break :blk if (stone == .black)
            self.ratePlace(place1, .black)
        else
            self.ratePlace(place1, .white);
    } else 0;

    return initMoveWithScore(place0, place1, score1 + score2);
}

inline fn initMoveWithScore(place0: Place, place1: Place, score: i32) Move {
    const sorted_places = sortPlaces(place0, place1);
    if (score == 0) {
        return Move{ .places = sorted_places, .score = 0, .terminal = true };
    } else if (score >= six_stones) {
        return Move{ .places = sorted_places, .score = six_stones, .terminal = true };
    } else if (score <= -six_stones) {
        return Move{ .places = sorted_places, .score = -six_stones, .terminal = true };
    } else {
        return Move{ .places = sorted_places, .score = score, .terminal = false };
    }
}

fn sortPlaces(p1: Place, p2: Place) [2]Place {
    return if (p1.x < p2.x or p1.x == p2.x and p1.y > p2.y)
        [2]Place{ p1, p2 }
    else
        [2]Place{ p2, p1 };
}

fn parseToken(maybe_token: ?[]const u8) !Place {
    if (maybe_token == null) return error.Error;
    const token = maybe_token.?;
    if (token.len < 2 or token.len > 3) return error.Error;
    if (token[0] < 'a' or token[0] > 's') return error.Error;
    if (token[1] < '0' or token[1] > '9') return error.Error;
    const x = token[0] - 'a';
    var y = token[1] - '0';
    if (token.len == 3) {
        if (token[2] < '0' or token[2] > '9') return error.Error;
        y = 10 * y + token[2] - '0';
    }
    y = board_size - y;
    if (x > board_size or y > board_size) return error.Error;
    return Place.init(x, y);
}

pub fn makeMove(self: *Self, move: Move) void {
    const stone = self.nextStone();
    const p1 = move.places[0];
    const p2 = move.places[1];

    self.board[p1.y][p1.x] = stone;
    self.board[p2.y][p2.x] = stone;
    self.n_moves += 1;
}

pub fn undoMove(self: *Self, move: Move) void {
    const p1 = move.places[0];
    const p2 = move.places[1];

    self.board[p1.y][p1.x] = .none;
    self.board[p2.y][p2.x] = .none;
    self.n_moves -= 1;
}

pub fn possibleMoves(self: *Self, buf: []Move) []Move {
    const stone = self.nextStone();

    var place_buf: [board_size * board_size]Place = undefined;
    if (stone == .black) {
        const scores = self.calcScores(.black);
        const place_list = self.possiblePlaces(.black, scores, &place_buf);
        return self.selectMoves(.black, scores, place_list, buf);
    } else {
        const scores = self.calcScores(.white);
        const place_list = self.possiblePlaces(.white, scores, &place_buf);
        return self.selectMoves(.white, scores, place_list, buf);
    }
}

fn possiblePlaces(self: Self, comptime stone: Stone, scores: Scores, place_list: []Place) []Place {
    var heap = if (stone == .black) HeapPlaceBlack.init(scores) else HeapPlaceWhite.init(scores);
    for (0..board_size) |y| {
        for (0..board_size) |x| {
            if (self.board[y][x] == .none) {
                heap.add(Place.init(x, y));
            }
        }
    }
    return heap.sorted(place_list); // TODO: unsorted
}

fn selectMoves(self: *Self, comptime stone: Stone, scores: Scores, place_list: []Place, buf: []Move) []Move {
    var heap = if (stone == .black) HeapBlack.init({}) else HeapWhite.init({});

    if (scores[place_list[0].y][place_list[0].x] == 0) {
        buf[0] = initMoveWithScore(place_list[0], place_list[0], 0);
        return buf[0..1];
    }

    for (place_list[0 .. place_list.len - 1], 0..) |p1, i| {
        const score1 = scores[p1.y][p1.x];
        if (@abs(score1) > six_stones)
            return winningMove(p1, p1, score1, buf);

        for (i + 1..place_list.len) |j| {
            var score2: i32 = undefined;
            const p2 = place_list[j];
            if (p1.x == p2.x or p1.y == p2.y or p1.x + p1.y == p2.x + p2.y or p1.x + p2.y == p2.x + p1.y) {
                self.board[p1.y][p1.x] = stone;
                score2 = self.ratePlace(p2, stone);
                self.board[p1.y][p1.x] = .none;
            } else {
                score2 = scores[p2.y][p2.x];
            }

            if (@abs(score2) >= six_stones)
                return winningMove(p1, p2, score2, buf);

            heap.add(initMoveWithScore(p1, p2, score1 + score2));
        }
    }
    return heap.sorted(buf); // TODO: unsorted
}

fn winningMove(p1: Place, p2: Place, score: i32, buf: []Move) []Move {
    buf[0] = initMoveWithScore(p1, p2, score);
    return buf[0..1];
}

fn ratePlace(self: Self, place: Place, comptime stone: Stone) i32 {
    const x = place.x;
    const y = place.y;
    var score: i32 = 0;

    {
        const start_x: usize = @max(x, 5) - 5;
        const end_x: usize = @min(x + 1, board_size - 5);
        var stones: i32 = @intFromEnum(self.board[y][start_x]);
        for (1..5) |i| {
            stones += @intFromEnum(self.board[y][start_x + i]);
        }
        for (start_x..end_x) |dx| {
            stones += @intFromEnum(self.board[y][dx + 5]);
            score += calcScore(stone, stones);
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
            score += calcScore(stone, stones);
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
            score += calcScore(stone, stones);
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
            score += calcScore(stone, stones);
            stones -= @intFromEnum(self.board[start_y + c][start_x - c]);
        }
    }

    return score;
}

fn calcScores(self: Self, comptime stone: Stone) Scores {
    var scores = [1][board_size]i32{[1]i32{0} ** board_size} ** board_size;

    for (0..board_size) |a| {
        var hStones: i32 = @intFromEnum(self.board[a][0]);
        var vStones: i32 = @intFromEnum(self.board[0][a]);
        for (1..5) |b| {
            hStones += @intFromEnum(self.board[a][b]);
            vStones += @intFromEnum(self.board[b][a]);
        }
        for (0..board_size - 5) |b| {
            hStones += @intFromEnum(self.board[a][b + 5]);
            vStones += @intFromEnum(self.board[b + 5][a]);
            const eScore = calcScore(stone, hStones);
            const sScore = calcScore(stone, vStones);
            inline for (0..6) |c| {
                scores[a][b + c] += eScore;
                scores[b + c][a] += sScore;
            }
            hStones -= @intFromEnum(self.board[a][b]);
            vStones -= @intFromEnum(self.board[b][a]);
        }
    }

    for (1..board_size - 5) |a| {
        var swStones: i32 = @intFromEnum(self.board[a][0]);
        var neStones: i32 = @intFromEnum(self.board[0][a]);
        var nwStones: i32 = @intFromEnum(self.board[board_size - 1 - a][0]);
        var seStones: i32 = @intFromEnum(self.board[a][board_size - 1]);
        for (1..5) |b| {
            swStones += @intFromEnum(self.board[a + b][b]);
            neStones += @intFromEnum(self.board[b][a + b]);
            nwStones += @intFromEnum(self.board[board_size - 1 - a - b][b]);
            seStones += @intFromEnum(self.board[a + b][board_size - 1 - b]);
        }

        for (0..board_size - 5 - a) |b| {
            swStones += @intFromEnum(self.board[a + b + 5][b + 5]);
            neStones += @intFromEnum(self.board[b + 5][a + b + 5]);
            nwStones += @intFromEnum(self.board[board_size - 6 - a - b][b + 5]);
            seStones += @intFromEnum(self.board[a + b + 5][board_size - 6 - b]);
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
            swStones -= @intFromEnum(self.board[a + b][b]);
            neStones -= @intFromEnum(self.board[b][a + b]);
            nwStones -= @intFromEnum(self.board[board_size - 1 - a - b][b]);
            seStones -= @intFromEnum(self.board[a + b][board_size - 1 - b]);
        }
    }

    var nwseStones: i32 = @intFromEnum(self.board[0][0]);
    var neswStones: i32 = @intFromEnum(self.board[0][board_size - 1]);
    for (1..5) |a| {
        nwseStones += @intFromEnum(self.board[a][a]);
        neswStones += @intFromEnum(self.board[a][board_size - 1 - a]);
    }
    for (0..board_size - 5) |b| {
        nwseStones += @intFromEnum(self.board[b + 5][b + 5]);
        neswStones += @intFromEnum(self.board[b + 5][board_size - 6 - b]);
        const nwseScore = calcScore(stone, nwseStones);
        const neswScore = calcScore(stone, neswStones);
        inline for (0..6) |c| {
            scores[b + c][b + c] += nwseScore;
            scores[b + c][board_size - 1 - b - c] += neswScore;
        }
        nwseStones -= @intFromEnum(self.board[b][b]);
        neswStones -= @intFromEnum(self.board[b][board_size - 1 - b]);
    }
    return scores;
}

// TODO should work by just comparing by scores
const HeapBlack = @import("heap.zig").Heap(Move, void, cmpBlack, max_moves);
fn cmpBlack(_: void, a: Move, b: Move) bool {
    if (a.score < b.score) return true;
    if (a.score > b.score) return false;
    if (a.places[0].less(b.places[0])) return true;
    if (b.places[0].less(a.places[0])) return false;
    return a.places[1].less(b.places[1]);
}

const HeapWhite = @import("heap.zig").Heap(Move, void, cmpWhite, max_moves);
fn cmpWhite(_: void, a: Move, b: Move) bool {
    return cmpBlack({}, b, a);
}

// TODO should work by just comparing by scores
const HeapPlaceBlack = @import("heap.zig").Heap(Place, Scores, cmpPlaceBlack, max_places);
fn cmpPlaceBlack(scores: Scores, a: Place, b: Place) bool {
    if (scores[a.y][a.x] < scores[b.y][b.x]) return true;
    if (scores[a.y][a.x] > scores[b.y][b.x]) return false;
    return a.less(b);
}

const HeapPlaceWhite = @import("heap.zig").Heap(Place, Scores, cmpPlaceWhite, max_places);
fn cmpPlaceWhite(scores: Scores, a: Place, b: Place) bool {
    return cmpPlaceBlack(scores, b, a);
}

inline fn nextStone(self: Self) Stone {
    return if (self.n_moves % 2 == 0) .black else .white;
}

const one_stone = 1;
const two_stones = 5;
const three_stones = 20;
const four_stones = 60;
const five_stones = 120;
const six_stones = 1000;

fn calcScore(comptime stone: Stone, stones: i32) i32 {
    return if (stone == .black)
        switch (stones) {
            0x00 => one_stone,
            0x01 => two_stones - one_stone,
            0x02 => three_stones - two_stones,
            0x03 => four_stones - three_stones,
            0x04 => five_stones - four_stones,
            0x05 => six_stones,
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
        0x50 => -six_stones,
        else => 0,
    };
}

pub fn scoreBoard(self: Self) i32 {
    var result: i32 = 0;

    for (0..board_size) |a| {
        var h_stones: i32 = 0;
        var v_stones: i32 = 0;

        for (0..5) |b| {
            h_stones += @intFromEnum(self.board[a][b]);
            v_stones += @intFromEnum(self.board[b][a]);
        }
        for (5..board_size) |b| {
            h_stones += @intFromEnum(self.board[a][b]);
            result += debugRate(h_stones);
            h_stones -= @intFromEnum(self.board[a][b - 5]);

            v_stones += @intFromEnum(self.board[b][a]);
            result += debugRate(v_stones);
            v_stones -= @intFromEnum(self.board[b - 5][a]);
        }
    }

    for (0..board_size - 5) |y| {
        var sw_stones: i32 = 0;
        var se_stones: i32 = 0;

        for (0..5) |i| {
            sw_stones += @intFromEnum(self.board[y + i][i]);
            se_stones += @intFromEnum(self.board[y + i][board_size - 1 - i]);
        }
        for (5..board_size - y) |i| {
            sw_stones += @intFromEnum(self.board[y + i][i]);
            result += debugRate(sw_stones);
            sw_stones -= @intFromEnum(self.board[y + i - 5][i - 5]);

            se_stones += @intFromEnum(self.board[y + i][board_size - 1 - i]);
            result += debugRate(se_stones);
            se_stones -= @intFromEnum(self.board[y + i - 5][board_size + 4 - i]);
        }
    }

    for (1..board_size - 5) |x| {
        var ne_stones: i32 = 0;
        var nw_stones: i32 = 0;

        for (0..5) |i| {
            ne_stones += @intFromEnum(self.board[i][x + i]);
            nw_stones += @intFromEnum(self.board[i][board_size - 1 - x - i]);
        }

        for (5..board_size - x) |i| {
            ne_stones += @intFromEnum(self.board[i][x + i]);
            result += debugRate(ne_stones);
            ne_stones -= @intFromEnum(self.board[i - 5][x + i - 5]);

            nw_stones += @intFromEnum(self.board[i][board_size - 1 - x - i]);
            result += debugRate(nw_stones);
            nw_stones -= @intFromEnum(self.board[i - 5][board_size + 4 - x - i]);
        }
    }

    return result;
}

fn debugRate(stones: i32) i32 {
    return switch (stones) {
        0x01 => one_stone,
        0x02 => two_stones,
        0x03 => three_stones,
        0x04 => four_stones,
        0x05 => five_stones,
        0x10 => -one_stone,
        0x20 => -two_stones,
        0x30 => -three_stones,
        0x40 => -four_stones,
        0x50 => -five_stones,
        else => 0,
    };
}

pub fn printBoard(self: Self) void {
    std.debug.print("\n  ", .{});
    for (0..board_size) |i| {
        std.debug.print(" {c}", .{@as(u8, @intCast(i)) + 'a'});
    }
    for (0..board_size) |y| {
        std.debug.print("\n{:2}", .{board_size - y});
        for (0..board_size) |x| {
            const piece = switch (self.board[y][x]) {
                .black => "─X",
                .white => "─O",
                .none => switch (y) {
                    0 => switch (x) {
                        0 => " ┌",
                        board_size - 1 => "─┐",
                        else => "─┬",
                    },
                    board_size - 1 => switch (x) {
                        0 => " └",
                        board_size - 1 => "─┘",
                        else => "─┴",
                    },
                    else => switch (x) {
                        0 => " ├",
                        board_size - 1 => "─┤",
                        else => "─┼",
                    },
                },
            };

            std.debug.print("{s}", .{piece});
        }
        std.debug.print(" {:2}", .{board_size - y});
    }

    std.debug.print("\n  ", .{});
    for (0..board_size) |i| {
        std.debug.print(" {c}", .{@as(u8, @intCast(i)) + 'a'});
    }
}

test "Move.str.1" {
    const m = Move{
        .places = [2]Place{ .{ .x = 7, .y = 10 }, .{ .x = 7, .y = 9 } },
        .terminal = false,
        .score = 0,
    };
    var buf: [8]u8 = undefined;
    const m_str = m.str(&buf);
    std.debug.print("m_str = {s}:{d}\n", .{ m_str, m_str.len });
}

test "Move.str.2" {
    var move = Move{ .places = .{ .{ .x = 0, .y = 18 }, .{ .x = 9, .y = 9 } }, .score = 0 };
    var buf: [7]u8 = undefined;
    const move_str = move.str(&buf);
    try std.testing.expectEqualSlices(u8, "a1+j10", move_str);
}

test "C6" {
    var game = Self{};
    game.makeMove(try game.initMove("j10+j10"));
    game.printBoard();
    const score = game.scoreBoard();
    std.debug.print("\nscore = {d} \n", .{score});
    var buf: [Self.max_moves]Move = undefined;
    const moves = game.possibleMoves(&buf);
    // print("\npossible moves {d}", .{moves.len});
    for (moves) |m| {
        var new_game = game;
        new_game.makeMove(m);
        // print("\n\n", .{});
        // m.print();
        // new_game.printBoard();
    }
}

const Prng = std.rand.Random.DefaultPrng;

test "scoreBoard" {
    var rng = Prng.init(1);
    var start = try std.time.Timer.start();
    var result: i32 = 0;
    var game = Self{};
    for (0..10_000) |_| {
        for (0..100) |_| {
            game.board[9][9] = if (rng.next() % 2 == 0) .black else .white;
            result += game.scoreBoard();
        }
    }
    const nanos = start.read();
    std.debug.print("\n{d} result {d}\n", .{ nanos / 1_000_000, result });
}

test "ratePlace" {
    var rng = Prng.init(1);
    var start = try std.time.Timer.start();
    var result: i32 = 0;
    var game = Self{};
    for (0..10_000) |_| {
        for (0..100) |_| {
            const r = if (rng.next() % 2 == 0) game.ratePlace(Place.init(9, 9), .black) else game.ratePlace(Place.init(9, 9), .white);
            result += r;
        }
    }
    const nanos = start.read();
    std.debug.print("\ntime {d}ms result {d}\n", .{ nanos / 1_000_000, result });
}

test "placeStone" {
    var game = Self{};

    var rng = Prng.init(1);
    var score: i32 = 0;
    for (1..100) |_| {
        const x: usize = @intCast(rng.next() % board_size);
        const y: usize = @intCast(rng.next() % board_size);
        const stone: Stone = if (rng.next() % 2 == 0) .black else .white;
        if (game.board[y][x] != .none) continue;
        score += if (stone == .black) game.ratePlace(Place.init(x, y), .black) else game.ratePlace(Place.init(x, y), .white);
        game.board[y][x] = stone;
        const score2 = game.scoreBoard();
        try std.testing.expectEqual(score2, score);
    }
}

test "calcScores" {
    var game = Self{};

    var rng = Prng.init(1);
    var score: i32 = 0;
    for (1..100) |_| {
        const x: usize = @intCast(rng.next() % board_size);
        const y: usize = @intCast(rng.next() % board_size);
        const stone: Stone = if (rng.next() % 2 == 0) .black else .white;
        if (game.board[y][x] != .none) continue;
        const scores = if (stone == .black) game.calcScores(.black) else game.calcScores(.white);
        score += scores[y][x];
        game.board[y][x] = stone;
        const score2 = game.scoreBoard();
        try std.testing.expectEqual(score2, score);
    }
}

test "bench-calcScores" {
    var game = Self{};

    var rng = Prng.init(1);

    var score: i32 = 0;
    var timer = try std.time.Timer.start();
    for (0..1_000_000) |_| {
        for (1..100) |_| {
            const x: usize = @intCast(rng.next() % board_size);
            const y: usize = @intCast(rng.next() % board_size);
            const stone: Stone = if (rng.next() % 2 == 0) .black else .white;
            if (game.board[y][x] != .none) continue;
            const scores = if (stone == .black) game.calcScores(.black) else game.calcScores(.white);
            score += scores[y][x];
            game.board[y][x] = stone;
        }
    }
    std.mem.doNotOptimizeAway(score);
    std.debug.print("\ntime {}ms\n", .{timer.read() / 1_000_000});
}

test "possibleMoves" {
    var game = Self{};

    var timer = try std.time.Timer.start();
    var n_moves: usize = 0;

    for (0..10_000) |_| {
        var buf: [Self.max_moves]Move = undefined;
        const moves = game.possibleMoves(&buf);
        n_moves += moves.len;
    }

    std.debug.print("\ntime {}ms", .{timer.read() / 1_000_000});
    std.debug.print("\nmoves {d}\n", .{n_moves});
}
