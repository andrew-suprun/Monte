const std = @import("std");
const Allocator = std.mem.Allocator;

const Engine = @import("Engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut().writer();

    var engine = Engine.init(allocator, in, out);
    defer engine.deinit();

    try engine.run();
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
