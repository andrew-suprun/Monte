const std = @import("std");
const Allocator = std.mem.Allocator;
const math = std.math;
const expect = std.testing.expect;
const print = std.debug.print;

pub fn main() !void {
    std.log.debug("DEBUG", .{});
    const c6 = std.log.scoped(.c6);
    c6.debug("C6", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    _ = allocator;

    print("{any}\n", .{row_count});
    _ = config.row_config.len;
}

const Coord = struct { x: u8, y: u8 };
const Move = [2]Coord;

const Node = struct {};

const BoardSize = 19;

const Idx = isize;

const RolloutResult = union(enum) {
    final: Player,
    nonterminal: Player,
};

const Board = struct {
    places: [BoardSize][BoardSize]Player = [1][BoardSize]Player{[1]Player{.none} ** BoardSize} ** BoardSize,

    fn init() Board {
        var board = Board{};
        board.places[BoardSize / 2][BoardSize / 2] = .second;
        return board;
    }

    fn get(self: Board, x: Idx, y: Idx) Player {
        // std.debug.print("    get[{}][{}] -> {}\n", .{ x, y, self.places[@intCast(x)][@intCast(y)] });
        return self.places[@intCast(x)][@intCast(y)];
    }

    fn print(self: Board) void {
        for (0..BoardSize) |j| {
            for (0..BoardSize) |i| {
                switch (self.places[i][j]) {
                    .none => std.debug.print(". ", .{}),
                    .first => std.debug.print("O ", .{}),
                    .second => std.debug.print("X ", .{}),
                }
            }
            std.debug.print("\n", .{});
        }
    }
};

const Player = enum(u8) { first = 0x01, second = 0x10, none = 0x00 };

const Score = i64;

const Scores = struct {
    places: [BoardSize][BoardSize]Score = [1][BoardSize]Score{[1]Score{0} ** BoardSize} ** BoardSize,

    inline fn get(self: Scores, x: Idx, y: Idx) Score {
        return self.places[@intCast(x)][@intCast(y)];
    }

    inline fn inc(self: *Scores, x: Idx, y: Idx, value: Score) void {
        self.places[@intCast(x)][@intCast(y)] += value;
    }

    fn print(self: Scores) void {
        for (0..BoardSize) |j| {
            for (0..BoardSize) |i| {
                std.debug.print("{:3} ", .{self.places[i][j]});
            }
            std.debug.print("\n", .{});
        }
    }
};

// pub fn rollout(allocator: Allocator, moves: []const Move, move: Move) std.AutoHashMap(Move, Node) {
pub fn expand(moves: []const Move, nodes: std.AutoHashMap(Move, Node)) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var board = Board.init();
    var player: Player = .first;
    var places_to_consider = std.AutoHashMap(Coord, void).init(allocator);
    try add_places_to_consider(Coord{ .x = BoardSize / 2, .y = BoardSize / 2 }, &places_to_consider);

    for (moves) |m| {
        board.places[m[0].x][m[0].y] = player;
        board.places[m[1].x][m[1].y] = player;

        try add_places_to_consider(m[0], &places_to_consider);
        try add_places_to_consider(m[1], &places_to_consider);

        player = if (player == .first) .second else .first;
    }

    for (moves) |m| {
        _ = places_to_consider.remove(m[0]);
        _ = places_to_consider.remove(m[1]);
    }
    _ = places_to_consider.remove(.{ .x = BoardSize / 2, .y = BoardSize / 2 });

    var places = try std.ArrayList(Coord).initCapacity(allocator, places_to_consider.count());
    var iter = places_to_consider.keyIterator();
    while (iter.next()) |place| {
        print("place: {}\n", .{place.*});
        try places.append(place.*);
    }
    print("places = {any}\n\n\n", .{places.items});

    const scores = score_board(&board);

    var j: Score = 1;
    for (places.items[0 .. places.items.len - 1], 1..) |one, i| {
        for (places.items[i..]) |two| {
            print("expand {} {}:{} - {}:{}\n", .{ j, one.x, one.y, two.x, two.y });
            j += 1;
            _ = rollout(board, scores, player, one, two);
        }
        print("\n", .{});
    }

    _ = .{ nodes, allocator };
}

fn rollout(b: Board, s: Scores, player: Player, one: Coord, two: Coord) RolloutResult {
    var board = b;
    var scores = s;

    if (make_move(&board, &scores, player, one)) return .{ .final = player };
    if (make_move(&board, &scores, player, two)) return .{ .final = player };

    return .{ .nonterminal = .none };
}

inline fn make_move(board: *Board, scores: *Scores, player: Player, place: Coord) bool {
    inline for (config.row_idces[place.x][place.y]) |idx| {
        _ = score_row(board, scores, config.row_config[idx], true);
        board.places[place.x][place.y] = player;
        if (score_row(board, scores, config.row_config[idx], false)) return true;
    }
    return false;
}

fn add_places_to_consider(place: Coord, places: *std.AutoHashMap(Coord, void)) !void {
    if (place.y > 0) {
        try places.put(Coord{ .x = place.x, .y = place.y - 1 }, {});
        if (place.x > 0) {
            try places.put(Coord{ .x = place.x - 1, .y = place.y - 1 }, {});
        }
        if (place.x < BoardSize) {
            try places.put(Coord{ .x = place.x + 1, .y = place.y - 1 }, {});
        }
    }
    if (place.y > 1) {
        try places.put(Coord{ .x = place.x, .y = place.y - 2 }, {});
        if (place.x > 1) {
            try places.put(Coord{ .x = place.x - 2, .y = place.y - 2 }, {});
        }
        if (place.x < BoardSize - 1) {
            try places.put(Coord{ .x = place.x + 2, .y = place.y - 2 }, {});
        }
    }
    if (place.x > 0) {
        try places.put(Coord{ .x = place.x - 1, .y = place.y }, {});
    }
    if (place.x < BoardSize) {
        try places.put(Coord{ .x = place.x + 1, .y = place.y }, {});
    }
    if (place.x > 1) {
        try places.put(Coord{ .x = place.x - 2, .y = place.y }, {});
    }
    if (place.x < BoardSize) {
        try places.put(Coord{ .x = place.x + 2, .y = place.y }, {});
    }
    if (place.y < BoardSize) {
        try places.put(Coord{ .x = place.x, .y = place.y + 1 }, {});
        if (place.x > 0) {
            try places.put(Coord{ .x = place.x - 1, .y = place.y + 1 }, {});
        }
        if (place.x < BoardSize) {
            try places.put(Coord{ .x = place.x + 1, .y = place.y + 1 }, {});
        }
    }
    if (place.y < BoardSize - 1) {
        try places.put(Coord{ .x = place.x, .y = place.y + 2 }, {});
        if (place.x > 0) {
            try places.put(Coord{ .x = place.x - 2, .y = place.y + 2 }, {});
        }
        if (place.x < BoardSize) {
            try places.put(Coord{ .x = place.x + 2, .y = place.y + 2 }, {});
        }
    }
}

fn score_board(board: *Board) Scores {
    var scores = Scores{};
    for (config.row_config) |row_config| {
        _ = score_row(board, &scores, row_config, false);
    }
    return scores;
}

const values = [_]Score{ 1, 4, 16, 64, 256, 1024, 32768 };

fn score_row(board: *Board, scores: *Scores, row_config: RowConfig, comptime clear: bool) bool {
    if (row_config.count == 0) return false;

    var x = row_config.x;
    var y = row_config.y;
    const dx: Idx = row_config.dx;
    const dy: Idx = row_config.dy;

    var sum: usize = @intFromEnum(board.get(x, y)) +
        @intFromEnum(board.get(x + dx, y + dy)) +
        @intFromEnum(board.get(x + 2 * dx, y + 2 * dy)) +
        @intFromEnum(board.get(x + 3 * dx, y + 3 * dy)) +
        @intFromEnum(board.get(x + 4 * dx, y + 4 * dy)) +
        @intFromEnum(board.get(x + 5 * dx, y + 5 * dy));

    var i: u8 = 0;
    while (true) {
        const v: Score = if (sum & 0x70 == 0) values[sum] else if (sum & 0x07 == 0) values[sum >> 4] else 0;
        if (v >= 32768) return true;
        const value = if (clear) -v else v;

        scores.inc(x, y, value);
        scores.inc(x + dx, y + dy, value);
        scores.inc(x + 2 * dx, y + 2 * dy, value);
        scores.inc(x + 3 * dx, y + 3 * dy, value);
        scores.inc(x + 4 * dx, y + 4 * dy, value);
        scores.inc(x + 5 * dx, y + 5 * dy, value);
        i += 1;
        if (i == row_config.count) {
            break;
        }
        sum -= @intFromEnum(board.get(x, y));
        x += dx;
        y += dy;
        sum += @intFromEnum(board.get(x + 5 * dx, y + 5 * dy));
    }
    return false;
}

test Board {
    var moves = std.ArrayList(Move).init(std.testing.allocator);
    // try moves.append([2]Coord{ .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } });
    // try moves.append([2]Coord{ .{ .x = 10, .y = 9 }, .{ .x = 9, .y = 10 } });
    // try moves.append([2]Coord{ .{ .x = 8, .y = 9 }, .{ .x = 9, .y = 8 } });
    defer moves.deinit();

    const nodes = std.AutoHashMap(Move, Node).init(std.testing.allocator);
    _ = try expand(moves.items, nodes);

    var board = Board.init();

    var timer = try std.time.Timer.start();
    var scores: Scores = undefined;
    for (0..100000) |_| {
        scores = score_board(&board);
    }
    const elapsed_ns = timer.read();
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / std.time.ns_per_s;
    print("time {d}/sec\n", .{@as(i64, @intFromFloat(100000 / elapsed_s))});
}

const config = GameConfig.init();
const row_count: Score = 6 * BoardSize - 21;
const RowConfig = struct { x: Idx, y: Idx, dx: Idx, dy: Idx, count: Idx };
const RowIndices = [BoardSize][BoardSize][4]usize;
const GameConfig = struct {
    row_config: [row_count]RowConfig,
    row_idces: RowIndices,

    fn init() GameConfig {
        @setEvalBranchQuota(2000);
        var row_config = [_]RowConfig{.{ .x = 0, .y = 0, .dx = 0, .dy = 0, .count = 0 }} ** row_count;
        var row_indices = [_][BoardSize][4]usize{[_][4]usize{[_]usize{ 0, 0, 0, 0 }} ** BoardSize} ** BoardSize;

        var row_idx: Score = 1;
        for (0..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 0, .count = BoardSize - 5 };

            for (0..BoardSize) |j| {
                row_indices[j][i][0] = row_idx;
            }

            row_idx += 1;
        }

        for (0..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = @intCast(i), .y = 0, .dx = 0, .dy = 1, .count = BoardSize - 5 };

            for (0..BoardSize) |j| {
                row_indices[i][j][1] = row_idx;
            }

            row_idx += 1;
        }

        for (5..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = -1, .count = @intCast(i - 4) };

            for (0..i + 1) |j| {
                row_indices[j][i - j][2] = row_idx;
            }

            row_idx += 1;
        }

        for (1..BoardSize - 5) |i| {
            row_config[row_idx] = RowConfig{ .x = @intCast(i), .y = BoardSize - 1, .dx = 1, .dy = -1, .count = @intCast(BoardSize - 5 - i) };

            for (i..BoardSize) |j| {
                row_indices[j][BoardSize - 1 + i - j][2] = row_idx;
            }

            row_idx += 1;
        }

        for (5..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = @intCast(BoardSize - 1 - i), .y = 0, .dx = 1, .dy = 1, .count = @intCast(i - 4) };

            for (0..i + 1) |j| {
                row_indices[BoardSize - 1 - i + j][j][3] = row_idx;
            }

            row_idx += 1;
        }

        for (1..BoardSize - 5) |i| {
            row_config[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 1, .count = @intCast(BoardSize - 5 - i) };

            for (0..BoardSize - i) |j| {
                row_indices[j][i + j][3] = row_idx;
            }

            row_idx += 1;
        }

        return GameConfig{ .row_config = row_config, .row_idces = row_indices };
    }
};

// pub const std_options = std.Options{
//     .log_level = .debug,
//     .log_scope_levels = ([_]std.log.ScopeLevel{
//         .{ .scope = .c6, .level = .debug },
//     })[0..],
// };
