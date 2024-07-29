const std = @import("std");
const print = std.debug.print;
const Prng = std.rand.Random.DefaultPrng;
const Allocator = std.mem.Allocator;

pub fn TicTacToe(comptime Player: type) type {
    return struct {
        board: [3][3]Player,
        moves_played: u8,

        const Self = @This();

        pub const max_moves: usize = 9;

        pub const Move = struct {
            player: Player,
            next_player: Player,
            x: u8,
            y: u8,

            pub inline fn eql(self: @This(), other: @This()) bool {
                return self.player == other.player and self.x == other.x and self.y == other.y;
            }

            pub fn print(self: @This()) void {
                std.debug.print("[", .{});
                self.player.print();
                std.debug.print(":{d}:{d}]", .{ self.x, self.y });
            }
        };

        pub fn init() Self {
            return .{
                .board = [1][3]Player{[1]Player{.none} ** 3} ** 3,
                .moves_played = 0,
            };
        }

        pub fn makeMove(self: *Self, move: Move) ?Player {
            self.moves_played += 1;
            self.board[move.y][move.x] = move.player;
            return self.outcome(move);
        }

        fn outcome(self: Self, move: Move) ?Player {
            const x = move.x;
            const y = move.y;
            const turn = move.player;
            if ((self.board[0][x] == turn and self.board[1][x] == turn and self.board[2][x] == turn) or
                (self.board[y][0] == turn and self.board[y][1] == turn and self.board[y][2] == turn) or
                (self.board[0][0] == turn and self.board[1][1] == turn and self.board[2][2] == turn) or
                (self.board[0][2] == turn and self.board[1][1] == turn and self.board[2][0] == turn)) return turn;

            if (self.moves_played == 9) return .none;
            return null;
        }

        pub fn possibleMoves(self: Self, buf: []Move) []Move {
            const player = self.nextPlayer();
            const next_player = self.previousPlayer();
            var idx: usize = 0;
            for (self.board, 0..) |row, y| {
                for (row, 0..) |place, x| {
                    if (place == .none) {
                        buf[idx] = Move{
                            .player = player,
                            .next_player = next_player,
                            .x = @intCast(x),
                            .y = @intCast(y),
                        };
                        idx += 1;
                    }
                }
            }
            return buf[0..idx];
        }

        pub fn rollout(self: *Self) Player {
            while (true) {
                if (self.makeMove(self.randomMove())) |winner| {
                    return winner;
                }
            }
        }

        inline fn nextPlayer(self: Self) Player {
            return if (self.moves_played % 2 == 0) .first else .second;
        }

        inline fn previousPlayer(self: Self) Player {
            return if (self.moves_played % 2 == 1) .first else .second;
        }

        fn randomMove(self: Self) Move {
            var rand = Prng.init(@intCast(std.time.milliTimestamp()));
            const player = self.nextPlayer();
            const next_player = self.previousPlayer();
            var move = Move{ .player = player, .next_player = next_player, .x = 0, .y = 0 };

            var prob: u64 = 1;
            for (self.board, 0..) |row, y| {
                for (row, 0..) |place, x| {
                    if (place == .none) {
                        const random = rand.next();
                        if (random % prob == 0) {
                            move = Move{
                                .player = player,
                                .next_player = next_player,
                                .x = @intCast(x),
                                .y = @intCast(y),
                            };
                        }
                        prob += 1;
                    }
                }
            }
            return move;
        }

        pub fn printBoard(self: Self, move: Move) void {
            for (0..3) |y| {
                print("\n", .{});
                for (0..3) |x| {
                    switch (self.board[y][x]) {
                        .second => if (move.x == x and move.y == y) print(" @", .{}) else print(" O", .{}),
                        .none => print(" .", .{}),
                        .first => if (move.x == x and move.y == y) print(" #", .{}) else print(" X", .{}),
                    }
                }
            }
            print("\n------", .{});
        }
    };
}

pub const P = enum(u8) {
    second,
    none,
    first,

    pub fn print(player: P) void {
        const str = switch (player) {
            .first => "first",
            .second => "second",
            .none => "none",
        };
        std.debug.print("{s}", .{str});
    }
};

test {
    var game = TicTacToe(P).init();
    const moves = [_]TicTacToe(P).Move{
        .{ .player = .first, .next_player = .second, .x = 1, .y = 1 },
        .{ .player = .second, .next_player = .first, .x = 0, .y = 0 },
        .{ .player = .first, .next_player = .second, .x = 0, .y = 2 },
        .{ .player = .second, .next_player = .first, .x = 2, .y = 0 },
        .{ .player = .first, .next_player = .second, .x = 1, .y = 0 },
        .{ .player = .second, .next_player = .first, .x = 1, .y = 2 },
        .{ .player = .first, .next_player = .second, .x = 0, .y = 1 },
        .{ .player = .second, .next_player = .first, .x = 2, .y = 1 },
        .{ .player = .first, .next_player = .second, .x = 2, .y = 2 },
    };

    for (moves, 1..) |move, i| {
        const result = game.makeMove(move);
        print("\nmove {d}:\n------\n", .{i});
        game.printBoard(move);
        if (result) |r| {
            print("\n", .{});
            r.print();
            try std.testing.expect(i == 9);
            try std.testing.expect(result == .none);
            break;
        }
    }
    print("\n", .{});
}
