const std = @import("std");
const print = std.debug.print;

pub fn Engine(Tree: type, Game: type) type {
    return struct {
        allocator: std.mem.Allocator,
        in: std.fs.File.Reader,
        out: std.fs.File.Writer,
        thread: std.Thread = undefined,
        isolate: Isolate,

        const Self = @This();

        const Isolate = struct {
            tree: Tree,
            game: Game,
            mutex: std.Thread.Mutex,
            cond: std.Thread.Condition,
            running: bool = false,

            fn acquire(self: *@This()) void {
                self.mutex.lock();
                self.cond.wait(&self.mutex);
            }

            fn release(self: *@This()) void {
                self.mutex.unlock();
                self.cond.signal();
            }
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .in = std.io.getStdIn().reader(),
                .out = std.io.getStdOut().writer(),
                .isolate = Isolate{
                    .tree = Tree.init(allocator),
                    .game = Game{},
                    .mutex = std.Thread.Mutex{},
                    .cond = std.Thread.Condition{},
                },
            };
        }

        pub fn deinit(self: *Self) void {
            self.isolate.acquire();
            defer self.isolate.release();
            self.isolate.tree.deinit();
            self.thread.join();
        }

        pub fn run(self: *Self) !void {
            self.thread = try std.Thread.spawn(.{}, Self.searcher, .{&self.isolate});
            while (true) {
                const maybe_line = try self.in.readUntilDelimiterOrEofAlloc(self.allocator, ' ', 4096);
                if (maybe_line) |line|
                    try self.handleCommand(line);
            }
        }

        fn handleCommand(self: *Self, line: []u8) !void {
            var tokens = std.mem.tokenizeScalar(u8, line, ' ');
            if (tokens.next()) |command| {
                if (std.mem.eql(u8, command, "move")) self.handleMove(&tokens);
            }
        }

        fn handleMove(self: *Self, tokens: *std.mem.TokenIterator(u8, .scalar)) void {
            print("\nmove: ", .{});
            var coords: [2]Game.Place = undefined;
            for (0..2) |i| {
                if (tokens.next()) |token| {
                    coords[i] = parsePlace(token) catch {
                        self.replyError("invalid move");
                    };
                } else {
                    self.replyError("invalid move");
                    return;
                }
            }
            self.isolate.acquire();
            defer self.isolate.release();
            const move = self.isolate.game.initMove(coords);
            print("\nmove: {any}", .{move});
        }

        fn parsePlace(token: []const u8) !Game.Place {
            _ = token;
            return Game.Place.init(9, 9);
        }

        fn replyError(self: Self, message: []const u8) void {
            _ = self;
            _ = message;
        }
        pub fn searcher(_: *Isolate) void {}
    };
}
