package connect6

import (
	"errors"
	"fmt"
	"math/rand"
	"monte/board"
	"monte/heap"
	"strings"
)

const maxPlaces = 20
const maxMoves = 60

type Move struct {
	x1, y1, x2, y2 byte
	winner         board.Stone
	score          board.Score // TODO added for testing
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

func (m Move) GoString() string {
	return fmt.Sprintf("%s, winner: %v, score: %d", m.String(), m.winner, m.score)
}

type Connect6 struct {
	turn     board.Stone
	board    board.Board
	places   []board.Place
	moveHeap []moveScore
}

func MakeGame() Connect6 {
	game := Connect6{
		turn:     board.Black,
		board:    board.MakeBoard(),
		places:   make([]board.Place, 0, maxPlaces),
		moveHeap: make([]moveScore, 0, maxMoves),
	}
	return game
}

func makeMove(x1, y1, x2, y2 int, winner board.Stone, score board.Score) Move {
	if x1 > x2 || x1 == x2 && y1 < y2 {
		return Move{byte(x2), byte(y2), byte(x1), byte(y1), winner, score}
	}
	return Move{byte(x1), byte(y1), byte(x2), byte(y2), winner, score}
}

func MakeMove(x1, y1, x2, y2 int) Move {
	if x1 > x2 || x1 == x2 && y1 < y2 {
		return Move{byte(x2), byte(y2), byte(x1), byte(y1), board.None, 0}
	}
	return Move{byte(x1), byte(y1), byte(x2), byte(y2), board.None, 0}
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

type moveScore struct {
	move  Move
	score board.Score
}

func (ms moveScore) Less(other moveScore) bool {
	return ms.score < other.score
}

func (c *Connect6) TopMoves(moves *[]Move) {
	drawMove := Move{}
	nZeros := 0
	c.board.TopPlaces(&c.places)

	c.moveHeap = c.moveHeap[:0]
	for i, place1 := range c.places {
		if place1.Winner != board.None {
			(*moves)[0] = makeMove(place1.X, place1.Y, place1.X, place1.Y, place1.Winner, place1.Score)
			*moves = (*moves)[:1]
			return
		}
		if place1.Score == 0 {
			switch nZeros {
			case 0:
				drawMove.x1 = byte(place1.X)
				drawMove.y1 = byte(place1.Y)
			case 1:
				drawMove.x2 = byte(place1.X)
				drawMove.y2 = byte(place1.Y)
			}
			nZeros++
			continue
		}

		for _, place2 := range c.places[i+1:] {
			if place2.Winner != board.None {
				(*moves)[0] = makeMove(place1.X, place1.Y, place2.X, place2.Y, place2.Winner, place1.Score+place2.Score)
				*moves = (*moves)[:1]
				return
			}
			heap.Add(&c.moveHeap, moveScore{
				move:  makeMove(place1.X, place1.Y, place2.X, place2.Y, board.None, place1.Score+place2.Score),
				score: place1.Score + place2.Score})
		}
	}

	*moves = (*moves)[:len(c.moveHeap)]
	for i := range c.moveHeap {
		(*moves)[i] = c.moveHeap[i].move
	}

	if len(*moves) == 0 {
		*moves = append(*moves, drawMove)
	}
}

func (c *Connect6) Rollout(rnd *rand.Rand) float32 {
	return c.board.Rollout(c.turn, 2)
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
