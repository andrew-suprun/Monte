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

const Board = struct {
    places: [BoardSize][BoardSize]Player = [1][BoardSize]Player{[1]Player{.none} ** BoardSize} ** BoardSize,

    fn init() Board {
        var board = Board{};
        board.places[BoardSize / 2][BoardSize / 2] = .second;
        return board;
    }

    fn get(self: Board, x: i8, y: i8) Player {
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

const Scores = struct {
    places: [BoardSize][BoardSize]i32 = [1][BoardSize]i32{[1]i32{0} ** BoardSize} ** BoardSize,

    fn get(self: Scores, x: i8, y: i8) i32 {
        return self.places[@intCast(x)][@intCast(y)];
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

    var j: i32 = 1;
    for (places.items[0 .. places.items.len - 1], 1..) |one, i| {
        for (places.items[i..]) |two| {
            print("expand {} {}:{} - {}:{}\n", .{ j, one.x, one.y, two.x, two.y });
            j += 1;
        }
        print("\n", .{});
    }

    _ = .{ nodes, allocator };
}

fn add_places_to_consider(place: Coord, places: *std.AutoHashMap(Coord, void)) !void {
    print("place: {}:{}\n", .{ place.x, place.y });
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

fn score_place(board: Board, scores: *Scores, place: Coord) void {
    for (config.row_idces[place.x][place.y]) |idx| {
        score_row(board, scores, config.row_config[idx]);
    }
}

fn score_row(board: Board, scores: *Scores, row_config: RowConfig) void {
    print("{}:{} {}:{} {}: ", .{ row_config.x, row_config.y, row_config.dx, row_config.dy, row_config.count });
    if (row_config.count == 0) return;

    var sum = @intFromEnum(board.get(row_config.x, row_config.y)) +
        @intFromEnum(board.get(row_config.x, row_config.y)) +
        @intFromEnum(board.get(row_config.x + 2 * row_config.dx, row_config.y + 2 * row_config.dy)) +
        @intFromEnum(board.get(row_config.x + 3 * row_config.dx, row_config.y + 3 * row_config.dy)) +
        @intFromEnum(board.get(row_config.x + 4 * row_config.dx, row_config.y + 4 * row_config.dy)) +
        @intFromEnum(board.get(row_config.x + 5 * row_config.dx, row_config.y + 5 * row_config.dy));

    print("sum = {}\n", .{sum});
    sum += 1;
    _ = scores;

    // TODO: Finish
}

test Board {
    var moves = std.ArrayList(Move).init(std.testing.allocator);
    // try moves.append([2]Coord{ .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } });
    // try moves.append([2]Coord{ .{ .x = 10, .y = 9 }, .{ .x = 9, .y = 10 } });
    // try moves.append([2]Coord{ .{ .x = 8, .y = 9 }, .{ .x = 9, .y = 8 } });
    defer moves.deinit();

    const nodes = std.AutoHashMap(Move, Node).init(std.testing.allocator);
    _ = try expand(moves.items, nodes);

    for (config.row_config, 0..) |c, i| {
        print("{}: start: {}:{} delta: {}:{} count: {}\n", .{ i, c.x, c.y, c.dx, c.dy, c.count });
    }

    print("\n\n", .{});

    for (0..BoardSize) |i| {
        for (0..BoardSize) |j| {
            const r = config.row_idces[i][j];
            print("{}:{} - {} {} {} {}\n", .{ i, j, r[0], r[1], r[2], r[3] });
        }
    }

    const board = Board.init();
    var scores = Scores{};

    score_place(board, &scores, Coord{ .x = 7, .y = 7 });
    board.print();
}

const config = GameConfig.init();
const row_count: i32 = 6 * BoardSize - 21;
const RowConfig = struct { x: i8, y: i8, dx: i8, dy: i8, count: i8 };
const RowIndices = [BoardSize][BoardSize][4]u32;
const GameConfig = struct {
    row_config: [row_count]RowConfig,
    row_idces: RowIndices,

    fn init() GameConfig {
        @setEvalBranchQuota(2000);
        var row_config = [_]RowConfig{.{ .x = 0, .y = 0, .dx = 0, .dy = 0, .count = 0 }} ** row_count;
        var row_indices = [_][BoardSize][4]u32{[_][4]u32{[_]u32{ 0, 0, 0, 0 }} ** BoardSize} ** BoardSize;

        var row_idx: u32 = 1;
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
