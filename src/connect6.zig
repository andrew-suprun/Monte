board: [board_size][board_size]Player = [1][board_size]Player{[1]Player{.none} ** board_size} ** board_size,
n_moves: usize = 0,

const std = @import("std");
const print = std.debug.print;
const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub const board_size: comptime_int = 19;
pub const max_moves: comptime_int = if (debug) 6 else 128;

pub const Player = enum(u8) {
    none = 0x00,
    first = 0x01,
    second = 0x10,

    pub fn max(self: Player, other: Player) Player {
        switch (self) {
            .none => if (other == .first) return .first else return .none,
            .first => return self,
            .second => return other,
        }
    }

    pub fn min(self: Player, other: Player) Player {
        switch (self) {
            .none => if (other == .second) return .second else return .none,
            .first => return other,
            .second => return self,
        }
    }

    pub fn str(self: @This()) []const u8 {
        return switch (self) {
            .none => "=",
            .first => "X",
            .second => "O",
        };
    }
};

pub const Move = struct {
    places: [2]Place,
    player: Player,
    winner: ?Player = null,
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
        std.debug.print("[{c}{d} {c}{d}, player: {s}, winner: {s}, score: {d}]", .{
            @as(u8, @intCast(self.places[0].x)) + 'a',
            board_size - self.places[0].y,
            @as(u8, @intCast(self.places[1].x)) + 'a',
            board_size - self.places[1].y,
            self.player.str(),
            if (self.winner) |w| w.str() else "-",
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
const C6Move = Move;
const Scores = [board_size][board_size]i32;

pub fn initMove(self: *Self, note: []const u8) !C6Move {
    var place_tokens = std.mem.tokenizeScalar(u8, note, '+');
    const places: [2]Place = .{
        try parseToken(place_tokens.next()),
        try parseToken(place_tokens.next()),
    };
    return self.initMoveFromPlaces(places);
}

pub fn initMoveFromPlaces(self: *Self, places: [2]Place) C6Move {
    const player = self.nextPlayer();
    const score1 = if (player == .first)
        self.ratePlace(places[0], .first)
    else
        self.ratePlace(places[0], .second);
    const score2 = if (!places[0].eql(places[1])) blk: {
        self.board[places[0].y][places[0].x] = player;
        defer self.board[places[0].y][places[0].x] = .none;

        break :blk if (player == .first)
            self.ratePlace(places[1], .first)
        else
            self.ratePlace(places[1], .second);
    } else 0;
    var winner: ?Player = null;
    if (score1 + score2 > 1024) winner = .first;
    if (score1 + score2 < -1024) winner = .second;
    return C6Move{
        .places = sortPlaces(places[0], places[1]),
        .player = player,
        .score = score1 + score2,
        .winner = winner,
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

pub fn makeMove(self: *Self, move: C6Move) void {
    const player = move.player;

    const p1 = move.places[0];
    const p2 = move.places[1];

    self.board[p1.y][p1.x] = player;
    self.board[p2.y][p2.x] = player;

    self.n_moves += 1;
}

pub fn undoMove(self: *Self, move: C6Move) void {
    const p1 = move.places[0];
    const p2 = move.places[1];

    self.board[p1.y][p1.x] = .none;
    self.board[p2.y][p2.x] = .none;

    self.n_moves -= 1;
}

pub fn possibleMoves(self: *Self, buf: []C6Move) []C6Move {
    const player = self.nextPlayer();
    var place_buf: [board_size * board_size]Place = undefined;
    if (player == .first) {
        const scores = self.calcScores(.first);
        const place_list = self.possiblePlaces(.first, scores, &place_buf);
        return self.selectMoves(.first, scores, place_list, buf);
    } else {
        const scores = self.calcScores(.second);
        const place_list = self.possiblePlaces(.second, scores, &place_buf);
        return self.selectMoves(.second, scores, place_list, buf);
    }
}

fn possiblePlaces(self: Self, comptime player: Player, scores: Scores, place_list: []Place) []Place {
    var heap = if (player == .first) HeapPlaceBlack.init(scores) else HeapPlaceWhite.init(scores);
    for (0..board_size) |y| {
        for (0..board_size) |x| {
            if (self.board[y][x] == .none) heap.add(Place.init(x, y));
        }
    }
    return heap.sorted(place_list);
}

fn selectMoves(self: *Self, comptime player: Player, scores: Scores, place_list: []Place, buf: []C6Move) []C6Move {
    var heap = if (player == .first) HeapBlack.init({}) else HeapWhite.init({});

    if (scores[place_list[0].y][place_list[0].x] == 0) {
        buf[0] = C6Move{
            .places = sortPlaces(place_list[0], place_list[1]),
            .player = player,
            .score = 0,
            .winner = .none,
        };
        return buf[0..1];
    }

    for (place_list[0 .. place_list.len - 1], 0..) |p1, i| {
        const score1 = scores[p1.y][p1.x];
        if (score1 > 1024)
            return winningMove(p1, p1, .first, score1, buf)
        else if (score1 < -1024)
            return winningMove(p1, p1, .second, score1, buf);

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

            if (score2 > 1024)
                return winningMove(p1, p2, .first, score2, buf)
            else if (score2 < -1024)
                return winningMove(p1, p2, .second, score2, buf);

            heap.add(C6Move{
                .places = sortPlaces(p1, p2),
                .player = player,
                .score = score1 + score2,
            });
        }
    }
    return heap.sorted(buf);
}

fn sortPlaces(p1: Place, p2: Place) [2]Place {
    return if (p1.x < p2.x or p1.x == p2.x and p1.y > p2.y)
        [2]Place{ p1, p2 }
    else
        [2]Place{ p2, p1 };
}

fn ratePlace(self: Self, place: Place, comptime player: Player) i32 {
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

fn winningMove(p1: Place, p2: Place, player: Player, score: i32, buf: []C6Move) []C6Move {
    buf[0] = C6Move{
        .places = sortPlaces(p1, p2),
        .player = player,
        .winner = player,
        .score = score,
    };
    return buf[0..1];
}

fn calcScores(self: Self, comptime player: Player) Scores {
    var scores = [1][board_size]i32{[1]i32{0} ** board_size} ** board_size;

    for (0..board_size) |a| {
        var hPlayers: i32 = @intFromEnum(self.board[a][0]);
        var vPlayers: i32 = @intFromEnum(self.board[0][a]);
        for (1..5) |b| {
            hPlayers += @intFromEnum(self.board[a][b]);
            vPlayers += @intFromEnum(self.board[b][a]);
        }
        for (0..board_size - 5) |b| {
            hPlayers += @intFromEnum(self.board[a][b + 5]);
            vPlayers += @intFromEnum(self.board[b + 5][a]);
            const eScore = calcScore(player, hPlayers);
            const sScore = calcScore(player, vPlayers);
            inline for (0..6) |c| {
                scores[a][b + c] += eScore;
                scores[b + c][a] += sScore;
            }
            hPlayers -= @intFromEnum(self.board[a][b]);
            vPlayers -= @intFromEnum(self.board[b][a]);
        }
    }

    for (1..board_size - 5) |a| {
        var swPlayers: i32 = @intFromEnum(self.board[a][0]);
        var nePlayers: i32 = @intFromEnum(self.board[0][a]);
        var nwPlayers: i32 = @intFromEnum(self.board[board_size - 1 - a][0]);
        var sePlayers: i32 = @intFromEnum(self.board[a][board_size - 1]);
        for (1..5) |b| {
            swPlayers += @intFromEnum(self.board[a + b][b]);
            nePlayers += @intFromEnum(self.board[b][a + b]);
            nwPlayers += @intFromEnum(self.board[board_size - 1 - a - b][b]);
            sePlayers += @intFromEnum(self.board[a + b][board_size - 1 - b]);
        }

        for (0..board_size - 5 - a) |b| {
            swPlayers += @intFromEnum(self.board[a + b + 5][b + 5]);
            nePlayers += @intFromEnum(self.board[b + 5][a + b + 5]);
            nwPlayers += @intFromEnum(self.board[board_size - 6 - a - b][b + 5]);
            sePlayers += @intFromEnum(self.board[a + b + 5][board_size - 6 - b]);
            const swScore = calcScore(player, swPlayers);
            const neScore = calcScore(player, nePlayers);
            const nwScore = calcScore(player, nwPlayers);
            const seScore = calcScore(player, sePlayers);
            inline for (0..6) |c| {
                scores[a + b + c][b + c] += swScore;
                scores[b + c][a + b + c] += neScore;
                scores[board_size - 1 - a - b - c][b + c] += nwScore;
                scores[a + b + c][board_size - 1 - b - c] += seScore;
            }
            swPlayers -= @intFromEnum(self.board[a + b][b]);
            nePlayers -= @intFromEnum(self.board[b][a + b]);
            nwPlayers -= @intFromEnum(self.board[board_size - 1 - a - b][b]);
            sePlayers -= @intFromEnum(self.board[a + b][board_size - 1 - b]);
        }
    }
    var nwsePlayers: i32 = @intFromEnum(self.board[0][0]);
    var neswPlayers: i32 = @intFromEnum(self.board[0][board_size - 1]);
    for (1..5) |a| {
        nwsePlayers += @intFromEnum(self.board[a][a]);
        neswPlayers += @intFromEnum(self.board[a][board_size - 1 - a]);
    }
    for (0..board_size - 5) |b| {
        nwsePlayers += @intFromEnum(self.board[b + 5][b + 5]);
        neswPlayers += @intFromEnum(self.board[b + 5][board_size - 6 - b]);
        const nwseScore = calcScore(player, nwsePlayers);
        const neswScore = calcScore(player, neswPlayers);
        inline for (0..6) |c| {
            scores[b + c][b + c] += nwseScore;
            scores[b + c][board_size - 1 - b - c] += neswScore;
        }
        nwsePlayers -= @intFromEnum(self.board[b][b]);
        neswPlayers -= @intFromEnum(self.board[b][board_size - 1 - b]);
    }
    return scores;
}

const HeapBlack = @import("heap.zig").Heap(C6Move, void, cmpBlack, max_moves);
fn cmpBlack(_: void, a: C6Move, b: C6Move) bool {
    return a.score < b.score;
}

const HeapWhite = @import("heap.zig").Heap(C6Move, void, cmpWhite, max_moves);
fn cmpWhite(_: void, a: C6Move, b: C6Move) bool {
    return a.score > b.score;
}

const HeapPlaceBlack = @import("heap.zig").Heap(Place, Scores, cmpPlaceBlack, max_moves / 2);
fn cmpPlaceBlack(scores: Scores, a: Place, b: Place) bool {
    return scores[a.y][a.x] < scores[b.y][b.x];
}

const HeapPlaceWhite = @import("heap.zig").Heap(Place, Scores, cmpPlaceWhite, max_moves / 2);
fn cmpPlaceWhite(scores: Scores, a: Place, b: Place) bool {
    return scores[a.y][a.x] > scores[b.y][b.x];
}

inline fn nextPlayer(self: Self) Player {
    return if (self.n_moves % 2 == 0) .first else .second;
}

const one_player = 1;
const two_players = 5;
const three_players = 20;
const four_players = 60;
const five_players = 120;
const six_players = 2048;

fn calcScore(comptime player: Player, players: i32) i32 {
    return if (player == .first)
        switch (players) {
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
    else switch (players) {
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
fn debugScoreBoard(self: Self) i32 {
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

pub fn printBoard(self: Self, move: C6Move) void {
    const place1 = move.places[0];
    const place2 = move.places[1];
    print("\n  ", .{});
    for (0..board_size) |i| {
        print(" {c}", .{@as(u8, @intCast(i)) + 'a'});
    }

    for (0..board_size) |y| {
        print("\n{:2}", .{board_size - y});
        for (0..board_size) |x| {
            const place = Place.init(x, y);
            switch (self.board[y][x]) {
                .first => if (place.eql(place1) or place.eql(place2)) print("─#", .{}) else print("─X", .{}),
                .second => if (place.eql(place1) or place.eql(place2)) print("─@", .{}) else print("─O", .{}),
                else => {
                    if (y == 0) {
                        if (x == 0) print(" ┌", .{}) else if (x == board_size - 1) print("─┐", .{}) else print("─┬", .{});
                    } else if (y == board_size - 1)
                        if (x == 0) print(" └", .{}) else if (x == board_size - 1) print("─┘", .{}) else print("─┴", .{})
                    else if (x == 0) print(" ├", .{}) else if (x == board_size - 1) print("─┤", .{}) else print("─┼", .{});
                },
            }
        }
        print(" {:2}", .{board_size - y});
    }

    print("\n  ", .{});
    for (0..board_size) |i| {
        print(" {c}", .{@as(u8, @intCast(i)) + 'a'});
    }
}

test "Move.str" {
    var move = Move{ .places = .{ .{ .x = 0, .y = 18 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    var buf: [7]u8 = undefined;
    const move_str = move.str(&buf);
    try std.testing.expectEqualSlices(u8, "a1+j10", move_str);
}

test "C6" {
    var game = Self{};
    const move = try game.initMove("j10+j10");
    game.makeMove(move);
    game.printBoard(move);
    const score = game.debugScoreBoard();
    print("\nscore = {d} \n", .{score});
    var buf: [max_moves]Move = undefined;
    const moves = game.possibleMoves(&buf);
    print("\npossible moves {d}", .{moves.len});
    for (moves) |m| {
        game.makeMove(m);
    }
    game.printBoard(move);
}

const Prng = std.rand.Random.DefaultPrng;

test "scoreBoard" {
    var rng = Prng.init(1);
    var start = try std.time.Timer.start();
    var result: i32 = 0;
    var game = Self{};
    for (0..10_000) |_| {
        for (0..100) |_| {
            game.board[9][9] = if (rng.next() % 2 == 0) .first else .second;
            result += game.debugScoreBoard();
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
            const r = if (rng.next() % 2 == 0) game.ratePlace(Place.init(9, 9), .first) else game.ratePlace(Place.init(9, 9), .second);
            result += r;
        }
    }
    const nanos = start.read();
    print("\ntime {d}ms result {d}\n", .{ nanos / 1_000_000, result });
}

test "placePlayer" {
    var game = Self{};

    var rng = Prng.init(1);
    var score: i32 = 0;
    for (1..100) |_| {
        const x: usize = @intCast(rng.next() % board_size);
        const y: usize = @intCast(rng.next() % board_size);
        const player: Player = if (rng.next() % 2 == 0) .first else .second;
        if (game.board[y][x] != .none) continue;
        score += if (player == .first) game.ratePlace(Place.init(x, y), .first) else game.ratePlace(Place.init(x, y), .second);
        game.board[y][x] = player;
        const score2 = game.debugScoreBoard();
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
        const player: Player = if (rng.next() % 2 == 0) .first else .second;
        if (game.board[y][x] != .none) continue;
        const scores = if (player == .first) game.calcScores(.first) else game.calcScores(.second);
        score += scores[y][x];
        game.board[y][x] = player;
        const score2 = game.debugScoreBoard();
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
            const player: Player = if (rng.next() % 2 == 0) .first else .second;
            if (game.board[y][x] != .none) continue;
            const scores = if (player == .first) game.calcScores(.first) else game.calcScores(.second);
            score += scores[y][x];
            game.board[y][x] = player;
        }
    }
    std.mem.doNotOptimizeAway(score);
    print("\ntime {}ms\n", .{timer.read() / 1_000_000});
}

test "possibleMoves" {
    var game = Self{};

    var move = Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    game.makeMove(move);

    move = Move{ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
    game.makeMove(move);

    move = Move{ .places = .{ .{ .x = 8, .y = 10 }, .{ .x = 9, .y = 10 } }, .score = 71, .player = .first };
    game.makeMove(move);

    move = Move{ .places = .{ .{ .x = 9, .y = 8 }, .{ .x = 7, .y = 10 } }, .score = -87, .player = .second };
    game.makeMove(move);

    var buf: [max_moves]Move = undefined;
    var timer = try std.time.Timer.start();
    var n_moves: usize = 0;

    for (0..10_000) |_| {
        n_moves += game.possibleMoves(&buf).len;
    }

    print("\ntime {}ms", .{timer.read() / 1_000_000});
    print("\nmoves {d}\n", .{n_moves});
}
