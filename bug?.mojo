from collections import Optional


@value
struct Node:
    var child: Optional[Node]


fn main():
    _ = Optional(Node(None)).value()
