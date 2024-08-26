const std = @import("std");
const print = std.debug.print;
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
        isolate: Isolate,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !Self {
            const list = try allocator.create(ArrayList);
            list.* = ArrayList.init(allocator);
            return .{
                .allocator = allocator,
                .tree = Tree.init(allocator),
                .game = Game.init(),
                .isolate = Isolate.init(list),
            };
        }

        pub fn deinit(self: *Self) void {
            var input = self.isolate.acquire();
            defer self.isolate.release(input);
            for (input.items) |item| {
                self.allocator.free(item);
            }
            input.deinit();
            self.thread.join();
        }

        pub fn run(self: *Self) !void {
            self.thread = try std.Thread.spawn(.{}, reader, .{ self.allocator, &self.isolate });
            while (!self.quit) {
                if (self.running) {
                    for (0..100) |_| {
                        self.tree.expand(&self.game);
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
                }
                input.clearRetainingCapacity();
            }
        }

        fn handleCommand(self: *Self, line: []u8) !void {
            var tokens = std.mem.tokenizeScalar(u8, line, ' ');
            if (tokens.next()) |command| {
                if (std.mem.eql(u8, command, "move")) try self.handleMove(tokens.next());
                if (std.mem.eql(u8, command, "best-move")) try self.handleBestMove();
                if (std.mem.eql(u8, command, "info")) try self.handleInfo();
                if (std.mem.eql(u8, command, "go")) self.handleGo();
                if (std.mem.eql(u8, command, "stop")) self.handleStop();
                if (std.mem.eql(u8, command, "quit")) self.quit = true;
            }
        }

        fn handleMove(self: *Self, token: ?[]const u8) !void {
            if (token == null) return error.Error;
            const move = try self.game.initMove(token.?);
            self.tree.makeMove(move);
            self.game.makeMove(move);
            self.game.printBoard(move);
            print("\n", .{});
        }

        fn handleBestMove(self: *Self) !void {
            const move = self.tree.bestMove();
            var buf: [7]u8 = undefined;
            try std.io.getStdOut().writer().print("best-move {s}\n", .{move.str(&buf)});
        }

        fn handleInfo(self: *Self) !void {
            try std.io.getStdOut().writer().print("extentions {d}\n", .{self.tree.root.n_extentions});
        }

        fn handleGo(self: *Self) void {
            print("running\n", .{});
            self.running = true;
        }

        fn handleStop(self: *Self) void {
            print("stopped\n", .{});
            self.running = false;
        }

        fn replyError(message: []const u8) !void {
            try std.io.getStdOut().writer().print("ERROR: {s}\n", .{message});
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
