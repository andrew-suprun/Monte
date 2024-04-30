pub const BoardSize = 7;
pub const Place = struct { x: isize, y: isize };
pub const Move = [2]Place;
pub const RowIndices = [BoardSize][BoardSize][4]usize;
pub const RowConfig = struct { x: isize, y: isize, dx: isize, dy: isize, count: isize };

const row_count: usize = 6 * BoardSize - 21;

pub fn row_config(idx: isize) RowConfig {
    return row_config_data[@intCast(idx)];
}

pub const row_config_data = blk: {
    // @setEvalBranchQuota(2000);
    var row_cfg = [_]RowConfig{.{ .x = 0, .y = 0, .dx = 0, .dy = 0, .count = 0 }} ** row_count;

    var row_idx: usize = 1;
    for (0..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 0, .count = BoardSize - 5 };
        row_idx += 1;
    }

    for (0..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = @intCast(i), .y = 0, .dx = 0, .dy = 1, .count = BoardSize - 5 };
        row_idx += 1;
    }

    for (5..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = -1, .count = @intCast(i - 4) };
        row_idx += 1;
    }

    for (1..BoardSize - 5) |i| {
        row_cfg[row_idx] = RowConfig{ .x = @intCast(i), .y = BoardSize - 1, .dx = 1, .dy = -1, .count = @intCast(BoardSize - 5 - i) };
        row_idx += 1;
    }

    for (5..BoardSize) |i| {
        row_cfg[row_idx] = RowConfig{ .x = @intCast(BoardSize - 1 - i), .y = 0, .dx = 1, .dy = 1, .count = @intCast(i - 4) };
        row_idx += 1;
    }

    for (1..BoardSize - 5) |i| {
        row_cfg[row_idx] = RowConfig{ .x = 0, .y = @intCast(i), .dx = 1, .dy = 1, .count = @intCast(BoardSize - 5 - i) };
        row_idx += 1;
    }

    break :blk row_cfg;
};

pub inline fn raw_indices(place: Place) [4]isize {
    return raw_indices_data[@intCast(place.x)][@intCast(place.y)];
}
const raw_indices_data = blk: {
    // @setEvalBranchQuota(2000);
    var row_inds = [_][BoardSize][4]isize{[_][4]isize{[_]isize{ 0, 0, 0, 0 }} ** BoardSize} ** BoardSize;

    var row_idx: usize = 1;
    for (0..BoardSize) |i| {
        for (0..BoardSize) |j| {
            row_inds[j][i][0] = row_idx;
        }

        row_idx += 1;
    }

    for (0..BoardSize) |i| {
        for (0..BoardSize) |j| {
            row_inds[i][j][1] = row_idx;
        }

        row_idx += 1;
    }

    for (5..BoardSize) |i| {
        for (0..i + 1) |j| {
            row_inds[j][i - j][2] = row_idx;
        }

        row_idx += 1;
    }

    for (1..BoardSize - 5) |i| {
        for (i..BoardSize) |j| {
            row_inds[j][BoardSize - 1 + i - j][2] = row_idx;
        }

        row_idx += 1;
    }

    for (5..BoardSize) |i| {
        for (0..i + 1) |j| {
            row_inds[BoardSize - 1 - i + j][j][3] = row_idx;
        }

        row_idx += 1;
    }

    for (1..BoardSize - 5) |i| {
        for (0..BoardSize - i) |j| {
            row_inds[j][i + j][3] = row_idx;
        }

        row_idx += 1;
    }

    break :blk row_inds;
};
