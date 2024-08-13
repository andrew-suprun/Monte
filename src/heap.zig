const std = @import("std");
const print = std.debug.print;

pub fn Heap(comptime T: type, comptime Context: type, comptime less: fn (context: Context, a: T, b: T) bool, capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        len: usize = 0,
        context: Context,

        pub fn init(context: Context) Self {
            return Self{ .context = context };
        }

        pub fn add(self: *Self, elem: T) void {
            if (self.len == capacity) {
                if (less(self.context, elem, self.items[0])) return;
                self.items[0] = elem;
                self.sift_down();
                return;
            }
            self.items[self.len] = elem;
            self.len += 1;
            self.sift_up();
        }

        pub fn remove(self: *Self) T {
            const result = self.items[0];
            self.len -= 1;
            self.items[0] = self.items[self.len];
            self.sift_down();
            return result;
        }

        pub fn unsorted(self: *Self, buf: []T) []T {
            std.mem.copyForwards(T, buf, self.items[0..self.len]);
            return buf[0..self.len];
        }

        pub fn sorted(self: *Self, buf: []T) []T {
            const len = self.len;
            for (0..len) |i| {
                buf[len - 1 - i] = self.remove();
            }
            return buf[0..len];
        }

        fn sift_up(self: *Self) void {
            var child_idx = self.len - 1;
            const child = self.items[child_idx];

            while (child_idx > 0 and less(self.context, child, self.items[(child_idx - 1) / 2])) {
                const parent_idx = (child_idx - 1) / 2;
                self.items[child_idx] = self.items[parent_idx];
                child_idx = parent_idx;
            }

            self.items[child_idx] = child;
            return;
        }

        fn sift_down(self: *Self) void {
            var parent_idx: usize = 0;
            const top_element = self.items[0];
            while (true) {
                var first = parent_idx;
                const left_child_idx = parent_idx * 2 + 1;
                if (left_child_idx < self.len and less(self.context, self.items[left_child_idx], top_element)) {
                    first = left_child_idx;
                }

                const right_child_idx = parent_idx * 2 + 2;
                if (right_child_idx < self.len and
                    less(self.context, self.items[right_child_idx], top_element) and
                    less(self.context, self.items[right_child_idx], self.items[left_child_idx]))
                {
                    first = right_child_idx;
                }

                if (parent_idx == first) break;

                self.items[parent_idx] = self.items[first];
                parent_idx = first;
            }
            self.items[parent_idx] = top_element;

            return;
        }
    };
}

fn cmp(ctxt: usize, a: usize, b: usize) bool {
    _ = ctxt;
    return a < b;
}

const Prng = std.rand.Random.DefaultPrng;
const assert = std.debug.assert;

test {
    var prng = Prng.init(@intCast(std.time.microTimestamp()));
    var heap = Heap(usize, usize, cmp, 20).init(42);
    for (0..100) |_| {
        heap.add(prng.next() % 100);
    }
    assert(heap.len == 20);
    var buf: [20]usize = undefined;
    const sorted = heap.sorted(&buf);
    for (1..sorted.len) |i| {
        assert(sorted[i - 1] >= sorted[i]);
    }
}

test "heap" {
    var prng = Prng.init(@intCast(std.time.microTimestamp()));
    var timer = try std.time.Timer.start();
    for (0..1_000_000) |_| {
        var heap = Heap(usize, usize, cmp, 100).init(42);
        for (0..1000) |_| {
            heap.add(prng.next() % 1000);
        }
        var buf: [100]usize = undefined;
        const sorted = heap.unsorted(&buf);
        assert(sorted.len == 100);
    }
    print("\ntime {d}ms\n", .{timer.read() / 1_000_000});
}
