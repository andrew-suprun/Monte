places: [BoardSize][BoardSize]Player = [1][BoardSize]Player{[1]Player{.none} ** BoardSize} ** BoardSize,

const std = @import("std");
const print = std.debug.print;

const Board = @This();
pub const BoardSize = 19;
pub const Place = struct { x: isize, y: isize };
pub const Player = enum(u8) { first = 0x01, second = 0x10, none = 0x00 };
pub const RowConfig = struct { x: isize, y: isize, dx: isize, dy: isize, count: isize };

pub inline fn set_place(board: *Board, place: Place, player: Player) void {
    board.places[@intCast(place.x)][@intCast(place.y)] = player;
}

pub const empty_board = blk: {
    var board = Board{};
    board.places[BoardSize / 2][BoardSize / 2] = .second;

    break :blk board;
};

pub fn clone(self: Board) Board {
    return Board{
        .places = self.places,
    };
}

pub inline fn get(self: Board, place: Place) Player {
    return self.places[@intCast(place.x)][@intCast(place.y)];
}

pub inline fn set(self: Board, place: Place, player: Player) void {
    self.places[@intCast(place.x)][@intCast(place.y)] = player;
}

fn add_places_to_consider(place: Place, places: *std.AutoHashMap(Place, void)) !void {
    if (place.y > 0) {
        try places.put(Place{ .x = place.x, .y = place.y - 1 }, {});
        if (place.x > 0) {
            try places.put(Place{ .x = place.x - 1, .y = place.y - 1 }, {});
        }
        if (place.x < BoardSize) {
            try places.put(Place{ .x = place.x + 1, .y = place.y - 1 }, {});
        }
    }
    if (place.y > 1) {
        try places.put(Place{ .x = place.x, .y = place.y - 2 }, {});
        if (place.x > 1) {
            try places.put(Place{ .x = place.x - 2, .y = place.y - 2 }, {});
        }
        if (place.x < BoardSize - 1) {
            try places.put(Place{ .x = place.x + 2, .y = place.y - 2 }, {});
        }
    }
    if (place.x > 0) {
        try places.put(Place{ .x = place.x - 1, .y = place.y }, {});
    }
    if (place.x < BoardSize) {
        try places.put(Place{ .x = place.x + 1, .y = place.y }, {});
    }
    if (place.x > 1) {
        try places.put(Place{ .x = place.x - 2, .y = place.y }, {});
    }
    if (place.x < BoardSize) {
        try places.put(Place{ .x = place.x + 2, .y = place.y }, {});
    }
    if (place.y < BoardSize) {
        try places.put(Place{ .x = place.x, .y = place.y + 1 }, {});
        if (place.x > 0) {
            try places.put(Place{ .x = place.x - 1, .y = place.y + 1 }, {});
        }
        if (place.x < BoardSize) {
            try places.put(Place{ .x = place.x + 1, .y = place.y + 1 }, {});
        }
    }
    if (place.y < BoardSize - 1) {
        try places.put(Place{ .x = place.x, .y = place.y + 2 }, {});
        if (place.x > 0) {
            try places.put(Place{ .x = place.x - 2, .y = place.y + 2 }, {});
        }
        if (place.x < BoardSize) {
            try places.put(Place{ .x = place.x + 2, .y = place.y + 2 }, {});
        }
    }
}

pub fn print_board(self: Board) void {
    for (0..BoardSize) |j| {
        for (0..BoardSize) |i| {
            switch (self.places[i][j]) {
                .none => print(". ", .{}),
                .first => print("O ", .{}),
                .second => print("X ", .{}),
            }
        }
        print("\n", .{});
    }
}

const row_count: usize = 6 * BoardSize - 21;

pub fn row_config(idx: isize) RowConfig {
    return row_config_data[@intCast(idx)];
}

pub const row_config_data = blk: {
    var row_cfg = [_]RowConfig{.{ .x = 0, .y = 0, .dx = 0, .dy = 0, .count = 0 }} ** row_count;

    var row_idx: usize = 1;
    for (0..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 0, .count = BoardSize - 5 };
        row_idx += 1;
    }

    for (0..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = @intCast(i), .y = 0, .dx = 0, .dy = 1, .count = BoardSize - 5 };
        row_idx += 1;
    }

    for (5..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = -1, .count = @intCast(i - 4) };
        row_idx += 1;
    }

    for (1..BoardSize - 5) |i| {
        row_cfg[row_idx] = RowConfig{ .x = @intCast(i), .y = BoardSize - 1, .dx = 1, .dy = -1, .count = @intCast(BoardSize - 5 - i) };
        row_idx += 1;
    }

    for (5..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = @intCast(BoardSize - 1 - i), .y = 0, .dx = 1, .dy = 1, .count = @intCast(i - 4) };
        row_idx += 1;
    }

    for (1..BoardSize - 5) |i| {
        row_cfg[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 1, .count = @intCast(BoardSize - 5 - i) };
        row_idx += 1;
    }

    break :blk row_cfg;
};
