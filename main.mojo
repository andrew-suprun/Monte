from connect6 import SearchTree, C6, Move


fn main():
    var tree = C6[19, True]()
    var stone = tree.rollout(Move(0, 0))
    print("winner", stone)
