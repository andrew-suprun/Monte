const std = @import("std");
const vaxis = @import("vaxis");

const C6 = @import("Connect6.zig");
const SearchTree = @import("tree.zig").SearchTree(C6);

const Player = C6.Player;

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
    game: C6,
    board: [C6.board_size][C6.board_size]Player = [1][C6.board_size]Player{[1]Player{.none} ** C6.board_size} ** C6.board_size,
    highlighted_places: [4]C6.Place = undefined,
    n_highlighted_places: usize = 2,
    winner: ?Player = null,

    pub fn init(allocator: std.mem.Allocator) !Monte {
        var result = Monte{
            .allocator = allocator,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .engine = SearchTree.init(allocator),
            .game = C6{},
        };
        result.board[9][9] = .first;
        const place = C6.Place.init(9, 9);
        const move = try result.game.initMove("j10+j10");
        result.engine.makeMove(move);
        result.game.makeMove(move);
        result.highlighted_places[0] = place;
        result.highlighted_places[1] = place;
        return result;
    }

    pub fn deinit(self: *Monte) void {
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
        self.engine.deinit();
    }

    pub fn run(self: *Monte) !void {
        var buf: [4096]u8 = undefined;
        const cwd = try std.process.getCwd(&buf);
        std.debug.print("cwd = {s}", .{cwd});

        var names: [2][]const u8 = undefined;
        var engines: [2]std.process.Child = undefined;
        var arg_iter = std.process.args();
        for (&names) |*name| {
            if (arg_iter.next()) |arg| {
                name.* = arg;
            } else {
                std.debug.print("Usage: ui-battle engine1 engine2\n", .{});
                return;
            }
        }
        for (names, &engines) |name, *eng| {
            const arg = [_][]const u8{name};
            eng.* = std.process.Child.init(&arg, self.allocator);
            try eng.spawn();
        }

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
        if (self.winner) |_| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true }))
                        self.should_quit = true;
                },
                else => {},
            }
            return;
        }
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }))
                    self.should_quit = true;
                if (key.matches(vaxis.Key.enter, .{})) {
                    if (self.n_highlighted_places == 4) {
                        const p1 = self.highlighted_places[2];
                        const p2 = self.highlighted_places[3];
                        const move = self.game.initMoveFromPlaces(.{ p1, p2 });
                        self.engine.makeMove(move);
                        self.game.makeMove(move);
                        self.winner = self.engineMove();
                    }
                }
                if (key.matches(vaxis.Key.escape, .{})) {
                    if (self.n_highlighted_places > 2) {
                        self.n_highlighted_places -= 1;
                        const place = self.highlighted_places[self.n_highlighted_places];
                        self.board[place.y][place.x] = .none;
                    }
                }
            },
            .mouse => |mouse| self.mouse = mouse,
            .winsize => |ws| {
                self.winsize = ws;
                try self.vx.resize(self.allocator, self.tty.anyWriter(), ws);
            },
            else => {},
        }
    }

    pub fn engineMove(self: *Monte) ?Player {
        for (0..100_000) |_| {
            if (self.engine.root.min_result == self.engine.root.max_result) {
                break;
            }
            self.engine.expand(&self.game);
        }
        const move = self.engine.bestMove();
        self.engine.makeMove(move);
        self.game.makeMove(move);
        self.n_highlighted_places = 2;
        self.highlighted_places[0] = move.places[0];
        self.highlighted_places[1] = move.places[1];
        self.board[move.places[0].y][move.places[0].x] = move.player;
        self.board[move.places[1].y][move.places[1].x] = move.player;
        return move.winner;
    }

    pub fn draw(self: *Monte, allocator: std.mem.Allocator) void {
        const win = self.vx.window();
        win.clear();
        win.fill(vaxis.Cell{ .style = style_board });

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
                if (x < 0 or x >= C6.board_size) break :mouse_blk;
                const y = mouse.row - start_y - 1;
                if (y < 0 or y >= C6.board_size) break :mouse_blk;
                if (self.board[y][x] != .none) break :mouse_blk;
                if (self.n_highlighted_places == 4) break :mouse_blk;

                self.board[y][x] = .second;
                self.highlighted_places[self.n_highlighted_places] = C6.Place.init(x, y);
                self.n_highlighted_places += 1;
            }
        }

        printSegment(win, "  a b c d e f g h i j k l m n o p q r s  ", style_board, start_x, start_y);
        printSegment(win, "  a b c d e f g h i j k l m n o p q r s  ", style_board, start_x, start_y + 20);
        for (0..C6.board_size) |y| {
            const row_str = std.fmt.allocPrint(allocator, "{d:2}", .{C6.board_size - y}) catch unreachable;
            printSegment(win, row_str, style_board, start_x, start_y + 1 + y);
            printSegment(win, row_str, style_board, start_x + 39, start_y + 1 + y);
        }

        for (0..C6.board_size) |y| {
            for (0..C6.board_size) |x| {
                const highlight = self.highlighted(x, y);
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
                            else if (x == C6.board_size - 1)
                                printSegment(win, "─┐", style_board, start_x + 1 + x * 2, start_y + 1 + y)
                            else
                                printSegment(win, "─┬", style_board, start_x + 1 + x * 2, start_y + 1 + y);
                        } else if (y == C6.board_size - 1) {
                            if (x == 0)
                                printSegment(win, "└", style_board, start_x + 2 + x * 2, start_y + 1 + y)
                            else if (x == C6.board_size - 1)
                                printSegment(win, "─┘", style_board, start_x + 1 + x * 2, start_y + 1 + y)
                            else
                                printSegment(win, "─┴", style_board, start_x + 1 + x * 2, start_y + 1 + y);
                        } else {
                            if (x == 0)
                                printSegment(win, "├", style_board, start_x + 2 + x * 2, start_y + 1 + y)
                            else if (x == C6.board_size - 1)
                                printSegment(win, "─┤", style_board, start_x + 1 + x * 2, start_y + 1 + y)
                            else
                                printSegment(win, "─┼", style_board, start_x + 1 + x * 2, start_y + 1 + y);
                        }
                    },
                }
            }
        }
        if (self.winner) |w| {
            switch (w) {
                .first => printSegment(win, "X Won", style_black_highlight, start_x + 2, start_y + 21),
                .second => printSegment(win, "O Won", style_white_highlight, start_x + 2, start_y + 21),
                else => {},
            }
        }
    }

    fn highlighted(self: Monte, x: usize, y: usize) bool {
        const place = C6.Place.init(x, y);
        for (self.highlighted_places[0..self.n_highlighted_places]) |hl_place| {
            if (place.eql(hl_place)) return true;
        }
        return false;
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
    .ul = .{ .rgb = [_]u8{ 255, 127, 127 } },
    .ul_style = .double,
    .bold = true,
};

const style_black = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 255, 127, 127 } },
    .bg = bg,
    .bold = true,
};

const style_white_highlight = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 127, 127, 255 } },
    .bg = bg,
    .ul = .{ .rgb = [_]u8{ 127, 127, 255 } },
    .ul_style = .double,
    .bold = true,
};

const style_white = vaxis.Style{
    .fg = .{ .rgb = [_]u8{ 127, 127, 255 } },
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
