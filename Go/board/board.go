package board

import (
	"bytes"
	"fmt"
)

type (
	Stone byte
	Score int32
)

const (
	None  Stone = 0
	Black Stone = 1
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
	stones [Size][Size]Stone
	scores [Size][Size]Score
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

func (b *Board) PlaceStone(stone Stone, x, y int) {
	b.placeStone(stone, x, y, 1)
}

func (b *Board) RemoveStone(stone Stone, x, y int) {
	b.placeStone(stone, x, y, -1)
}

func (b *Board) placeStone(stone Stone, x, y int, coeff Score) {
	if coeff == -1 {
		b.stones[y][x] = None
	}

	{
		start := max(0, x-maxStones1)
		end := min(x+maxStones, Size) - maxStones1
		n := end - start
		b.updateRow(stone, start, y, 1, 0, n, coeff)
	}

	{
		start := max(0, y-maxStones1)
		end := min(y+maxStones, Size) - maxStones1
		n := end - start
		b.updateRow(stone, x, start, 0, 1, n, coeff)
	}

	m := 1 + min(x, y, Size-1-x, Size-1-y)

	{
		n := min(maxStones, m, Size-maxStones1-y+x, Size-maxStones1-x+y)
		if n > 0 {
			mn := min(x, y, maxStones1)
			xStart := x - mn
			yStart := y - mn
			b.updateRow(stone, xStart, yStart, 1, 1, n, coeff)
		}
	}

	{
		n := min(maxStones, m, 2*Size-1-maxStones1-y-x, x+y-maxStones1+1)
		if n > 0 {
			mn := min(Size-1-x, y, maxStones1)
			xStart := x + mn
			yStart := y - mn
			b.updateRow(stone, xStart, yStart, -1, 1, n, coeff)
		}
	}

	if coeff == 1 {
		b.stones[y][x] = stone
	}
	b.validate()
}

func (b *Board) updateRow(stone Stone, x, y, dx, dy, n int, coeff Score) {
	// fmt.Printf("updateRow: %v [%d:%d] [%d:%d] n: %d\n", stone, x, y, dx, dy, n)
	stones := Stone(0)
	for i := 0; i < maxStones1; i++ {
		stones += b.stones[y+i*dy][x+i*dx]
	}
	for range n {
		stones += b.stones[y+maxStones1*dy][x+maxStones1*dx]
		score := scoreStones(stone, stones)
		if score != 0 {
			score = score * coeff
			for j := 0; j < maxStones; j++ {
				b.scores[y+j*dy][x+j*dx] += score
				// fmt.Printf("    [%d:%d] stones: %2x  score: %d\n", x+j*dx, y+j*dy, byte(stones), score)
			}
		}
		stones -= b.stones[y][x]
		x += dx
		y += dy
	}
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
		fmt.Fprintf(buf, "%2d\n", Size-y)
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
				if score == 0 {
					fmt.Fprintf(buf, "  <D> │")
				} else if score <= -sixStones || score >= sixStones {
					fmt.Fprintf(buf, "  <W> │")
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
