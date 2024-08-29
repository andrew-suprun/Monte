const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList([]u8);
const Isolate = @import("isolate.zig").Isolate(*ArrayList);

pub fn Engine(Tree: type, Game: type) type {
    return struct {
        allocator: Allocator,
        tree: Tree,
        game: Game,
        thread: std.Thread = undefined,
        running: bool = false,
        quit: bool = false,
        isolate: *Isolate,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !Self {
            const list = try allocator.create(ArrayList);
            list.* = ArrayList.init(allocator);
            const iso = try allocator.create(Isolate);
            iso.* = Isolate.init(list);
            return .{
                .allocator = allocator,
                .tree = Tree.init(allocator),
                .game = Game{},
                .isolate = iso,
                .thread = try std.Thread.spawn(.{}, reader, .{ allocator, iso }),
            };
        }

        pub fn deinit(self: *Self) void {
            var input = self.isolate.acquire();
            defer {
                self.isolate.release(input);
                self.allocator.destroy(self.isolate);
            }
            for (input.items) |item| {
                self.allocator.free(item);
            }
            input.deinit();
            self.thread.join();
        }

        pub fn run(self: *Self) !void {
            std.debug.print("running\n", .{});
            var best_move_buf: [8]u8 = undefined;
            var best_move: []u8 = best_move_buf[0..0];
            var move_buf: [8]u8 = undefined;
            var move: []u8 = move_buf[0..0];
            while (!self.quit) {
                if (!self.tree.root.conclusive and self.running) {
                    self.tree.expand(&self.game);
                    const node = self.tree.bestNode();
                    move = node.move.str(&move_buf);
                    if (!std.mem.eql(u8, best_move, move)) {
                        try std.io.getStdOut().writer().print("best-move move={s}; terminal={any}; score={d}\n", .{
                            move,
                            node.move.terminal,
                            node.score,
                            node.n_expansions,
                        });
                        best_move = &best_move_buf;
                        std.mem.copyForwards(u8, best_move, move);
                        best_move.len = move.len;
                    }
                }

                var input = self.isolate.acquire();
                defer self.isolate.release(input);

                while (input.items.len == 0 and !self.running) {
                    self.isolate.wait();
                }

                for (input.items) |command| {
                    try self.handleCommand(command);
                    self.allocator.free(command);
                    best_move = "";
                }
                input.clearRetainingCapacity();
            }
        }

        fn handleCommand(self: *Self, line: []u8) !void {
            var tokens = std.mem.tokenizeScalar(u8, line, ' ');
            if (tokens.next()) |command| {
                if (std.mem.eql(u8, command, "move")) try self.handleMove(tokens.next());
                // if (std.mem.eql(u8, command, "best-move")) try self.handleBestMove();
                if (std.mem.eql(u8, command, "info")) try self.handleInfo();
                if (std.mem.eql(u8, command, "stop")) self.handleStop();
                if (std.mem.eql(u8, command, "reset")) self.handleReset();
                if (std.mem.eql(u8, command, "quit")) self.quit = true;
            }
        }

        fn handleMove(self: *Self, token: ?[]const u8) !void {
            if (token == null) return error.Error;
            const move = try self.game.initMove(token.?);
            self.tree.makeMove(&self.game, move);
            if (!self.tree.root.conclusive) {
                self.tree.expand(&self.game);
                self.running = true;
            }

            // self.game.printBoard();
            // print("\n", .{});
        }

        // fn handleBestMove(self: *Self) !void {
        //     if (self.tree.root.children.len == 0) {
        //         std.debug.print("handleBestMove with no children: extentions {d}\n", .{self.tree.root.n_expansions});
        //         unreachable;
        //     }
        //     const node = self.tree.bestNode();
        //     var buf: [7]u8 = undefined;
        //     try std.io.getStdOut().writer().print("best-move move={s}; terminal={any}; score={d}\n", .{
        //         node.move.str(&buf),
        //         node.move.terminal,
        //         node.score,
        //     });
        // }

        fn handleInfo(self: *Self) !void {
            try std.io.getStdOut().writer().print("info extentions={d}\n", .{self.tree.root.n_expansions});
        }

        fn handleStop(self: *Self) void {
            std.debug.print("stopped\n", .{});
            self.running = false;
        }

        fn handleReset(self: *Self) void {
            const allocator = self.allocator;
            self.deinit();
            self.* = Self.init(allocator) catch unreachable;
        }

        fn replyError(message: []const u8) !void {
            try std.io.getStdOut().writer().print("error message={s}\n", .{message});
        }
    };
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
