const std = @import("std");
const Array = std.ArrayListUnmanaged(i64);
const print = std.debug.print;

const X = struct {
    a: f32,
    m: [4]u8,
    b: bool,
};

pub fn main() void {
    print("{any}\n", .{@sizeOf(X)});
}
