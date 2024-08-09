const std = @import("std");
const Prng = std.rand.Random.DefaultPrng;
const print = std.debug.print;
// const debug = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

pub fn C6(Player: type, comptime board_size: comptime_int, comptime max_moves: usize) type {
    return struct {
        board: [board_size][board_size]Stone = [1][board_size]Stone{[1]Stone{.none} ** board_size} ** board_size,
        n_moves: usize = 0,

        pub const Place = struct {
            x: u8,
            y: u8,

            inline fn init(x: usize, y: usize) @This() {
                return @This(){ .x = @intCast(x), .y = @intCast(y) };
            }
        };

        pub const Move = struct {
            places: [2]Place,
            player: Player,
            score: i32,

            fn print(self: @This()) void {
                std.debug.print("[{}:{}, {}:{}, {s}, {d}]", .{
                    self.places[0].x,
                    self.places[0].y,
                    self.places[1].x,
                    self.places[1].y,
                    self.player.str(),
                    self.score,
                });
            }
        };

        pub fn maxMoves() comptime_int {
            return max_moves;
        }

        pub fn makeMove(self: *Self, move: Move) void {
            const stone = Stone.fromPlayer(move.player);
            const p1 = move.places[0];
            const p2 = move.places[1];
            self.board[p1.y][p1.x] = stone;
            self.board[p2.y][p2.x] = stone;
            self.n_moves += 1;
        }

        pub fn possibleMoves(self: *Self, buf: []Move) []Move {
            var places: [board_size][board_size]bool = [1][board_size]bool{[1]bool{false} ** board_size} ** board_size;
            for (0..board_size) |y| {
                for (0..board_size) |x| {
                    const x_start = @max(2, x) - 2;
                    const x_end = @min(board_size, x + 3);
                    const y_start = @max(2, y) - 2;
                    const y_end = @min(board_size, y + 3);
                    for (y_start..y_end) |yy| {
                        for (x_start..x_end) |xx| {
                            places[yy][xx] = true;
                        }
                    }
                }
            }

            for (0..board_size) |y| {
                for (0..board_size) |x| {
                    if (self.board[y][x] != .none) places[y][x] = false;
                }
            }

            var place_list: [board_size * board_size]Place = undefined;
            var n_places: usize = 0;
            for (0..board_size) |y| {
                for (0..board_size) |x| {
                    if (places[y][x]) {
                        place_list[n_places] = Place.init(x, y);
                        n_places += 1;
                    }
                }
            }

            return if (self.nextStone() == .black)
                self.selectMoves(place_list[0..n_places], self.nextPlayer(), .black, buf)
            else
                self.selectMoves(place_list[0..n_places], self.nextPlayer(), .white, buf);
        }

        fn selectMoves(self: *Self, place_list: []Place, player: Player, comptime stone: Stone, buf: []Move) []Move {
            var heap = if (stone == .black) HeapBlack.init({}) else HeapWhite.init({});
            for (place_list[0 .. place_list.len - 1], 0..) |p1, i| {
                const score1 = self.ratePlace(p1, stone);
                if (score1.winner != .none) {
                    return winningMove(p1, p1, score1, buf);
                }
                self.board[p1.y][p1.x] = stone;
                for (place_list[i + 1 .. place_list.len]) |p2| {
                    const score2 = self.ratePlace(p2, stone);
                    if (score2.winner != .none) {
                        return winningMove(p1, p2, score2, buf);
                    }
                    heap.add(Move{
                        .places = [2]Place{ p1, p2 },
                        .player = player,
                        .score = score1.score + score2.score,
                    });
                }
                self.board[p1.y][p1.x] = .none;
            }
            return heap.sorted(buf);
        }

        fn winningMove(p1: Place, p2: Place, score: Score, buf: []Move) []Move {
            buf[0] = Move{
                .places = [2]Place{ p1, p2 },
                .player = score.winner.player(),
                .score = score.score,
            };
            return buf[0..1];
        }

        const Score = struct { score: i32, winner: Stone };
        const HeapBlack = @import("heap.zig").Heap(Move, void, cmpBlack, max_moves);
        const HeapWhite = @import("heap.zig").Heap(Move, void, cmpWhite, max_moves);

        fn cmpBlack(_: void, a: Move, b: Move) bool {
            return a.score < b.score;
        }

        fn cmpWhite(_: void, a: Move, b: Move) bool {
            return a.score > b.score;
        }

        fn ratePlace(self: Self, place: Place, stone: Stone) Score {
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
                    const d = calcDelta(stones, stone);
                    if (d.winner != .none) return d;
                    score += d.score;
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
                    if (d.winner != .none) return d;
                    score += d.score;
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
                    if (d.winner != .none) return d;
                    score += d.score;
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
                    if (d.winner != .none) return d;
                    score += d.score;
                    stones -= @intFromEnum(self.board[start_y + c][start_x - c]);
                }
            }

            return .{ .score = score, .winner = .none };
        }

        fn calcDelta(stones: i32, stone: Stone) Score {
            if (stone == .black) {
                const score: i32 = switch (stones) {
                    0x00 => one_stone,
                    0x01 => two_stones - one_stone,
                    0x02 => three_stones - two_stones,
                    0x03 => four_stones - three_stones,
                    0x04 => five_stones - four_stones,
                    0x05 => return .{ .score = 0, .winner = .black },
                    0x10 => one_stone,
                    0x20 => two_stones,
                    0x30 => three_stones,
                    0x40 => four_stones,
                    0x50 => five_stones,
                    else => 0,
                };
                return .{ .score = score, .winner = .none };
            } else {
                const score: i32 = switch (stones) {
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
                    0x50 => return .{ .score = 0, .winner = .white },
                    else => 0,
                };
                return .{ .score = score, .winner = .none };
            }
        }

        fn scoreBoard(self: Self) Score {
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
                    result += switch (h_stones) {
                        0x06 => return .{ .score = result, .winner = .black },
                        0x60 => return .{ .score = result, .winner = .white },
                        else => rate(h_stones),
                    };
                    h_stones -= @intFromEnum(self.board[a][b - 5]);

                    v_stones += @intFromEnum(self.board[b][a]);
                    result += switch (v_stones) {
                        0x06 => return .{ .score = result, .winner = .black },
                        0x60 => return .{ .score = result, .winner = .white },
                        else => rate(v_stones),
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
                    result += switch (sw_stones) {
                        0x06 => return .{ .score = result, .winner = .black },
                        0x60 => return .{ .score = result, .winner = .white },
                        else => rate(sw_stones),
                    };
                    sw_stones -= @intFromEnum(self.board[y + i - 5][i - 5]);

                    se_stones += @intFromEnum(self.board[y + i][board_size - 1 - i]);
                    result += switch (se_stones) {
                        0x06 => return .{ .score = result, .winner = .black },
                        0x60 => return .{ .score = result, .winner = .white },
                        else => rate(se_stones),
                    };
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
                    result += switch (ne_stones) {
                        0x06 => return .{ .score = result, .winner = .black },
                        0x60 => return .{ .score = result, .winner = .white },
                        else => rate(ne_stones),
                    };
                    ne_stones -= @intFromEnum(self.board[i - 5][x + i - 5]);

                    nw_stones += @intFromEnum(self.board[i][board_size - 1 - x - i]);
                    result += switch (nw_stones) {
                        0x06 => return .{ .score = result, .winner = .black },
                        0x60 => return .{ .score = result, .winner = .white },
                        else => rate(nw_stones),
                    };
                    nw_stones -= @intFromEnum(self.board[i - 5][board_size + 4 - x - i]);
                }
            }

            return .{ .score = result, .winner = .none };
        }

        const one_stone = 1;
        const two_stones = 3;
        const three_stones = 7;
        const four_stones = 15;
        const five_stones = 31;

        fn rate(stones: i32) i32 {
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

        const Self = @This();

        inline fn nextStone(self: Self) Stone {
            return if (self.n_moves % 2 == 0) .black else .white;
        }

        pub inline fn nextPlayer(self: Self) Player {
            return if (self.n_moves % 2 == 0) .first else .second;
        }

        pub fn printBoard(self: Self, move: Move) void {
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
    };
}

test C6 {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19);
    var board = Game.init();
    const move = Game.Move.init(8, 9, .second);
    board.makeMove(move);
    board.printSelf(move);
    const score = board.score();
    print("\nscore = {d} winner = {any}\n", .{ score.score, score.winner });
    var buf: [Game.max_moves]Game.Move = undefined;
    const moves = board.possibleMoves(&buf);
    print("\npossible moves {d}", .{moves.len});
    for (moves) |m| {
        board.makeMove(m, .second);
    }
    board.printSelf(move);
}

test "bench1" {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var rng = Prng.init(1);
    var start = try std.time.Timer.start();
    var result: i32 = 0;
    var game = Game{};
    for (0..10_000) |_| {
        for (0..100) |_| {
            game.board[9][9] = if (rng.next() % 2 == 0) .black else .white;
            result += game.scoreBoard().score;
        }
    }
    const nanos = start.read();
    print("\n{d} result {d}\n", .{ nanos, result });
}

test "bench2" {
    const Player = enum { second, none, first };
    const Game = C6(Player, 19, 300);
    var rng = Prng.init(1);
    var start = try std.time.Timer.start();
    var result: i32 = 0;
    var game = Game{};
    for (0..10_000) |_| {
        for (0..100) |_| {
            const r = game.ratePlace(Game.Place.init(9, 9), if (rng.next() % 2 == 0) .black else .white);
            result += r.score;
        }
    }
    const nanos = start.read();
    print("\n{d} result {d}\n", .{ nanos, result });
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
        const r = game.ratePlace(Game.Place.init(x, y), stone);
        game.board[y][x] = stone;
        score += r.score;
        const score2 = game.scoreBoard();
        try std.testing.expectEqual(score2.score, score);
    }
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
    const Game = C6(Player, 19, 300);
    var game = Game{};

    var rng = Prng.init(1);
    const x: usize = @intCast(rng.next() % 19);
    const y: usize = @intCast(rng.next() % 19);
    var buf: [Game.maxMoves()]Game.Move = undefined;
    const rate = game.ratePlace(Game.Place.init(x, y), .black);
    print("\nrate {d}", .{rate.score});
    game.board[y][x] = .black;
    game.n_moves += 1;
    game.printBoard(undefined);
    for (game.possibleMoves(&buf), 1..) |move, i| {
        print("\n {d}: ", .{i});
        move.print();
    }
}
