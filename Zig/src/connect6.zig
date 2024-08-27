board: [board_size][board_size]Stone = [1][board_size]Stone{[1]Stone{.none} ** board_size} ** board_size,
n_moves: usize = 0,

const std = @import("std");
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub const board_size: comptime_int = 19;
pub const max_moves: comptime_int = if (debug) 6 else 200;
pub const max_places: comptime_int = if (debug) 6 else 200;

const Stone = enum(u8) { none = 0x00, black = 0x01, white = 0x10 };

pub const Decision = enum(u2) {
    nonterminal,
    win,
    loss,
    draw,

    fn str(self: @This()) []const u8 {
        return switch (self) {
            .nonterminal => "nonterminal",
            .win => "win",
            .loss => "loss",
            .draw => "draw",
        };
    }
};

pub const Move = struct {
    decision: Decision = .nonterminal,
    places: [2]Place,
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
        std.debug.print("[{s}, decision: {s}, score: {d}]", .{
            move_str,
            self.decision.str(),
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
    const places: [2]Place = .{
        try parseToken(place_tokens.next()),
        try parseToken(place_tokens.next()),
    };
    return self.initMoveFromPlaces(places);
}

pub fn initMoveFromPlaces(self: *Self, places: [2]Place) Move {
    const player = self.nextStone();
    const score1 = if (player == .black)
        self.ratePlace(places[0], .black)
    else
        self.ratePlace(places[0], .white);
    const score2 = if (!places[0].eql(places[1])) blk: {
        self.board[places[0].y][places[0].x] = player;
        defer self.board[places[0].y][places[0].x] = .none;

        break :blk if (player == .black)
            self.ratePlace(places[1], .black)
        else
            self.ratePlace(places[1], .white);
    } else 0;
    var decision: Decision = .nonterminal;
    if (@abs(score1 + score2) > 1024) decision = .win;
    return Move{
        .places = sortPlaces(places[0], places[1]),
        .score = score1 + score2,
        .decision = decision,
    };
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

pub fn possibleMoves(self: *Self, allocator: std.mem.Allocator) []Move {
    const stone = self.nextStone();

    var place_buf: [board_size * board_size]Place = undefined;
    if (stone == .black) {
        const scores = self.calcScores(.black);
        const place_list = self.possiblePlaces(.black, scores, &place_buf);
        return self.selectMoves(.black, scores, place_list, allocator);
    } else {
        const scores = self.calcScores(.white);
        const place_list = self.possiblePlaces(.white, scores, &place_buf);
        return self.selectMoves(.white, scores, place_list, allocator);
    }
}

fn possiblePlaces(self: Self, comptime player: Stone, scores: Scores, place_list: []Place) []Place {
    var heap = if (player == .black) HeapPlaceBlack.init(scores) else HeapPlaceWhite.init(scores);
    for (0..board_size) |y| {
        for (0..board_size) |x| {
            if (self.board[y][x] == .none) {
                heap.add(Place.init(x, y));
            }
        }
    }
    return heap.sorted(place_list); // TODO: unsorted
}

fn selectMoves(self: *Self, comptime player: Stone, scores: Scores, place_list: []Place, allocator: std.mem.Allocator) []Move {
    var heap = if (player == .black) HeapBlack.init({}) else HeapWhite.init({});

    if (scores[place_list[0].y][place_list[0].x] == 0) {
        var moves = allocator.alloc(Move, 1) catch unreachable;
        moves[0] = Move{
            .places = sortPlaces(place_list[0], place_list[1]),
            .score = 0,
            .decision = .draw,
        };
        return moves;
    }

    for (place_list[0 .. place_list.len - 1], 0..) |p1, i| {
        const score1 = scores[p1.y][p1.x];
        if (@abs(score1) > 1024)
            return winningMove(p1, p1, score1, allocator);

        for (i + 1..place_list.len) |j| {
            var score2: i32 = undefined;
            const p2 = place_list[j];
            if (p1.x == p2.x or p1.y == p2.y or p1.x + p1.y == p2.x + p2.y or p1.x + p2.y == p2.x + p1.y) {
                self.board[p1.y][p1.x] = player;
                score2 = self.ratePlace(p2, player);
                self.board[p1.y][p1.x] = .none;
            } else {
                score2 = scores[p2.y][p2.x];
            }

            if (@abs(score2) > 1024)
                return winningMove(p1, p2, score2, allocator);

            heap.add(Move{
                .places = sortPlaces(p1, p2),
                .score = score1 + score2,
            });
        }
    }
    const moves = allocator.alloc(Move, heap.len) catch unreachable;
    return heap.sorted(moves); // TODO: unsorted
}

fn sortPlaces(p1: Place, p2: Place) [2]Place {
    return if (p1.x < p2.x or p1.x == p2.x and p1.y > p2.y)
        [2]Place{ p1, p2 }
    else
        [2]Place{ p2, p1 };
}

fn ratePlace(self: Self, place: Place, comptime player: Stone) i32 {
    const x = place.x;
    const y = place.y;
    var score: i32 = 0;

    {
        const start_x: usize = @max(x, 5) - 5;
        const end_x: usize = @min(x + 1, board_size - 5);
        var players: i32 = @intFromEnum(self.board[y][start_x]);
        for (1..5) |i| {
            players += @intFromEnum(self.board[y][start_x + i]);
        }
        for (start_x..end_x) |dx| {
            players += @intFromEnum(self.board[y][dx + 5]);
            score += calcScore(player, players);
            players -= @intFromEnum(self.board[y][dx]);
        }
    }

    {
        const start_y: usize = @max(y, 5) - 5;
        const end_y: usize = @min(y + 1, board_size - 5);
        var players: i32 = @intFromEnum(self.board[start_y][x]);
        for (1..5) |i| {
            players += @intFromEnum(self.board[start_y + i][x]);
        }
        for (start_y..end_y) |dy| {
            players += @intFromEnum(self.board[dy + 5][x]);
            score += calcScore(player, players);
            players -= @intFromEnum(self.board[dy][x]);
        }
    }

    b1: {
        const min: usize = @min(x, y, 5);
        const max: usize = @max(x, y);

        if (max - min >= board_size - 5) break :b1;

        const start_x = x - min;
        const start_y = y - min;
        const count = @min(min + 1, board_size - max, board_size - 5 + min - max);

        var players: i32 = @intFromEnum(self.board[start_y][start_x]);
        for (1..5) |i| {
            players += @intFromEnum(self.board[start_y + i][start_x + i]);
        }
        for (start_x.., start_y.., 0..count) |xx, yy, _| {
            players += @intFromEnum(self.board[yy + 5][xx + 5]);
            score += calcScore(player, players);
            players -= @intFromEnum(self.board[yy][xx]);
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

        var players: i32 = @intFromEnum(self.board[start_y][start_x]);
        for (1..5) |i| {
            players += @intFromEnum(self.board[start_y + i][start_x - i]);
        }
        for (0..count) |c| {
            players += @intFromEnum(self.board[start_y + 5 + c][start_x - 5 - c]);
            score += calcScore(player, players);
            players -= @intFromEnum(self.board[start_y + c][start_x - c]);
        }
    }

    return score;
}

fn winningMove(p1: Place, p2: Place, score: i32, allocator: std.mem.Allocator) []Move {
    var moves = allocator.alloc(Move, 1) catch unreachable;
    moves[0] = Move{
        .places = sortPlaces(p1, p2),
        .decision = .win,
        .score = score,
    };
    return moves;
}

fn calcScores(self: Self, comptime player: Stone) Scores {
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
            const eScore = calcScore(player, hStones);
            const sScore = calcScore(player, vStones);
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
            const swScore = calcScore(player, swStones);
            const neScore = calcScore(player, neStones);
            const nwScore = calcScore(player, nwStones);
            const seScore = calcScore(player, seStones);
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
        const nwseScore = calcScore(player, nwseStones);
        const neswScore = calcScore(player, neswStones);
        inline for (0..6) |c| {
            scores[b + c][b + c] += nwseScore;
            scores[b + c][board_size - 1 - b - c] += neswScore;
        }
        nwseStones -= @intFromEnum(self.board[b][b]);
        neswStones -= @intFromEnum(self.board[b][board_size - 1 - b]);
    }
    return scores;
}

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

const one_player = 1;
const two_players = 5;
const three_players = 20;
const four_players = 60;
const five_players = 120;
const six_players = 2048;

fn calcScore(comptime player: Stone, stones: i32) i32 {
    return if (player == .black)
        switch (stones) {
            0x00 => one_player,
            0x01 => two_players - one_player,
            0x02 => three_players - two_players,
            0x03 => four_players - three_players,
            0x04 => five_players - four_players,
            0x05 => six_players,
            0x10 => one_player,
            0x20 => two_players,
            0x30 => three_players,
            0x40 => four_players,
            0x50 => five_players,
            else => 0,
        }
    else switch (stones) {
        0x00 => -one_player,
        0x01 => -one_player,
        0x02 => -two_players,
        0x03 => -three_players,
        0x04 => -four_players,
        0x05 => -five_players,
        0x10 => one_player - two_players,
        0x20 => two_players - three_players,
        0x30 => three_players - four_players,
        0x40 => four_players - five_players,
        0x50 => -six_players,
        else => 0,
    };
}

pub fn scoreBoard(self: Self) i32 {
    var result: i32 = 0;

    for (0..board_size) |a| {
        var h_players: i32 = 0;
        var v_players: i32 = 0;

        for (0..5) |b| {
            h_players += @intFromEnum(self.board[a][b]);
            v_players += @intFromEnum(self.board[b][a]);
        }
        for (5..board_size) |b| {
            h_players += @intFromEnum(self.board[a][b]);
            result += debugRate(h_players);
            h_players -= @intFromEnum(self.board[a][b - 5]);

            v_players += @intFromEnum(self.board[b][a]);
            result += debugRate(v_players);
            v_players -= @intFromEnum(self.board[b - 5][a]);
        }
    }

    for (0..board_size - 5) |y| {
        var sw_players: i32 = 0;
        var se_players: i32 = 0;

        for (0..5) |i| {
            sw_players += @intFromEnum(self.board[y + i][i]);
            se_players += @intFromEnum(self.board[y + i][board_size - 1 - i]);
        }
        for (5..board_size - y) |i| {
            sw_players += @intFromEnum(self.board[y + i][i]);
            result += debugRate(sw_players);
            sw_players -= @intFromEnum(self.board[y + i - 5][i - 5]);

            se_players += @intFromEnum(self.board[y + i][board_size - 1 - i]);
            result += debugRate(se_players);
            se_players -= @intFromEnum(self.board[y + i - 5][board_size + 4 - i]);
        }
    }

    for (1..board_size - 5) |x| {
        var ne_players: i32 = 0;
        var nw_players: i32 = 0;

        for (0..5) |i| {
            ne_players += @intFromEnum(self.board[i][x + i]);
            nw_players += @intFromEnum(self.board[i][board_size - 1 - x - i]);
        }

        for (5..board_size - x) |i| {
            ne_players += @intFromEnum(self.board[i][x + i]);
            result += debugRate(ne_players);
            ne_players -= @intFromEnum(self.board[i - 5][x + i - 5]);

            nw_players += @intFromEnum(self.board[i][board_size - 1 - x - i]);
            result += debugRate(nw_players);
            nw_players -= @intFromEnum(self.board[i - 5][board_size + 4 - x - i]);
        }
    }

    return result;
}

fn debugRate(players: i32) i32 {
    return switch (players) {
        0x01 => one_player,
        0x02 => two_players,
        0x03 => three_players,
        0x04 => four_players,
        0x05 => five_players,
        0x10 => -one_player,
        0x20 => -two_players,
        0x30 => -three_players,
        0x40 => -four_players,
        0x50 => -five_players,
        else => 0,
    };
}

pub fn printBoard(self: Self) void {
    print("\n  ", .{});
    for (0..board_size) |i| {
        print(" {c}", .{@as(u8, @intCast(i)) + 'a'});
    }
    for (0..board_size) |y| {
        print("\n{:2}", .{board_size - y});
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

            print("{s}", .{piece});
        }
        print(" {:2}", .{board_size - y});
    }

    print("\n  ", .{});
    for (0..board_size) |i| {
        print(" {c}", .{@as(u8, @intCast(i)) + 'a'});
    }
}

test "Move.str" {
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
    print("\nscore = {d} \n", .{score});
    const moves = game.possibleMoves(std.testing.allocator);
    defer std.testing.allocator.free(moves);
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
    print("\n{d} result {d}\n", .{ nanos / 1_000_000, result });
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
    print("\ntime {d}ms result {d}\n", .{ nanos / 1_000_000, result });
}

test "placeStone" {
    var game = Self{};

    var rng = Prng.init(1);
    var score: i32 = 0;
    for (1..100) |_| {
        const x: usize = @intCast(rng.next() % board_size);
        const y: usize = @intCast(rng.next() % board_size);
        const player: Stone = if (rng.next() % 2 == 0) .black else .white;
        if (game.board[y][x] != .none) continue;
        score += if (player == .black) game.ratePlace(Place.init(x, y), .black) else game.ratePlace(Place.init(x, y), .white);
        game.board[y][x] = player;
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
        const player: Stone = if (rng.next() % 2 == 0) .black else .white;
        if (game.board[y][x] != .none) continue;
        const scores = if (player == .black) game.calcScores(.black) else game.calcScores(.white);
        score += scores[y][x];
        game.board[y][x] = player;
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
            const player: Stone = if (rng.next() % 2 == 0) .black else .white;
            if (game.board[y][x] != .none) continue;
            const scores = if (player == .black) game.calcScores(.black) else game.calcScores(.white);
            score += scores[y][x];
            game.board[y][x] = player;
        }
    }
    std.mem.doNotOptimizeAway(score);
    print("\ntime {}ms\n", .{timer.read() / 1_000_000});
}

test "possibleMoves" {
    var game = Self{};

    var timer = try std.time.Timer.start();
    var n_moves: usize = 0;

    for (0..10_000) |_| {
        const moves = game.possibleMoves(std.testing.allocator);
        n_moves += moves.len;
        std.testing.allocator.free(moves);
    }

    print("\ntime {}ms", .{timer.read() / 1_000_000});
    print("\nmoves {d}\n", .{n_moves});
}
