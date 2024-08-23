const std = @import("std");
const print = std.debug.print;
const vaxis = @import("vaxis");
const Allocator = std.mem.Allocator;

const C6 = @import("Connect6.zig");
const SearchTree = @import("tree.zig").SearchTree(C6);
const Player = C6.Player;
const ArrayList = std.ArrayList([]u8);
const Isolate = @import("isolate.zig").Isolate(*ArrayList);

pub const panic = vaxis.panic_handler;

const Event = union(enum) {
    key_press: vaxis.Key,
    key_release: vaxis.Key,
    mouse: vaxis.Mouse,
    winsize: vaxis.Winsize,
};

const Engine = struct {
    allocator: Allocator,
    process: std.process.Child,
    in: std.fs.File.Writer,
    out: std.fs.File.Reader,
    isolate: Isolate,
    thread: std.Thread,

    fn deinit(self: *@This()) !void {
        for (self.isolate.t.items) |item| {
            print("# freeing {s}\n", .{item});
            self.isolate.t.allocator.free(item);
        }
        self.isolate.t.deinit();
        self.isolate.t.allocator.destroy(self.isolate.t);
        // self.thread.detach();
    }
};

fn startEngines(allocator: Allocator) ![2]Engine {
    var engines: [2]Engine = undefined;
    var names: [2][]const u8 = undefined;
    var arg_iter = std.process.args();
    _ = arg_iter.next();
    for (&names) |*name| {
        if (arg_iter.next()) |arg| {
            name.* = arg;
            print("# arg = {s}\n", .{arg});
        } else {
            print("Usage: ui-battle engine1 engine2\n", .{});
            return error.Error;
        }
    }
    for (names, &engines) |name, *engine| {
        const arg = [_][]const u8{name};
        engine.process = std.process.Child.init(&arg, allocator);
        engine.process.stdin_behavior = .Pipe;
        engine.process.stdout_behavior = .Pipe;
        engine.process.spawn() catch |err| {
            print("@@ start error: {any}\n", .{err});
            return err;
        };
        engine.in = engine.process.stdin.?.writer();
        engine.out = engine.process.stdout.?.reader();
        const list = try allocator.create(ArrayList);
        list.* = ArrayList.init(allocator);
        engine.isolate = Isolate.init(list);
        engine.thread = try std.Thread.spawn(.{}, reader, .{ allocator, &engine.isolate });
    }
    return engines;
}

fn reader(allocator: Allocator, isolate: *Isolate) !void {
    var in = std.io.getStdIn().reader();

    while (true) {
        const maybe_line = try in.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096);
        if (maybe_line) |line| {
            var input = isolate.acquire();

            defer isolate.release(input);

            try input.append(line);

            if (std.mem.eql(u8, line, "quit")) break;
        } else {
            break;
        }
    }
}

const Monte = struct {
    allocator: Allocator,
    should_quit: bool = false,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    mouse: ?vaxis.Mouse = null,
    winsize: vaxis.Winsize = undefined,
    engines: [2]Engine = undefined,
    board: [C6.board_size][C6.board_size]Player = [1][C6.board_size]Player{[1]Player{.none} ** C6.board_size} ** C6.board_size,
    highlighted_places: [4]C6.Place = undefined,
    n_highlighted_places: usize = 2,
    winner: ?Player = null,

    pub fn init(allocator: Allocator) !Monte {
        var result = Monte{
            .allocator = allocator,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .engines = try startEngines(allocator),
        };
        result.board[9][9] = .first;
        const place = C6.Place.init(9, 9);
        result.highlighted_places[0] = place;
        result.highlighted_places[1] = place;

        for (result.engines) |e| {
            try e.in.writeAll("move j10+j10\ngo\n");
        }

        return result;
    }

    pub fn deinit(self: *Monte) !void {
        print("#deinit.1\n", .{});
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        print("#deinit.2\n", .{});
        self.tty.deinit();
        print("#deinit.3\n", .{});
        try self.engines[0].deinit();
        print("#deinit.4\n", .{});
        try self.engines[1].deinit();
        print("#deinit.5\n", .{});
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

            print("###1\n", .{});
            loop.pollEvent();
            print("###2\n", .{});

            while (loop.tryEvent()) |event| {
                print("###3: event = {any}\n", .{event});
                try self.update(event);
                print("###4\n", .{});
            }
            print("###5\n", .{});

            self.draw(arena.allocator());
            print("###6\n", .{});

            var buffered = self.tty.bufferedWriter();
            try self.vx.render(buffered.writer().any());
            try buffered.flush();
            print("###7\n", .{});
        }
        print("###9\n", .{});
    }

    pub fn update(self: *Monte, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) {
                    self.should_quit = true;
                    print("quit = true", .{});
                }
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
        print("#draw\n", .{});
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
    defer app.deinit() catch unreachable;

    // Run the application
    try app.run();
}
