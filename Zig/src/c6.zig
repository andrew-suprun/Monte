const std = @import("std");
const Allocator = std.mem.Allocator;

const Game = @import("Connect6.zig");
const SearchTree = @import("tree.zig").SearchTree(Game);
const Engine = @import("engine.zig").Engine(SearchTree, Game);

pub fn main() !void {
    std.debug.print("server started\n", .{});
    defer std.debug.print("server ended\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = try Engine.init(allocator);
    defer engine.deinit();

    try engine.run();
}
