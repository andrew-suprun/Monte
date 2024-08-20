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
            var place_tokens = std.mem.tokenizeScalar(u8, token.?, '+');
            const coords: [2]Game.Place = .{
                try parseToken(place_tokens.next()),
                try parseToken(place_tokens.next()),
            };
            var state = self.isolate.acquire();
            defer self.isolate.release(state);
            const move = state.game.initMove(coords);
            state.tree.makeMove(move);
            state.game.makeMove(move);
            print("\nmove: {any}", .{move});
            state.game.printBoard(move);
        }

        fn parseToken(maybe_token: ?[]const u8) !Game.Place {
            if (maybe_token == null) return error.Error;
            const token = maybe_token.?;
            if (token.len < 2 or token.len > 3) return error.Error;
            if (token[0] < 'a' or token[0] > 's') return error.Error;
            if (token[1] < '0' or token[1] > '9') return error.Error;
            const x = token[0] - 'a';
            var y = token[1] - '0';
            print("\ny.1: {d}", .{y});
            if (token.len == 3) {
                if (token[2] < '0' or token[2] > '9') return error.Error;
                y = 10 * y + token[2] - '0';
                print("\ny.2: {d}", .{y});
            }
            y = Game.board_size - y;
            print("\ny.3: x: {d} y: {d} size: {d}", .{ x, y, Game.board_size });
            if (x > Game.board_size or y > Game.board_size) return error.Error;
            return Game.Place.init(x, y);
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
