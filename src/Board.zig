const Board = @This();
const std = @import("std");
const config = @import("config.zig");
const BoardSize = config.BoardSize;
const Place = config.Place;
const Player = config.Player;

places: [BoardSize][BoardSize]Player = [1][BoardSize]Player{[1]Player{.none} ** BoardSize} ** BoardSize,

pub fn set_place(board: Board, place: Place, player: Player) void {
    board.places[place.x][place.y] = player;
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
