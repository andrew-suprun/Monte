package connect6

import (
	"errors"
	"fmt"
	"math/rand"
	"monte/board"
	"strings"
)

type Move struct {
	x1, y1, x2, y2 byte
	winner         board.Stone
}

func (m Move) Winner() bool {
	return m.winner != board.None
}

func (m Move) String() string {
	x1, y1, x2, y2 := m.x1, m.y1, m.x2, m.y2
	if x1 > x2 || x1 == x2 && y1 < y2 {
		x1, y1, x2, y2 = x2, y2, x1, y1
	}
	return fmt.Sprintf("%c%d-%c%d", x1+'a', board.Size-y1, x2+'a', board.Size-y2)
}

type Connect6 struct {
	turn  board.Stone
	board board.Board
}

func NewGame() *Connect6 {
	game := &Connect6{
		turn:  board.Black,
		board: board.MakeBoard(),
	}
	return game
}

func makeMove(x1, y1, x2, y2 int, winner board.Stone) Move {
	if x1 > x2 || x1 == x2 && y1 < y2 {
		return Move{byte(x2), byte(y2), byte(x1), byte(y1), winner}
	}
	return Move{byte(x1), byte(y1), byte(x2), byte(y2), winner}
}

func MakeMove(x1, y1, x2, y2 int) Move {
	if x1 > x2 || x1 == x2 && y1 < y2 {
		return Move{byte(x2), byte(y2), byte(x1), byte(y1), board.None}
	}
	return Move{byte(x1), byte(y1), byte(x2), byte(y2), board.None}
}

func (c *Connect6) PlayMove(move Move) {
	c.board.PlaceStone(c.turn, int(move.x1), int(move.y1))
	if move.x1 != move.x2 || move.y1 != move.y2 {
		c.board.PlaceStone(c.turn, int(move.x2), int(move.y2))
	}
	if c.turn == board.Black {
		c.turn = board.White
	} else {
		c.turn = board.Black
	}
}

func (c *Connect6) PossibleMoves(moves *[]Move) {
	drawMove := Move{}
	nZeros := 0
	*moves = (*moves)[:0]

	for y1 := 0; y1 < board.Size; y1++ {
		for x1 := 0; x1 < board.Size; x1++ {
			if c.board.Stone(x1, y1) != board.None {
				continue
			}

			score1, winner1 := c.board.Score(c.turn, x1, y1)
			if score1 == 0 {
				switch nZeros {
				case 0:
					drawMove.x1 = byte(x1)
					drawMove.y1 = byte(y1)
				case 1:
					drawMove.x2 = byte(x1)
					drawMove.y2 = byte(y1)
				}
				nZeros++
				continue
			}

			if winner1 != board.None {
				(*moves)[0] = MakeMove(x1, y1, x1, y1)
				*moves = (*moves)[:1]
				return
			}

			for y2 := y1; y2 < board.Size; y2++ {
				x2 := 0
				if y1 == y2 {
					x2 = x1 + 1
				}
				for ; x2 < board.Size; x2++ {
					if c.board.Stone(x2, y2) != board.None {
						continue
					}
					score2, winner2 := c.board.Score(c.turn, x2, y2)
					if score2 == 0 {
						continue
					}
					if winner2 != board.None {
						(*moves)[0] = makeMove(x1, y1, x2, y2, winner2)
						*moves = (*moves)[:1]
						return
					}
					*moves = append(*moves, makeMove(x1, y1, x2, y2, board.None))
				}
			}
		}
	}

	if len(*moves) == 0 {
		*moves = append(*moves, drawMove)
	}
}

func (c *Connect6) Rollout(rnd *rand.Rand) float32 {
	n := 0
	for {
		for range 2 {
			x, y, score, winner := c.board.BestPlace(c.turn, rnd)
			if winner {
				fmt.Printf("-- BestPlace: %v %c%d score %d winner %v\n", c.turn, x+'a', board.Size-y, score, winner)
				if c.turn == board.Black {
					// fmt.Println("Winner: Black", "N", n)
					return 1
				} else {
					// fmt.Println("Winner: White", "N", n)
					return -1
				}
			} else if score == 0 {
				// fmt.Println("Draw: N", n)
				return 0
			}
			c.board.PlaceStone(c.turn, x, y)
			// fmt.Printf("Stone %v %c%d\n", c.turn, x+'a', board.Size-y)
			// fmt.Println(&c.board)
			n++
		}
		if c.turn == board.Black {
			c.turn = board.White
		} else {
			c.turn = board.Black
		}
	}
}

func (c *Connect6) ParseMove(moveStr string) (Move, error) {
	tokens := strings.Split(moveStr, "-")
	x1, y1, err := board.ParsePlace(tokens[0])
	if err != nil {
		return Move{}, errors.New("failed to parse move")
	}
	x2, y2 := x1, y1
	if len(tokens) > 1 {
		x2, y2, err = board.ParsePlace(tokens[1])
	}
	if err != nil {
		return Move{}, errors.New("failed to parse move")
	}
	return MakeMove(x1, y1, x2, y2), nil
}

// func (c *Connect6) SameMove(a, b Move) bool {
// 	return a.x1 == b.x1 && a.y1 == b.y1 && a.x2 == b.x2 && a.y2 == b.y2 ||
// 		a.x1 == b.x2 && a.y1 == b.y2 && a.x2 == b.x1 && a.y2 == b.y1
// }
