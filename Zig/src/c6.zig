const std = @import("std");
const Allocator = std.mem.Allocator;

const C6 = @import("Connect6.zig");
const SearchTree = @import("tree.zig").SearchTree(C6);
const Engine = @import("engine.zig").Engine(SearchTree, C6);

pub fn main() !void {
    try std.io.getStdOut().writer().print("server started\n", .{});
    defer std.io.getStdOut().writer().print("server ended\n", .{}) catch unreachable;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var engine = try Engine.init(allocator);
    defer engine.deinit();

    try engine.run();
}
