const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const tree = @import("tree.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var search_tree = tree.SearchTree(@import("TicTacToe.zig")).init();
    defer search_tree.deinit(allocator);

    try search_tree.expand(allocator);
}
