const std = @import("std");

pub fn Isolate(T: type) type {
    return struct {
        t: T,
        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},

        const Self = @This();

        pub fn init(t: T) Self {
            return .{ .t = t };
        }

        pub fn acquire(self: *Self) T {
            self.mutex.lock();
            return self.t;
        }

        pub fn release(self: *Self, t: T) void {
            self.t = t;
            self.mutex.unlock();
            self.cond.signal();
        }

        pub fn wait(self: *Self) void {
            self.cond.wait(&self.mutex);
        }
    };
}
