const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Engine(Tree: type, Game: type) type {
    return struct {
        allocator: Allocator,
        tree: Tree,
        game: Game,
        name: ?[]u8 = null,
        quit: bool = false,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .tree = Tree.init(allocator),
                .game = Game{},
            };
        }

        pub fn deinit(_: *Self) void {}

        pub fn run(self: *Self) !void {
            var in = std.io.getStdIn().reader();

            while (!self.quit) {
                const maybe_line = try in.readUntilDelimiterOrEofAlloc(self.allocator, '\n', 4096);
                if (maybe_line) |line| {
                    try self.handleCommand(line);
                } else {
                    break;
                }
            }
        }

        fn handleCommand(self: *Self, line: []u8) !void {
            var tokens = std.mem.tokenizeScalar(u8, line, ' ');
            if (tokens.next()) |command| {
                if (std.mem.eql(u8, command, "set-name")) try self.handleSetName(tokens.next());
                if (std.mem.eql(u8, command, "move")) try self.handleMove(tokens.next());
                if (std.mem.eql(u8, command, "expand")) try self.handleExpand(tokens.next());
                if (std.mem.eql(u8, command, "info")) try self.handleInfo();
                if (std.mem.eql(u8, command, "reset")) self.handleReset();
                if (std.mem.eql(u8, command, "quit")) self.quit = true;
            }
        }

        fn handleSetName(self: *Self, token: ?[]const u8) !void {
            if (token) |name| {
                if (self.name) |old_name| {
                    self.allocator.free(old_name);
                }
                self.name = self.allocator.alloc(u8, name.len) catch unreachable;
                std.mem.copyForwards(u8, self.name.?, name);
            }
        }

        fn handleMove(self: *Self, token: ?[]const u8) !void {
            if (token == null) return;
            const move = try self.game.initMove(token.?);
            self.tree.makeMove(&self.game, move);
            std.debug.print("handled: move {s}\n", .{token.?});

            self.game.printBoard();
            std.debug.print("\n", .{});
        }

        fn handleExpand(self: *Self, token: ?[]const u8) !void {
            if (token == null) return;
            var n = try std.fmt.parseInt(usize, token.?, 10);
            if (n < 1) n = 1;
            for (0..n) |_| {
                if (self.tree.root.conclusive) break;
                self.tree.expand(&self.game);
            }
            var move_buf: [8]u8 = undefined;
            const node = self.tree.bestNode();
            const move = node.move.str(&move_buf);
            try std.io.getStdOut().writer().print("best-move move={s}; conclusive={any}; terminal={any}; score={d}; expansions={d}\n", .{
                move,
                node.conclusive,
                node.move.terminal,
                node.score,
                self.tree.root.n_expansions,
            });
        }

        fn handleInfo(self: *Self) !void {
            try std.io.getStdOut().writer().print("info expansions={d}\n", .{self.tree.root.n_expansions});
        }

        fn handleReset(self: *Self) void {
            const allocator = self.allocator;
            self.deinit();
            self.* = Self.init(allocator) catch unreachable;
        }

        // TODO: handle errors
        fn replyError(message: []const u8) !void {
            try std.io.getStdOut().writer().print("error message={s}\n", .{message});
        }
    };
}
