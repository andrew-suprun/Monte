allocator: std.heap.Allocator,
arena: std.heap.ArenaAllocator,
root: *Node,

const std = @import("std");
const SearchTree = @import("tree").SearchTree;
const Node = @import("tree").Node;
