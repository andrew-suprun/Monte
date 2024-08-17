const std = @import("std");
const vaxis = @import("vaxis");

const board_size = 19;
const max_moves = 300;

const Player = @import("tree.zig").Player;
const Move = @import("connect6.zig").Move(Player);
const C6 = @import("connect6.zig").C6(Player, board_size, max_moves);
const SearchTree = @import("tree.zig").SearchTree(C6, Move);

pub const panic = vaxis.panic_handler;

const Event = union(enum) {
    key_press: vaxis.Key,
    key_release: vaxis.Key,
    mouse: vaxis.Mouse,
    winsize: vaxis.Winsize,
};

const Monte = struct {
    allocator: std.mem.Allocator,
    should_quit: bool = false,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    mouse: ?vaxis.Mouse = null,
    winsize: vaxis.Winsize = undefined,
    engine: SearchTree,
    board: [board_size][board_size]Player,
    last_move: Move,

    pub fn init(allocator: std.mem.Allocator) !Monte {
        var engine = SearchTree.init(allocator);
        const move = Move{ .places = .{ .{ .x = 9, .y = 9 }, .{ .x = 9, .y = 9 } }, .score = 0, .player = .first };
        engine.makeMove(move);
        var board = [1][board_size]Player{[1]Player{.none} ** board_size} ** board_size;
        board[9][9] = .first;

        return .{
            .allocator = allocator,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .engine = engine,
            .board = board,
            .last_move = move,
        };
    }

    pub fn deinit(self: *Monte) void {
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
    }

    pub fn run(self: *Monte) !void {
        var loop: vaxis.Loop(Event) = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };
        try loop.init();

        try loop.start();
        defer loop.stop();

        try self.vx.enterAltScreen(self.tty.anyWriter());
        try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);
        try self.vx.setMouseMode(self.tty.anyWriter(), true);

        while (!self.should_quit) {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();

            loop.pollEvent();

            while (loop.tryEvent()) |event| {
                try self.update(event);
            }

            self.draw(arena.allocator());

            var buffered = self.tty.bufferedWriter();
            try self.vx.render(buffered.writer().any());
            try buffered.flush();
        }
    }

    pub fn update(self: *Monte, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }))
                    self.should_quit = true;
            },
            .mouse => |mouse| self.mouse = mouse,
            .winsize => |ws| {
                self.winsize = ws;
                try self.vx.resize(self.allocator, self.tty.anyWriter(), ws);
            },
            else => {},
        }
    }

    pub fn draw(self: *Monte, allocator: std.mem.Allocator) void {
        const win = self.vx.window();
        win.clear();

        if (self.winsize.cols < 44 or self.winsize.rows < 21) {
            _ = try win.printSegment(.{ .text = "Too Small!!!", .style = .{
                .fg = .{ .rgb = [_]u8{ 0, 0, 0 } },
                .bg = .{ .rgb = [_]u8{ 255, 31, 31 } },
            } }, .{});
            return;
        }

        const start_x = self.winsize.cols / 2 - 22;
        const start_y = self.winsize.rows / 2 - 11;

        mouse_blk: {
            if (self.mouse) |mouse| {
                self.mouse = null;
                if (mouse.button != .left or mouse.type != .press) break :mouse_blk;

                const dx = mouse.col - start_x - 2;
                if (dx % 2 == 1) break :mouse_blk;
                const x = dx / 2;
                if (x < 0 or x >= board_size) break :mouse_blk;
                const y = mouse.row - start_y - 1;
                if (y < 0 or y >= board_size) break :mouse_blk;
                self.board[y][x] = .second;
                self.last_move = Move{
                    .places = .{ .{ .x = @intCast(x), .y = @intCast(y) }, .{ .x = @intCast(x), .y = @intCast(y) } },
                    .score = 0,
                    .player = .second,
                };
            }
        }

        printSegment(win, "  a b c d e f g h i j k l m n o p q r s  ", style_board, start_x, start_y);
        printSegment(win, "  a b c d e f g h i j k l m n o p q r s  ", style_board, start_x, start_y + 20);
        for (0..board_size) |y| {
            const row_str = std.fmt.allocPrint(allocator, "{d:2}", .{board_size - y}) catch unreachable;
            printSegment(win, row_str, style_board, start_x, start_y + 1 + y);
            printSegment(win, row_str, style_board, start_x + 39, start_y + 1 + y);
        }

        const place1 = self.last_move.places[0];
        const place2 = self.last_move.places[1];
        for (0..board_size) |y| {
            for (0..board_size) |x| {
                const highlight = place1.x == x and place1.y == y or place2.x == x and place2.y == y;
                if (x > 0) printSegment(win, "─", style_board, start_x + 1 + x * 2, start_y + 1 + y);

                switch (self.board[y][x]) {
                    .first => if (highlight) {
                        printSegment(win, "X", style_black_highlight, start_x + 2 + x * 2, start_y + 1 + y);
                    } else {
                        printSegment(win, "X", style_black, start_x + 2 + x * 2, start_y + 1 + y);
                    },
                    .second => if (highlight) {
                        printSegment(win, "O", style_white_highlight, start_x + 2 + x * 2, start_y + 1 + y);
                    } else {
                        printSegment(win, "O", style_white, start_x + 2 + x * 2, start_y + 1 + y);
                    },
                    // .white => if (place1.x == x and place1.y == y or place2.x == x and place2.y == y) print("─@", .{}) else print("─O", .{}),
                    else => {
                        if (y == 0) {
                            if (x == 0)
                                printSegment(win, "┌", style_board, start_x + 2 + x * 2, start_y + 1 + y)
                            else if (x == board_size - 1)
                                printSegment(win, "─┐", style_board, start_x + 1 + x * 2, start_y + 1 + y)
                            else
                                printSegment(win, "─┬", style_board, start_x + 1 + x * 2, start_y + 1 + y);
                        } else if (y == board_size - 1) {
                            if (x == 0)
                                printSegment(win, "└", style_board, start_x + 2 + x * 2, start_y + 1 + y)
                            else if (x == board_size - 1)
                                printSegment(win, "─┘", style_board, start_x + 1 + x * 2, start_y + 1 + y)
                            else
                                printSegment(win, "─┴", style_board, start_x + 1 + x * 2, start_y + 1 + y);
                        } else {
                            if (x == 0)
                                printSegment(win, "├", style_board, start_x + 2 + x * 2, start_y + 1 + y)
                            else if (x == board_size - 1)
                                printSegment(win, "─┤", style_board, start_x + 1 + x * 2, start_y + 1 + y)
                            else
                                printSegment(win, "─┼", style_board, start_x + 1 + x * 2, start_y + 1 + y);
                        }
                    },
                }
            }
        }
    }
};

const bg: vaxis.Color = .{ .rgb = [_]u8{ 0, 0, 0 } };

const style_board = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 127, 127, 127 } },
    .bg = bg,
};

const style_black_highlight = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 255, 127, 127 } },
    .bg = bg,
    .bold = true,
};

const style_black = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 255, 63, 63 } },
    .bg = bg,
    .bold = true,
};

const style_white_highlight = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 127, 127, 255 } },
    .bg = bg,
    .bold = true,
};

const style_white = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 63, 63, 255 } },
    .bg = bg,
    .bold = true,
};

pub fn printSegment(win: vaxis.Window, text: []const u8, style: vaxis.Style, x: usize, y: usize) void {
    _ = try win.printSegment(.{ .text = text, .style = style }, .{ .row_offset = y, .col_offset = x });
}

/// Keep our main function small. Typically handling arg parsing and initialization only
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }
    const allocator = gpa.allocator();

    // Initialize our application
    var app = try Monte.init(allocator);
    defer app.deinit();

    // Run the application
    try app.run();
}
