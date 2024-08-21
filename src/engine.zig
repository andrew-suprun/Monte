const std = @import("std");
const print = std.debug.print;

pub fn Engine(Tree: type, Game: type) type {
    const State = struct {
        tree: Tree,
        game: Game,
        running: bool = false,
    };

    const Isolate = @import("isolate.zig").Isolate(State);

    return struct {
        allocator: std.mem.Allocator,
        in: std.fs.File.Reader,
        out: std.fs.File.Writer,
        thread: std.Thread = undefined,
        isolate: Isolate,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            var state = allocator.create(State) catch unreachable;
            state.tree = Tree.init(allocator);
            state.game = Game{};
            return .{
                .allocator = allocator,
                .in = std.io.getStdIn().reader(),
                .out = std.io.getStdOut().writer(),
                .isolate = Isolate.init(state),
            };
        }

        pub fn deinit(self: *Self) void {
            var state = self.isolate.acquire();
            defer self.isolate.release(state);
            state.tree.deinit();
            self.allocator.destroy(state);
            // self.thread.join();
        }

        pub fn run(self: *Self) !void {
            self.thread = try std.Thread.spawn(.{}, Self.searcher, .{&self.isolate});
            while (true) {
                const maybe_line = try self.in.readUntilDelimiterOrEofAlloc(self.allocator, '\n', 4096);
                if (maybe_line) |line|
                    try self.handleCommand(line);
            }
        }

        fn handleCommand(self: *Self, line: []u8) !void {
            var tokens = std.mem.tokenizeScalar(u8, line, ' ');
            if (tokens.next()) |command| {
                if (std.mem.eql(u8, command, "move")) try self.handleMove(tokens.next());
                if (std.mem.eql(u8, command, "go")) self.handleGo();
                if (std.mem.eql(u8, command, "stop")) self.handleStop();
            }
        }

        fn handleMove(self: *Self, token: ?[]const u8) !void {
            if (token == null) return error.Error;
            var state = self.isolate.acquire();
            defer self.isolate.release(state);
            const move = try state.game.initMove(token.?);
            state.tree.makeMove(move);
            state.game.makeMove(move);
            print("\nmove: {any}", .{move});
            state.game.printBoard(move);
        }

        fn handleGo(self: *Self) void {
            var state = self.isolate.acquire();
            defer self.isolate.release(state);

            state.running = true;
        }

        fn handleStop(self: *Self) void {
            var state = self.isolate.acquire();
            defer self.isolate.release(state);

            state.running = false;
        }

        fn replyError(self: Self, message: []const u8) void {
            _ = self;
            print("ERROR: {s}", .{message});
        }

        pub fn searcher(isolate: *Isolate) void {
            print("\nsearcher started", .{});
            defer print("\nsearcher ended\n", .{});

            while (true) {
                var state = isolate.acquire();
                defer isolate.release(state);

                while (!state.running) isolate.wait();
                print("\nthread started", .{});
                state.running = false;
            }
        }
    };
}
