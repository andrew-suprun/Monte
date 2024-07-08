from connect6 import SearchTree, C6, Move, Stone
from random import random_ui64


fn main():
    var game = C6[board_size=19, max_children=32, debug=False]()

    var results = List(0, 0, 0)

    for _ in range(100_000):
        var result = game.rollout(
            # Move(int(random_ui64(0, 9)), int(random_ui64(0, 9)))
            # Move(0, 0)
            Move(8, 8)
        )
        if result == Stone.none:
            results[0] += 1
        elif result == Stone.black:
            results[1] += 1
        elif result == Stone.white:
            results[2] += 1

    print(
        "rollout results draw:",
        results[0],
        "black:",
        results[1],
        "white:",
        results[2],
    )


fn mainX():
    var tree = SearchTree[
        board_size=19, node_capacity=10_000_000, max_children=32, debug=False
    ]()
    print(tree.nodes[0].first_child)
    print(tree.nodes[1].first_child)
    print(tree.nodes[9_999_999].first_child)
    print(tree.free_node_list)
    print("done")
