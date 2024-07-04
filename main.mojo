from connect6 import SearchTree, C6, Move, Stone


fn mainX():
    var game = C6[board_size=19, max_children=32, debug=False]()

    var results = List(0, 0, 0)

    for _ in range(10000):
        var result = game.rollout(
            # Move(int(random_ui64(0, 9)), int(random_ui64(0, 9)))
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


fn main():
    _ = C6[19, 32, True]().rollout(Move(8, 8))
