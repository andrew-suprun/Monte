const std = @import("std");
const SearchTree = @import("SearchTree.zig");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var tree = SearchTree.init(allocator, 1_000_000);
    defer tree.deinit();

    try tree.expand();

    print("Done {any}\n", .{tree.size});
}
