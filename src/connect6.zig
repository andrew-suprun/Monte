const std = @import("std");
const Prng = std.rand.Random.DefaultPrng;
const print = std.debug.print;
// const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub fn Move(Player: type) type {
    return struct {
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

        pub fn print(self: @This()) void {
            std.debug.print("[{}:{}, {}:{}, player: {s}, winner: {s}, score: {d}]", .{
                self.places[0].x,
                self.places[0].y,
                self.places[1].x,
                self.places[1].y,
                self.player.str(),
                if (self.winner) |w| w.str() else "?",
                self.score,
            });
        }
    };
}

const Place = struct {
    x: u8,
    y: u8,

    inline fn init(x: usize, y: usize) @This() {
        return @This(){ .x = @intCast(x), .y = @intCast(y) };
    }
};

pub fn C6(Player: type, comptime board_size: comptime_int, comptime max_moves: usize) type {
    return struct {
        board: [board_size][board_size]Stone = [1][board_size]Stone{[1]Stone{.none} ** board_size} ** board_size,
        n_moves: usize = 0,

        const Self = @This();
        const C6Move = Move(Player);
        const Scores = [board_size][board_size]i32;

        pub fn maxMoves() comptime_int {
            return max_moves;
        }

        pub fn makeMove(self: *Self, move: C6Move) void {
            const stone = Stone.fromPlayer(move.player);
            const p1 = move.places[0];
            const p2 = move.places[1];
            self.board[p1.y][p1.x] = stone;
            self.board[p2.y][p2.x] = stone;
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
            const stone = self.nextStone();
            var place_list: [board_size * board_size]Place = undefined;
            if (stone == .black) {
                const scores = self.calcScores(.black);
                const places = self.possiblePlaces(.black, scores, &place_list);
                return self.selectMoves(.black, scores, places, buf);
            } else {
                const scores = self.calcScores(.white);
                const places = self.possiblePlaces(.white, scores, &place_list);
                return self.selectMoves(.white, scores, places, buf);
            }
        }

        fn possiblePlaces(self: Self, comptime stone: Stone, scores: Scores, place_list: []Place) []Place {
            var heap = if (stone == .black) HeapPlaceBlack.init(scores) else HeapPlaceWhite.init(scores);
            for (0..board_size) |y| {
                for (0..board_size) |x| {
                    if (self.board[y][x] == .none) heap.add(Place.init(x, y));
                }
            }
            return heap.sorted(place_list);
        }

        fn selectMoves(self: *Self, comptime stone: Stone, scores: Scores, places: []Place, buf: []C6Move) []C6Move {
            var heap = if (stone == .black) HeapBlack.init({}) else HeapWhite.init({});

            if (scores[places[0].y][places[0].x] == 0) {
                buf[0] = C6Move{
                    .places = [2]Place{ places[0], places[1] },
                    .player = stone.player(),
                    .score = 0,
                    .winner = .none,
                };
                return buf[0..1];
            }

            for (places[0 .. places.len - 1], 0..) |p1, i| {
                const score1 = scores[p1.y][p1.x];
                if (score1 > 1024)
                    return winningMove(p1, p1, .first, score1, buf)
                else if (score1 < -1024)
                    return winningMove(p1, p1, .second, score1, buf);

                for (i + 1..places.len) |j| {
                    var score2: i32 = undefined;
                    const p2 = places[j];
                    if (p1.x == p2.x or p1.y == p2.y or p1.x + p1.y == p2.x + p2.y or p1.x + p2.y == p2.x + p1.y) {
                        self.board[p1.y][p1.x] = stone;
                        score2 = self.ratePlace(p2, stone);
                        self.board[p1.y][p1.x] = .none;
                    } else {
                        score2 = scores[p2.y][p2.x];
                    }

                    if (score2 > 1024)
                        return winningMove(p1, p2, .first, score2, buf)
                    else if (score2 < -1024)
                        return winningMove(p1, p2, .second, score2, buf);

                    heap.add(C6Move{
                        .places = [2]Place{ p1, p2 },
                        .player = stone.player(),
                        .score = score1 + score2,
                    });
                }
            }
            return heap.sorted(buf);
        }

        fn ratePlace(self: Self, place: Place, stone: Stone) i32 {
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

        fn winningMove(p1: Place, p2: Place, player: Player, score: i32, buf: []C6Move) []C6Move {
            buf[0] = C6Move{
                .places = [2]Place{ p1, p2 },
                .player = player,
                .winner = player,
                .score = score,
            };
            return buf[0..1];
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

        const HeapBlack = @import("heap.zig").Heap(C6Move, void, cmpBlack, max_moves);
        fn cmpBlack(_: void, a: C6Move, b: C6Move) bool {
            return a.score < b.score;
        }

        const HeapWhite = @import("heap.zig").Heap(C6Move, void, cmpWhite, max_moves);
        fn cmpWhite(_: void, a: C6Move, b: C6Move) bool {
            return a.score > b.score;
        }

        const HeapPlaceBlack = @import("heap.zig").Heap(Place, Scores, cmpPlaceBlack, max_moves);
        fn cmpPlaceBlack(scores: Scores, a: Place, b: Place) bool {
            return scores[a.y][a.x] < scores[b.y][b.x];
        }

        const HeapPlaceWhite = @import("heap.zig").Heap(Place, Scores, cmpPlaceWhite, max_moves);
        fn cmpPlaceWhite(scores: Scores, a: Place, b: Place) bool {
            return scores[a.y][a.x] > scores[b.y][b.x];
        }

        const Stone = enum(u8) {
            none = 0x00,
            black = 0x01,
            white = 0x10,

            fn fromPlayer(p: Player) @This() {
                return switch (p) {
                    .none => .none,
                    .first => .black,
                    .second => .white,
                };
            }

            fn player(self: @This()) Player {
                return switch (self) {
                    .none => .none,
                    .black => .first,
                    .white => .second,
                };
            }

            fn str(self: @This()) []const u8 {
                return switch (self) {
                    .none => "=",
                    .black => "X",
                    .white => "O",
                };
            }
        };

        inline fn nextStone(self: Self) Stone {
            return if (self.n_moves % 2 == 0) .black else .white;
        }

        inline fn nextPlayer(self: Self) Player {
            return if (self.n_moves % 2 == 0) .first else .second;
        }

        const one_stone = 1;
        const two_stones = 4;
        const three_stones = 16;
        const four_stones = 64;
        const five_stones = 128;
        const six_stones = 2048;

        fn calcScore(stone: Stone, stones: i32) i32 {
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
        fn debugScoreBoard(self: Self) i32 {
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
                    result += switch (v_stones) {
                        0x06 => return .{ .score = result, .winner = .black },
                        0x60 => return .{ .score = result, .winner = .white },
                        else => debugRate(v_stones),
                    };
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

            return .{ .score = result, .winner = .none };
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

        pub fn printBoard(self: Self, move: C6Move) void {
            const place1 = move.places[0];
            const place2 = move.places[1];
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
                        .black => if (place1.x == x and place1.y == y or place2.x == x and place2.y == y) print(" #", .{}) else print(" X", .{}),
                        .white => if (place1.x == x and place1.y == y or place2.x == x and place2.y == y) print(" @", .{}) else print(" O", .{}),
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
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var game = Game{};
    const move = Move(Player){ .places = [2]Place{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    game.makeMove(move);
    game.printBoard(move);
    const score = game.debugScoreBoard();
    print("\nscore = {d} winner = {any}\n", .{ score.score, score.winner });
    var buf: [Game.maxMoves()]Move(Player) = undefined;
    const moves = game.possibleMoves(&buf);
    print("\npossible moves {d}", .{moves.len});
    for (moves) |m| {
        game.makeMove(m);
    }
    game.printBoard(move);
}

test "scoreBoard" {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var rng = Prng.init(1);
    var start = try std.time.Timer.start();
    var result: i32 = 0;
    var game = Game{};
    for (0..10_000) |_| {
        for (0..100) |_| {
            game.board[9][9] = if (rng.next() % 2 == 0) .black else .white;
            result += game.debugScoreBoard().score;
        }
    }
    const nanos = start.read();
    print("\n{d} result {d}\n", .{ nanos / 1_000_000, result });
}

test "ratePlace" {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var rng = Prng.init(1);
    var start = try std.time.Timer.start();
    var result: i32 = 0;
    var game = Game{};
    for (0..10_000) |_| {
        for (0..100) |_| {
            const r = game.ratePlace(Place.init(9, 9), if (rng.next() % 2 == 0) .black else .white);
            result += r.score;
        }
    }
    const nanos = start.read();
    print("\ntime {d}ms result {d}\n", .{ nanos / 1_000_000, result });
}

test "placeStone" {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var game = Game{};

    var rng = Prng.init(1);
    var score: i32 = 0;
    for (1..100) |_| {
        const x: usize = @intCast(rng.next() % 19);
        const y: usize = @intCast(rng.next() % 19);
        const stone: Game.Stone = if (rng.next() % 2 == 0) .black else .white;
        if (game.board[y][x] != .none) continue;
        score += game.ratePlace(Place.init(x, y), stone);
        game.board[y][x] = stone;
        const score2 = game.debugScoreBoard();
        try std.testing.expectEqual(score2.score, score);
    }
}

test "calcScores" {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var game = Game{};

    var rng = Prng.init(1);
    var score: i32 = 0;
    for (1..100) |_| {
        const x: usize = @intCast(rng.next() % 19);
        const y: usize = @intCast(rng.next() % 19);
        const stone: Game.Stone = if (rng.next() % 2 == 0) .black else .white;
        if (game.board[y][x] != .none) continue;
        const scores = game.calcScores(stone);
        score += scores[y][x];
        game.board[y][x] = stone;
        const score2 = game.debugScoreBoard();
        try std.testing.expectEqual(score2.score, score);
    }
}

test "bench-calcScores" {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var game = Game{};

    var rng = Prng.init(1);

    var score: i32 = 0;
    var timer = try std.time.Timer.start();
    for (0..1_000_000) |_| {
        for (1..100) |_| {
            const x: usize = @intCast(rng.next() % 19);
            const y: usize = @intCast(rng.next() % 19);
            const stone: Game.Stone = if (rng.next() % 2 == 0) .black else .white;
            if (game.board[y][x] != .none) continue;
            const scores = game.calcScores(stone);
            score += scores[y][x];
            game.board[y][x] = stone;
        }
    }
    std.mem.doNotOptimizeAway(score);
    print("\ntime {}ms\n", .{timer.read() / 1_000_000});
}

test "possibleMoves" {
    const Player = enum {
        second,
        none,
        first,

        fn str(self: @This()) []const u8 {
            return switch (self) {
                .none => ".",
                .first => "X",
                .second => "O",
            };
        }
    };
    const Game = C6(Player, 19, 100);
    var game = Game{};

    var move = Move(Player){ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    game.makeMove(move);

    move = Move(Player){ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
    game.makeMove(move);

    move = Move(Player){ .places = .{ .{ .x = 8, .y = 10 }, .{ .x = 9, .y = 10 } }, .score = 71, .player = .first };
    game.makeMove(move);

    move = Move(Player){ .places = .{ .{ .x = 9, .y = 8 }, .{ .x = 7, .y = 10 } }, .score = -87, .player = .second };
    game.makeMove(move);

    var buf: [Game.maxMoves()]Move(Player) = undefined;
    var timer = try std.time.Timer.start();
    var n_moves: usize = 0;

    for (0..10_000) |_| {
        n_moves += game.possibleMoves(&buf).len;
    }

    print("\ntime {}ms", .{timer.read() / 1_000_000});
    print("\nmoves {d}\n", .{n_moves});
}

test "possiblePlaces" {
    const Player = enum {
        second,
        none,
        first,

        fn str(self: @This()) []const u8 {
            return switch (self) {
                .none => ".",
                .first => "X",
                .second => "O",
            };
        }
    };
    const Game = C6(Player, 19, 100);
    var game = Game{};

    var move = Move(Player){ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
    game.makeMove(move);

    move = Move(Player){ .places = .{ .{ .x = 8, .y = 9 }, .{ .x = 8, .y = 8 } }, .score = 0, .player = .second };
    game.makeMove(move);

    move = Move(Player){ .places = .{ .{ .x = 8, .y = 10 }, .{ .x = 9, .y = 10 } }, .score = 71, .player = .first };
    game.makeMove(move);

    move = Move(Player){ .places = .{ .{ .x = 9, .y = 8 }, .{ .x = 7, .y = 10 } }, .score = -87, .player = .second };
    game.makeMove(move);

    var places: [19 * 19]Place = undefined;
    var timer = try std.time.Timer.start();
    var n_moves: usize = 0;

    for (0..1_000_000) |_| {
        n_moves += game.possiblePlaces(&places).len;
    }

    print("\ntime {}ms", .{timer.read() / 1_000_000});
    print("\nmoves {d}\n", .{n_moves});
}
