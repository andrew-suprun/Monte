const std = @import("std");

pub fn Stats(Player: type) type {
    return struct {
        rollout_diff: f32 = 0,
        n_rollouts: f32 = 1,

        const Self = @This();
        pub inline fn calcScore(self: Self, player: Player) f32 {
            return if (player == .first)
                self.rollout_diff / self.n_rollouts
            else
                -self.rollout_diff / self.n_rollouts;
        }

        pub fn debugPrint(self: Self) void {
            std.debug.print("rollout_diff: {d:3} | rollouts: {d:4}", .{
                self.rollout_diff,
                self.n_rollouts,
            });
        }
    };
}
