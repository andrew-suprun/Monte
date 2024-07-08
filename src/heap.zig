const std = @import("std");
const print = std.debug.print;
const Order = std.math.Order;

pub fn Heap(comptime T: type, comptime Context: type, comptime compareFn: fn (context: Context, a: T, b: T) Order, capacity: usize) type {
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
                if (compareFn(self.context, elem, self.items[0]) == .lt) return;
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

        fn sift_up(self: *Self) void {
            var child_idx = self.len - 1;
            const child = self.items[child_idx];

            while (child_idx > 0 and compareFn(self.context, child, self.items[(child_idx - 1) / 2]) == .lt) {
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
                if (left_child_idx < self.len and compareFn(self.context, self.items[left_child_idx], top_element) == .lt) {
                    first = left_child_idx;
                }

                const right_child_idx = parent_idx * 2 + 2;
                if (right_child_idx < self.len and
                    compareFn(self.context, self.items[right_child_idx], top_element) == .lt and
                    compareFn(self.context, self.items[right_child_idx], self.items[left_child_idx]) == .lt)
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

fn cmp(ctxt: usize, a: usize, b: usize) Order {
    _ = ctxt;
    return if (a < b) .lt else if (a > b) .gt else .eq;
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
    print("{any}\n", .{heap.items});
    var current: usize = 0;
    for (0..20) |_| {
        const next = heap.remove();
        print("{}\n", .{next});
        assert(current <= next);
        current = next;
    }
}
