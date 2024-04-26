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
}

const Coord = struct { x: u8, y: u8 };
const Move = [2]Coord;

const Node = struct {};

const BoardSize = 19;

const place_first = 0x01;
const place_second = 0x10;

const Board = struct {
    places: [BoardSize][BoardSize]u8 = [1][BoardSize]u8{[1]u8{0} ** BoardSize} ** BoardSize,

    fn init() Board {
        var board = Board{};
        board.places[BoardSize / 2][BoardSize / 2] = place_second;
        return board;
    }
};

const Player = enum { first, second, none };

// pub fn rollout(allocator: Allocator, moves: []const Move, move: Move) std.AutoHashMap(Move, Node) {
pub fn expand(moves: []const Move, nodes: std.AutoHashMap(Move, Node)) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var board = Board.init();
    var player: u8 = place_first;
    var places_to_consider = std.AutoHashMap(Coord, void).init(allocator);
    try add_places_to_consider(Coord{ .x = BoardSize / 2, .y = BoardSize / 2 }, &places_to_consider);

    for (moves) |m| {
        board.places[m[0].y][m[0].x] = player;
        board.places[m[1].y][m[1].x] = player;

        try add_places_to_consider(m[0], &places_to_consider);
        try add_places_to_consider(m[1], &places_to_consider);

        player = place_first + place_second - player;
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

test Board {
    var moves = std.ArrayList(Move).init(std.testing.allocator);
    // try moves.append([2]Coord{ .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } });
    // try moves.append([2]Coord{ .{ .x = 10, .y = 9 }, .{ .x = 9, .y = 10 } });
    // try moves.append([2]Coord{ .{ .x = 8, .y = 9 }, .{ .x = 9, .y = 8 } });
    defer moves.deinit();

    const nodes = std.AutoHashMap(Move, Node).init(std.testing.allocator);
    _ = try expand(moves.items, nodes);

    _ = Config.init();
}

const row_count: i32 = 6 * BoardSize - 22;
const RowConfig = struct { x: i8, y: i8, dx: i8, dy: i8, count: i8 };
const RowIndices = [BoardSize][BoardSize][4]u32;
const Config = struct {
    row_config: [row_count]RowConfig,
    row_idces: RowIndices,

    fn init() Config {
        var row_config = [_]RowConfig{.{ .x = 0, .y = 0, .dx = 0, .dy = 0, .count = 0 }} ** row_count;
        const row_indices = [_][BoardSize][4]u32{[_][4]u32{[_]u32{ 0, 0, 0, 0 }} ** BoardSize} ** BoardSize;

        print("1:\n", .{});
        var row_idx: u32 = 0;
        for (0..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 0, .count = BoardSize - 5 };
            const c = row_config[row_idx];
            print("{}: start {}:{}  delta {}:{}  count {}\n", .{ row_idx, c.x, c.y, c.dx, c.dy, c.count });
            row_idx += 1;
        }

        print("2:\n", .{});
        for (0..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = @intCast(i), .y = 0, .dx = 0, .dy = 1, .count = BoardSize - 5 };
            const c = row_config[row_idx];
            print("{}: start {}:{}  delta {}:{}  count {}\n", .{ row_idx, c.x, c.y, c.dx, c.dy, c.count });
            row_idx += 1;
        }

        print("3\n", .{});
        for (5..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = -1, .count = @intCast(i - 4) };
            const c = row_config[row_idx];
            print("{}: start {}:{}  delta {}:{}  count {}\n", .{ row_idx, c.x, c.y, c.dx, c.dy, c.count });
            row_idx += 1;
        }

        print("4\n", .{});
        for (1..BoardSize - 5) |i| {
            row_config[row_idx] = RowConfig{ .x = @intCast(i), .y = BoardSize - 1, .dx = 1, .dy = -1, .count = @intCast(BoardSize - 5 - i) };
            const c = row_config[row_idx];
            print("{}: start {}:{}  delta {}:{}  count {}\n", .{ row_idx, c.x, c.y, c.dx, c.dy, c.count });
            row_idx += 1;
        }

        print("5\n", .{});
        for (5..BoardSize) |i| {
            row_config[row_idx] = RowConfig{ .x = @intCast(BoardSize - 1 - i), .y = 0, .dx = 1, .dy = 1, .count = @intCast(i - 4) };
            const c = row_config[row_idx];
            print("{}: start {}:{}  delta {}:{}  count {}\n", .{ row_idx, c.x, c.y, c.dx, c.dy, c.count });
            row_idx += 1;
        }

        print("6\n", .{});
        for (1..BoardSize - 5) |i| {
            row_config[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 1, .count = @intCast(BoardSize - 5 - i) };
            const c = row_config[row_idx];
            print("{}: start {}:{}  delta {}:{}  count {}\n", .{ row_idx, c.x, c.y, c.dx, c.dy, c.count });
            row_idx += 1;
        }
        print("\n", .{});

        return Config{ .row_config = row_config, .row_idces = row_indices };
    }
};
const config = Config.init();

// pub const std_options = std.Options{
//     .log_level = .debug,
//     .log_scope_levels = ([_]std.log.ScopeLevel{
//         .{ .scope = .c6, .level = .debug },
//     })[0..],
// };
