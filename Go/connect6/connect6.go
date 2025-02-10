package connect6

import (
	"errors"
	"fmt"
	"strings"

	"monte/board"
	. "monte/common"
	"monte/heap"
)

type Move struct {
	x1, y1, x2, y2 int8
}

func (m Move) Equal(other Move) bool {
	return m.x1 == other.x1 && m.y1 == other.y1 && m.x2 == other.x2 && m.y2 == other.y2 ||
		m.x1 == other.x2 && m.y1 == other.y2 && m.x2 == other.x1 && m.y2 == other.y1
}

func (m Move) String() string {
	x1, y1, x2, y2 := m.x1, m.y1, m.x2, m.y2
	if x1 > x2 || x1 == x2 && y1 < y2 {
		x1, y1, x2, y2 = x2, y2, x1, y1
	}
	return fmt.Sprintf("%c%d-%c%d", x1+'a', y1+1, x2+'a', y2+1)
}

type Connect6 struct {
	turn   Turn
	places []board.Place
}

func MakeGame(maxPlaces int) Connect6 {
	game := Connect6{
		turn:   First,
		places: make([]board.Place, 0, maxPlaces),
	}
	return game
}

func ExpFactor() float64 {
	return 1
}

func ParseMove(moveStr string) (Move, error) {
	tokens := strings.Split(moveStr, "-")
	x1, y1, err := board.ParsePlace(tokens[0])
	if err != nil {
		return Move{}, errors.New("failed to parse move")
	}

	if len(tokens) == 1 {
		return Move{x1, y1, x1, y1}, nil
	}
	x2, y2, err := board.ParsePlace(tokens[1])
	if err != nil {
		return Move{}, errors.New("failed to parse move")
	}

	return Move{x1, y1, x2, y2}, nil
}

func (c *Connect6) PlayMove(board *board.Board, move Move) bool {
	if board.PlaceStone(c.turn, int(move.x1), int(move.y1)) {
		return true
	}
	if move.x1 != move.x2 || move.y1 != move.y2 {
		if board.PlaceStone(c.turn, int(move.x2), int(move.y2)) {
			return true
		}
	}
	if c.turn == First {
		c.turn = Second
	} else {
		c.turn = First
	}
	return false
}

func (c *Connect6) TopMoves(board *board.Board, moves *[]MoveValue[Move]) {
	*moves = (*moves)[:0]
	drawMove := Move{}
	hasDraw := false

	board.TopPlaces(&c.places)

	for i, place1 := range c.places {
		score1 := board.Score(place1.X, place1.Y)
		for _, place2 := range c.places[i+1:] {
			score := score1 + board.Score(place2.X, place2.Y)
			if score == 0 {
				if !hasDraw {
					drawMove = Move{place1.X, place1.Y, place2.X, place2.Y}
					hasDraw = true
				}
				continue
			}

			heap.Add(moves, MoveValue[Move]{
				Move:  Move{place1.X, place1.Y, place2.X, place2.Y},
				Value: Value(score)})
		}
	}
	for i := range *moves {
		(*moves)[i].Value = c.rollout(board, (*moves)[i].Move)
	}

	if len(*moves) == 0 {
		*moves = append(*moves, MoveValue[Move]{Move: drawMove, Value: Draw})
	}
}

func (c *Connect6) rollout(board *board.Board, move Move) Value {
	copy := board.Copy()
	if c.PlayMove(copy, move) {
		return Win
	}
	return -copy.Rollout(c.turn, 2)
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
	return Move{x1, y1, x2, y2}, nil
}
