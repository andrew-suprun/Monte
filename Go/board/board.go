package board

import (
	"bytes"
	"errors"
	"fmt"

	. "monte/common"
	"monte/heap"
)

type Board struct {
	stones [Size][Size]Stone
	scores [Size][Size]Score
}

type Place struct {
	X, Y  int8
	Score Score
}

type (
	Stone byte
	Score int16
)

const (
	None  Stone = 0x00
	Black Stone = 0x01
	White Stone = 0x10
)

func (place Place) Less(other Place) bool {
	return place.Score < other.Score
}

func (stone Stone) String() string {
	switch stone {
	case Black:
		return "Black"
	case White:
		return "White"
	}
	return "None"
}

const maxStones1 = maxStones - 1

func MakeBoard() Board {
	board := Board{}
	for y := 0; y < Size; y++ {
		v := 1 + min(maxStones1, y, Size-1-y)
		for x := 0; x < Size; x++ {
			h := 1 + min(maxStones1, x, Size-1-x)
			m := 1 + min(x, y, Size-1-x, Size-1-y)
			t1 := max(0, min(maxStones, m, Size-maxStones1-y+x, Size-maxStones1-x+y))
			t2 := max(0, min(maxStones, m, 2*Size-1-maxStones1-y-x, x+y-maxStones1+1))
			total := Score(v + h + t1 + t2)
			board.scores[y][x] = total
		}
	}
	return board
}

func (b *Board) Score(x, y int8) int16 {
	return int16(b.scores[y][x])
}

func (b *Board) TopPlaces(places *[]Place) {
	*places = (*places)[:0]
	for y := int8(0); y < Size; y++ {
		for x := int8(0); x < Size; x++ {
			if b.stones[y][x] != None {
				continue
			}
			heap.Add(places, Place{x, y, b.scores[y][x]})
		}
	}
}

func (b *Board) PlaceStone(turn Turn, x, y int) bool {
	{
		start := max(0, x-maxStones1)
		end := min(x+maxStones, Size) - maxStones1
		n := end - start
		if b.updateRow(turn, start, y, 1, 0, n) {
			return true
		}
	}

	{
		start := max(0, y-maxStones1)
		end := min(y+maxStones, Size) - maxStones1
		n := end - start
		if b.updateRow(turn, x, start, 0, 1, n) {
			return true
		}
	}

	m := 1 + min(x, y, Size-1-x, Size-1-y)

	{
		n := min(maxStones, m, Size-maxStones1-y+x, Size-maxStones1-x+y)
		if n > 0 {
			mn := min(x, y, maxStones1)
			xStart := x - mn
			yStart := y - mn
			if b.updateRow(turn, xStart, yStart, 1, 1, n) {
				return true
			}
		}
	}

	{
		n := min(maxStones, m, 2*Size-1-maxStones1-y-x, x+y-maxStones1+1)
		if n > 0 {
			mn := min(Size-1-x, y, maxStones1)
			xStart := x + mn
			yStart := y - mn
			if b.updateRow(turn, xStart, yStart, -1, 1, n) {
				return true
			}
		}
	}

	if turn == First {
		b.stones[y][x] = Black
	} else {
		b.stones[y][x] = White
	}
	b.validate()
	return false
}

func (b *Board) updateRow(turn Turn, x, y, dx, dy, n int) bool {
	stones := Stone(0)
	for i := 0; i < maxStones1; i++ {
		stones += b.stones[y+i*dy][x+i*dx]
	}
	for range n {
		stones += b.stones[y+maxStones1*dy][x+maxStones1*dx]

		if turn == First && stones == maxStones1 || turn == Second && stones == maxStones1*White {
			return true
		}
		score := scoreStones(turn, stones)
		if score != 0 {
			for j := 0; j < maxStones; j++ {
				b.scores[y+j*dy][x+j*dx] += score
			}
		}
		stones -= b.stones[y][x]
		x += dx
		y += dy
	}
	return false
}

func (b *Board) Copy() *Board {
	board := *b
	return &board
}

func (b *Board) Rollout(turn Turn, stonesPerMove int) Value {
	roTurn := turn
	n := 1
	for {
		for range stonesPerMove {
			if n > 100 {
				return 0
			}
			n++
			x, y, score := b.BestPlace(roTurn)
			if score == 0 {
				return 0
			}
			winner := b.PlaceStone(roTurn, x, y)
			fmt.Printf("place %d: %v %c%d%v\n", n, roTurn, x+'a', y+1, b)
			if winner {
				if turn == roTurn {
					return 1
				} else {
					return -1
				}
			}
		}
		if roTurn == First {
			roTurn = Second
		} else {
			roTurn = First
		}
	}
}

func (b *Board) BestPlace(turn Turn) (int, int, Score) {
	xx, yy, bestScore := 0, 0, Score(0)
	for y := range Size {
		for x := range Size {
			if b.stones[y][x] != None {
				continue
			}
			score := b.scores[y][x]
			if score > bestScore {
				xx, yy, bestScore = x, y, score
			}
		}
	}
	return xx, yy, bestScore
}

func (b *Board) String() string {
	buf := &bytes.Buffer{}
	b.BoardString(buf)
	return buf.String()
}

func (b *Board) GoString() string {
	buf := &bytes.Buffer{}
	b.BoardString(buf)
	b.ScoresString(buf)
	return buf.String()
}

func (b *Board) BoardString(buf *bytes.Buffer) {
	buf.WriteString("\n  ")

	for i := range Size {
		fmt.Fprintf(buf, " %c", i+'a')
	}
	buf.WriteByte('\n')

	for y := range Size {
		fmt.Fprintf(buf, "%2d", y+1)
		for x := range Size {
			switch b.stones[y][x] {
			case Black:
				if x == 0 {
					buf.WriteString(" X")
				} else {
					buf.WriteString("─X")
				}
			case White:
				if x == 0 {
					buf.WriteString(" O")
				} else {
					buf.WriteString("─O")
				}
			default:
				switch y {
				case 0:
					switch x {
					case 0:
						buf.WriteString(" ┌")
					case Size - 1:
						buf.WriteString("─┐")
					default:
						buf.WriteString("─┬")
					}
				case Size - 1:
					switch x {
					case 0:
						buf.WriteString(" └")
					case Size - 1:
						buf.WriteString("─┘")
					default:
						buf.WriteString("─┴")
					}
				default:
					switch x {
					case 0:
						buf.WriteString(" ├")
					case Size - 1:
						buf.WriteString("─┤")
					default:
						buf.WriteString("─┼")
					}
				}
			}
		}
		fmt.Fprintf(buf, " %2d\n", y+1)
	}

	buf.WriteString("  ")

	for i := range Size {
		fmt.Fprintf(buf, " %c", i+'a')
	}
	buf.WriteByte('\n')
}

func (b *Board) ScoresString(buf *bytes.Buffer) {
	buf.WriteString("\n      │")

	for i := range Size {
		fmt.Fprintf(buf, " %c %2d │", i+'a', i)
	}
	buf.WriteString("\n")

	for range Size {
		fmt.Fprintf(buf, "──────┼")
	}
	fmt.Fprintln(buf, "──────┤")
	for y := 0; y < Size; y++ {
		fmt.Fprintf(buf, "%2d %2d │", Size-y, y)

		for x := 0; x < Size; x++ {
			switch b.stones[y][x] {
			case None:
				fmt.Fprintf(buf, "%5d │", b.scores[y][x])
			case Black:
				buf.WriteString("    X │")
			case White:
				buf.WriteString("    O │")
			}
		}

		buf.WriteByte('\n')
	}
	for range Size {
		fmt.Fprintf(buf, "──────┼")
	}
	fmt.Fprintln(buf, "──────┤")
	buf.WriteString("      │")

	for i := range Size {
		fmt.Fprintf(buf, " %c %2d │", i+'a', i)
	}
	buf.WriteString("\n")
}

func ParsePlace(place string) (int8, int8, error) {
	if len(place) < 2 || len(place) > 3 {
		return 0, 0, errors.New("failed to parse place")
	}
	if place[0] < 'a' || place[0] > 's' {
		return 0, 0, errors.New("failed to parse place")
	}
	if place[1] < '0' || place[1] > '9' {
		return 0, 0, errors.New("failed to parse place")
	}
	x := int8(place[0] - 'a')
	y := int8(place[1] - '0')
	if len(place) == 3 {
		if place[2] < '0' || place[2] > '9' {
			return 0, 0, errors.New("failed to parse place")
		}
		y = 10*y + int8(place[2]-'0')
	}
	y -= 1
	if x >= Size || y >= Size {
		return 0, 0, errors.New("failed to parse place")
	}
	return x, y, nil
}
