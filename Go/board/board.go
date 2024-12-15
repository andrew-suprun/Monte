package board

import (
	"bytes"
	"errors"
	"fmt"
	"math/rand"
)

type (
	Stone  byte
	Winner byte
	Score  int32
)

func (score Score) IsDrawing() bool {
	return score == 0
}

const (
	None  Stone = 0x00
	Black Stone = 0x01
	White Stone = 0x10
)

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

type Board struct {
	stones  [Size][Size]Stone
	winners [Size][Size]Stone
	scores  [Size][Size]Score
}

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

func (b *Board) IsWinning(turn Stone, x, y int) bool {
	return b.winners[y][x] == turn
}

func (b *Board) IsDrawing(turn Stone, x, y int) bool {
	return b.winners[y][x] == 0
}

func (b *Board) PlaceStone(stone Stone, x, y int) {
	{
		start := max(0, x-maxStones1)
		end := min(x+maxStones, Size) - maxStones1
		n := end - start
		b.updateRow(stone, start, y, 1, 0, n)
	}

	{
		start := max(0, y-maxStones1)
		end := min(y+maxStones, Size) - maxStones1
		n := end - start
		b.updateRow(stone, x, start, 0, 1, n)
	}

	m := 1 + min(x, y, Size-1-x, Size-1-y)

	{
		n := min(maxStones, m, Size-maxStones1-y+x, Size-maxStones1-x+y)
		if n > 0 {
			mn := min(x, y, maxStones1)
			xStart := x - mn
			yStart := y - mn
			b.updateRow(stone, xStart, yStart, 1, 1, n)
		}
	}

	{
		n := min(maxStones, m, 2*Size-1-maxStones1-y-x, x+y-maxStones1+1)
		if n > 0 {
			mn := min(Size-1-x, y, maxStones1)
			xStart := x + mn
			yStart := y - mn
			b.updateRow(stone, xStart, yStart, -1, 1, n)
		}
	}

	b.stones[y][x] = stone
	b.validate()
}

func (b *Board) updateRow(stone Stone, x, y, dx, dy, n int) {
	// fmt.Printf("updateRow: %v [%d:%d] [%d:%d] n: %d\n", stone, x, y, dx, dy, n)
	stones := Stone(0)
	for i := 0; i < maxStones1; i++ {
		stones += b.stones[y+i*dy][x+i*dx]
	}
	for range n {
		stones += b.stones[y+maxStones1*dy][x+maxStones1*dx]
		score, winner := scoreStones(stone, stones)
		// if winner != None {
		// 	fmt.Printf("updateRow.Winner %v %c%d stones: %2x  score: %d\n", winner, x+'a', Size-y, byte(stones), score)
		// }
		if score != 0 {
			for j := 0; j < maxStones; j++ {
				b.scores[y+j*dy][x+j*dx] += score
				b.winners[y+j*dy][x+j*dx] |= winner
				// if winner != None {
				// 	fmt.Printf("    %v: %c%d stones: %2x  score: %d\n", winner, (x+j*dx)+'a', Size-(y+j*dy), byte(stones), score)
				// }
			}
		}
		stones -= b.stones[y][x]
		x += dx
		y += dy
	}
}

func (b *Board) BestPlace(turn Stone, rnd *rand.Rand) (int, int, Score, bool) {
	xx, yy, bestScore := 0, 0, Score(0)
	prob := 2
	for y := range Size {
		for x := range Size {
			if b.stones[y][x] != None {
				continue
			}
			if b.winners[y][x] == turn {
				// fmt.Printf("BestPlace Winner %v: %c%d Score: %d\n", turn, x+'a', Size-y, b.scores[y][x])
				return x, y, b.scores[y][x], true
			}
			score := b.scores[y][x]
			if score > bestScore {
				// fmt.Printf("bp1: old %c%d new %c%d: score %d, best %d\n", xx+'a', Size-yy, x+'a', Size-y, score, bestScore)
				xx, yy, bestScore = x, y, score
				prob = 2
			} else if score == bestScore {
				if rnd.Intn(prob) == 0 {
					// fmt.Printf("bp2: old %c%d new %c%d: score %d, prob %v\n", xx+'a', Size-yy, x+'a', Size-y, score, prob)
					xx, yy = x, y
					prob++
					// } else {
					// 	fmt.Printf("bp2: old %c%d new %c%d: score %d, prob %v\n", xx+'a', Size-yy, x+'a', Size-y, score, prob)
				}
			}
		}
	}
	// fmt.Printf("BestPlace Score %d: %c%d\n", bestScore, xx+'a', Size-yy)
	return xx, yy, bestScore, false
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
		fmt.Fprintf(buf, "%2d", Size-y)
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
		fmt.Fprintf(buf, " %2d\n", Size-y)
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
				score := b.scores[y][x]
				if score.IsDrawing() {
					fmt.Fprintf(buf, "  (D) │")
				} else if b.IsWinning(Black, x, y) {
					fmt.Fprintf(buf, "  (B) │")
				} else if b.IsWinning(White, x, y) {
					fmt.Fprintf(buf, "  (W) │")
				} else {
					fmt.Fprintf(buf, "%5d │", b.scores[y][x])
				}
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

func ParsePlace(place string) (int, int, error) {
	if len(place) < 2 || len(place) > 3 {
		return 0, 0, errors.New("failed to parse place")
	}
	if place[0] < 'a' || place[0] > 's' {
		return 0, 0, errors.New("failed to parse place")
	}
	if place[1] < '0' || place[1] > '9' {
		return 0, 0, errors.New("failed to parse place")
	}
	x := place[0] - 'a'
	y := place[1] - '0'
	if len(place) == 3 {
		if place[2] < '0' || place[2] > '9' {
			return 0, 0, errors.New("failed to parse place")
		}
		y = 10*y + place[2] - '0'
	}
	y = Size - y
	if x > Size || y > Size {
		return 0, 0, errors.New("failed to parse place")
	}
	return int(x), int(y), nil
}
