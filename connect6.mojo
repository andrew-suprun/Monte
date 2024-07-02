from utils.static_tuple import InlineArray
from collections import Optional
from sys import exit
from random import random_ui64


@value
@register_passable("trivial")
struct Stone:
    var stone: Int8

    alias none: Stone = 0x00
    alias black: Stone = 0x01
    alias white: Stone = 0x10

    fn __init__(inout self, value: IntLiteral):
        self.stone = value

    fn __eq__(self, other: Self) -> Bool:
        return self.stone == other.stone

    fn __ne__(self, other: Self) -> Bool:
        return self.stone != other.stone

    fn __iadd__(inout self, other: Self):
        self.stone += other.stone

    fn __isub__(inout self, other: Self):
        self.stone -= other.stone

    fn __str__(self) -> String:
        if self == Self.none:
            return "."
        elif self == Self.black:
            return "X"
        else:
            return "O"


@value
@register_passable("trivial")
struct Move:
    var x: Int8
    var y: Int8

    fn __eq__(self, other: Self) -> Bool:
        return self.x == other.x and self.y == other.y

    fn __str__(self) -> String:
        return "[" + str(self.x) + ":" + str(self.y) + "]"


@value
struct Grid[T: CollectionElement, size: Int]:
    var data: InlineArray[InlineArray[T, size], size]

    fn __init__(inout self, value: T):
        var row = InlineArray[T, size](value)
        self.data = InlineArray[InlineArray[T, size], size](row)

    fn __getitem__(self, x: Int, y: Int) -> T:
        return self.data[y][x]

    fn __getitem__(self, move: Move) -> T:
        return self.data[int(move.y)][int(move.x)]

    fn __setitem__(inout self, x: Int, y: Int, val: T):
        self.data[y][x] = val

    fn __setitem__(inout self, move: Move, val: T):
        self.data[int(move.y)][int(move.x)] = val


@value
struct C6[board_size: Int, debug: Bool]:
    var board: Grid[Stone, board_size]
    var scores: Grid[Int32, board_size]
    var move_number: Int32

    fn __init__(inout self):
        self.board = Stone.none
        self.scores = 0
        self.move_number = 0
        random.seed()

        calc_scores(self.board, self.scores)
        _ = self.make_move(Move(board_size / 2, board_size / 2))

    fn make_move(inout self, move: Move) -> Optional[Stone]:
        if debug:
            var stone = self.next_stone()
            var score = self.scores[move]
            var winner = self.place_stone(move)
            print("place", stone, "at", move, "score", score)
            print(self.str_board(move))
            if winner is None:
                self.check_scores()
            else:
                print("winner =", winner.value()[])
            print(self)
            return winner
        else:
            return self.place_stone(move)

    fn place_stone(inout self, move: Move) -> Optional[Stone]:
        var stone = self.next_stone()
        var x = int(move.x)
        var y = int(move.y)

        while True:
            var start_x = max(x, 5) - 5
            var end_x = min(x + 1, board_size - 5)
            var stones = self.board[start_x, y]

            @parameter
            for i in range(1, 5):
                stones += self.board[start_x + i, y]
            for dx in range(start_x, end_x):
                stones += self.board[dx + 5, y]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
                    print("place stone 1: winner =", d[1])
                    return d[1]

                @parameter
                for c in range(6):
                    self.scores[dx + c, y] += d[0]
                stones -= self.board[dx, y]
            break

        while True:
            var start_y = max(y, 5) - 5
            var end_y = min(y + 1, board_size - 5)
            var stones = self.board[x, start_y]

            @parameter
            for i in range(1, 5):
                stones += self.board[x, start_y + i]
            for dy in range(start_y, end_y):
                stones += self.board[x, dy + 5]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
                    print("place stone 2: winner =", d[1])
                    return d[1]

                @parameter
                for c in range(6):
                    self.scores[x, dy + c] += d[0]
                stones -= self.board[x, dy]
            break

        while True:
            var minIdx = min(min(x, y), 5)
            var maxIdx = max(x, y)

            if maxIdx - minIdx >= board_size - 5:
                break

            var start_x = x - minIdx
            var start_y = y - minIdx
            var count = min(
                min(minIdx + 1, board_size - maxIdx),
                board_size - 5 + minIdx - maxIdx,
            )

            var stones = self.board[start_x, start_y]

            @parameter
            for i in range(1, 5):
                stones += self.board[start_x + i, start_y + i]

            for i in range(count):
                stones += self.board[start_x + i + 5, start_y + i + 5]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
                    print("place stone 3: winner =", d[1])
                    return d[1]

                @parameter
                for e in range(6):
                    self.scores[start_x + i + e, start_y + i + e] += d[0]
                stones -= self.board[start_x + i, start_y + i]
            break

        while True:
            var rev_x = board_size - 1 - x
            var minIdx = min(min(rev_x, y), 5)
            var maxIdx = max(rev_x, y)

            if maxIdx - minIdx >= board_size - 5:
                break

            var start_x = x + minIdx
            var start_y = y - minIdx
            var count = min(
                min(minIdx + 1, board_size - maxIdx),
                board_size - 5 + minIdx - maxIdx,
            )

            var stones = self.board[start_x, start_y]

            @parameter
            for i in range(1, 5):
                stones += self.board[start_x - i, start_y + i]

            for c in range(count):
                stones += self.board[start_x - 5 - c, start_y + 5 + c]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
                    print("place stone 4: winner =", d[1])
                    return d[1]

                @parameter
                for e in range(6):
                    self.scores[start_x - c - e, start_y + c + e] += d[0]
                stones -= self.board[start_x - c, start_y + c]
            break

        self.board[x, y] = stone
        self.move_number += 1
        return None

    fn rollout(self, move: Move) -> Stone:
        var game = self

        var winner = game.make_move(move)
        if winner is not None:
            return winner.value()[]
        while True:
            var next_move = game.rollout_move()
            if next_move is not None:
                winner = game.make_move(next_move.value()[])
                if winner is not None:
                    return winner.value()[]
            else:
                return Stone.none

    fn rollout_move(self) -> Optional[Move]:
        var best_move = Move(0, 0)
        var best_score: Int32 = 0
        var prob: UInt64 = 2
        for y in range(board_size):
            for x in range(board_size):
                if self.board[x, y] != Stone.none:
                    continue
                var score = self.scores[x, y]
                if score > best_score:
                    best_score = score
                    best_move = Move(x, y)
                    prob = 2
                elif score == best_score:
                    if random_ui64(0, prob) == 0:
                        best_move = Move(x, y)
                        prob += 1
        if best_score < 32:
            return None
        return best_move

    fn check_scores(self):
        var scores = Grid[Int32, board_size](0)
        calc_scores(self.board, scores)
        var failed = False
        for y in range(board_size):
            for x in range(board_size):
                if (
                    self.board[x, y] == Stone.none
                    and self.scores[x, y] != scores[x, y]
                ):
                    print(
                        "Failure: at",
                        Move(x, y),
                        "expected =",
                        scores[x, y],
                        "actual =",
                        self.scores[x, y],
                    )
                    failed = True
        if failed:
            print("FAILURE\n", self, sep="")
            exit(1)

    @always_inline
    fn next_stone(self) -> Stone:
        return Stone.black if ((self.move_number + 3) & 2 == 2) else Stone.white

    fn __str__(self) -> String:
        var result = String(" yx|")
        for i in range(board_size):
            result += pad(str(i), 5)
        result += " |\n---+" + str("-----") * board_size + "-+---\n"
        for y in range(board_size):
            result += pad(str(y), 2) + " |"
            for x in range(board_size):
                if self.board[x, y] == Stone.none:
                    result += pad(str(self.scores[x, y]), 5)
                else:
                    result += pad(str(self.board[x, y]), 5)
            result += " | " + pad(str(y), 2) + "\n"
        result += "---+" + str("-----") * board_size + "-+---\n   |"
        for i in range(board_size):
            result += pad(str(i), 5)
        result += " |\n"

        return result

    fn str_board(self, move: Move) -> String:
        var result = String(" yx|")
        for i in range(board_size):
            result += pad(str(i % 10), 2)
        result += " |\n---+" + str("--") * board_size + "-+---\n"
        for y in range(board_size):
            result += pad(str(y), 2) + " |"
            for x in range(board_size):
                if self.board[x, y] == Stone.black:
                    result += " X"
                elif self.board[x, y] == Stone.white:
                    result += " O"
                elif self.board[x, y] == Stone.none:
                    if move == Move(x, y):
                        if self.next_stone() == Stone.black:
                            result += " #"
                        else:
                            result += " @"
                    else:
                        result += " ."
            result += " | " + pad(str(y), 2) + "\n"
        result += "---+" + str("--") * board_size + "-+---\n   |"
        for i in range(board_size):
            result += pad(str(i % 10), 2)
        result += " |\n"

        return result


fn calc_scores[
    board_size: Int
](board: Grid[Stone, board_size], inout scores: Grid[Int32, board_size]):
    for a in range(board_size):
        var hStones = board[0, a]
        var vStones = board[a, 0]

        @parameter
        for b in range(1, 5):
            hStones += board[b, a]
            vStones += board[a, b]

        for b in range(board_size - 5):
            hStones += board[b + 5, a]
            vStones += board[a, b + 5]
            var eScore = calc_score(hStones)
            var sScore = calc_score(vStones)

            @parameter
            for c in range(6):
                scores[b + c, a] += eScore
                scores[a, b + c] += sScore

            hStones -= board[b, a]
            vStones -= board[a, b]

    for a in range(1, board_size - 5):
        var swStones = board[0, a]
        var neStones = board[a, 0]
        var nwStones = board[0, board_size - 1 - a]
        var seStones = board[board_size - 1, a]

        @parameter
        for b in range(1, 5):
            swStones += board[b, a + b]
            neStones += board[a + b, b]
            nwStones += board[b, board_size - 1 - a - b]
            seStones += board[board_size - 1 - b, a + b]

        for b in range(board_size - 5 - a):
            swStones += board[b + 5, a + b + 5]
            neStones += board[a + b + 5, b + 5]
            nwStones += board[b + 5, board_size - 6 - a - b]
            seStones += board[board_size - 6 - b, a + b + 5]
            var swScore = calc_score(swStones)
            var neScore = calc_score(neStones)
            var nwScore = calc_score(nwStones)
            var seScore = calc_score(seStones)

            @parameter
            for c in range(6):
                scores[b + c, a + b + c] += swScore
                scores[a + b + c, b + c] += neScore
                scores[b + c, board_size - 1 - a - b - c] += nwScore
                scores[board_size - 1 - b - c, a + b + c] += seScore

            swStones -= board[b, a + b]
            neStones -= board[a + b, b]
            nwStones -= board[b, board_size - 1 - a - b]
            seStones -= board[board_size - 1 - b, a + b]

    var nwseStones = board[0, 0]
    var neswStones = board[board_size - 1, 0]

    @parameter
    for a in range(1, 5):
        nwseStones += board[a, a]
        neswStones += board[board_size - 1 - a, a]

    for b in range(board_size - 5):
        nwseStones += board[b + 5, b + 5]
        neswStones += board[board_size - 6 - b, b + 5]

        var nwseScore = calc_score(nwseStones)
        var neswScore = calc_score(neswStones)

        @parameter
        for c in range(6):
            scores[b + c, b + c] += nwseScore
            scores[board_size - 1 - b - c, b + c] += neswScore
        nwseStones -= board[b, b]
        neswStones -= board[board_size - 1 - b, b]


fn calc_score(stones: Stone) -> Int32:
    if stones == 0x00:
        return 1
    elif stones == 0x01 or stones == 0x10:
        return 4
    elif stones == 0x02 or stones == 0x20:
        return 16
    elif stones == 0x03 or stones == 0x30:
        return 64
    elif stones == 0x04 or stones == 0x40:
        return 256
    elif stones == 0x05 or stones == 0x50:
        return 1024
    else:
        return 0


fn calc_delta(stones: Stone, stone: Stone) -> (Int, Stone):
    if stone == Stone.black:
        if stones == 0x00:
            return (3, Stone.none)
        elif stones == 0x01:
            return (12, Stone.none)
        elif stones == 0x02:
            return (48, Stone.none)
        elif stones == 0x03:
            return (192, Stone.none)
        elif stones == 0x04:
            return (768, Stone.none)
        elif stones == 0x05:
            print("Black wins: stone =", stone, "stones = ", stones)
            return (0, Stone.black)
        elif stones == 0x10:
            return (-4, Stone.none)
        elif stones == 0x20:
            return (-16, Stone.none)
        elif stones == 0x30:
            return (-64, Stone.none)
        elif stones == 0x40:
            return (-256, Stone.none)
        elif stones == 0x50:
            return (-1024, Stone.none)
        else:
            return (0, Stone.none)
    else:
        if stones == 0x00:
            return (3, Stone.none)
        elif stones == 0x01:
            return (-4, Stone.none)
        elif stones == 0x02:
            return (-16, Stone.none)
        elif stones == 0x03:
            return (-64, Stone.none)
        elif stones == 0x04:
            return (-256, Stone.none)
        elif stones == 0x05:
            return (-1024, Stone.none)
        elif stones == 0x10:
            return (12, Stone.none)
        elif stones == 0x20:
            return (48, Stone.none)
        elif stones == 0x30:
            return (192, Stone.none)
        elif stones == 0x40:
            return (768, Stone.none)
        elif stones == 0x50:
            print("White wins: stone =", stone, "stones = ", stones)
            return (0, Stone.white)
        else:
            return (0, Stone.none)


fn pad(t: String, width: Int) -> String:
    var r = str(" ") * width + t
    return r[len(r) - width :]


@value
struct SearchTree:
    ...
