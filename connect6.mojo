from utils.static_tuple import InlineArray
from collections import Optional
from sys import exit


@value
@register_passable("trivial")
struct Stone:
    var stone: Int8

    alias none: Int8 = 0x00
    alias black: Int8 = 0x01
    alias white: Int8 = 0x10

    fn __eq__(self, other: Self) -> Bool:
        return self.stone == other.stone

    fn __ne__(self, other: Self) -> Bool:
        return self.stone != other.stone

    fn __iadd__(inout self, other: Self):
        self.stone += other.stone

    fn __isub__(inout self, other: Self):
        self.stone -= other.stone

    fn __str__(self) -> String:
        if self.stone == Self.none:
            return "."
        elif self.stone == Self.black:
            return "X"
        else:
            return "O"


@value
@register_passable("trivial")
struct Move:
    var x: Int8
    var y: Int8


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

    fn make_move(inout self, move: Move) -> Optional[Stone]:
        var result = self.place_stone(move)
        if debug and result is None:
            self.check_scores()
        return result

    fn place_stone(inout self, move: Move) -> Optional[Stone]:
        var stone = self.next_stone()
        if debug:
            print(
                "place", stone, "at", move.x, move.y, "score", self.scores[move]
            )
            self.check_scores()
            print(self)

        var x = int(move.x)
        var y = int(move.y)

        while True:
            var start_x = max(x, 5) - 5
            var end_x = min(x + 1, board_size - 5)
            var stones = self.board[start_x, y]
            for i in range(1, 5):
                stones += self.board[start_x + i, y]
            for dx in range(start_x, end_x):
                stones += self.board[dx + 5, y]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
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
            for i in range(1, 5):
                stones += self.board[x, start_y + i]
            for dy in range(start_y, end_y):
                stones += self.board[x, dy + 5]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
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
            for i in range(1, 5):
                stones += self.board[start_x + i, start_y + i]

            for i in range(count):
                stones += self.board[start_x + i + 5, start_y + i + 5]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
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
            for i in range(1, 5):
                stones += self.board[start_x - i, start_y + i]
            for c in range(count):
                stones += self.board[start_x - 5 - c, start_y + 5 + c]
                var d = calc_delta(stones, stone)
                if d[1] != Stone.none:
                    return d[1]

                @parameter
                for e in range(6):
                    self.scores[start_x - c - e, start_y + c + e] += d[0]
                stones -= self.board[start_x - c, start_y + c]
            break
        return Stone.none

    fn check_scores(self):
        exit(1)

    @always_inline
    fn next_stone(self) -> Stone:
        return Stone.black if ((self.move_number + 3) & 2 == 2) else Stone.white

    fn __str__(self) -> String:
        var result = String(" yx|")
        for i in range(board_size):
            result += pad(str(i), 4)
        result += " |\n---+" + str("----") * board_size + "-+---\n"
        for y in range(board_size):
            result += pad(str(y), 2) + " |"
            for x in range(board_size):
                if self.board[x, y] == Stone.none:
                    result += pad(str(self.scores[x, y]), 4)
                else:
                    result += pad(str(self.board[x, y]), 4)
            result += " | " + pad(str(y), 2) + "\n"
        result += "---+" + str("----") * board_size + "-+---\n   |"
        for i in range(board_size):
            result += pad(str(i), 4)
        result += " |\n"

        return result


fn calc_delta(stones: Stone, stone: Stone) -> (Int, Stone):
    ...


fn pad(t: String, width: Int) -> String:
    var r = str(" ") * width + t
    return r[len(r) - width :]


@value
struct SearchTree:
    pass
