package board

import (
	"bytes"
	"fmt"
	"monte/score"
)

func (b *Board) validate() {
	failed := false
	for y := 0; y < Size; y++ {
		for x := 0; x < Size; x++ {
			rate := b.rateStone(x, y)
			if b.stones[y][x] == None && b.scores[y][x] != rate {
				fmt.Printf("x: %d y: %d expected: %v got: %v\n", x, y, rate, b.scores[y][x])
				failed = true
			}
		}
	}
	if failed {
		fmt.Printf("Expected:\n")
		buf := &bytes.Buffer{}
		b.debugScoresString(buf)
		fmt.Println(buf)
		fmt.Printf("Got:\n%#v", b)
		panic("### Validation ###")
	}
}

func (b *Board) rateStone(x, y int) (result score.Score) {
	{
		start := max(0, x-maxStones1)
		end := min(x+maxStones, Size) - maxStones1
		n := end - start
		result += b.rateRow(start, y, 1, 0, n)
	}

	{
		start := max(0, y-maxStones1)
		end := min(y+maxStones, Size) - maxStones1
		n := end - start
		result += b.rateRow(x, start, 0, 1, n)
	}

	m := 1 + min(x, y, Size-1-x, Size-1-y)

	{
		n := min(maxStones, m, Size-maxStones1-y+x, Size-maxStones1-x+y)
		if n > 0 {
			mn := min(x, y, maxStones1)
			xStart := x - mn
			yStart := y - mn
			result += b.rateRow(xStart, yStart, 1, 1, n)
		}
	}

	{
		n := min(maxStones, m, 2*Size-1-maxStones1-y-x, x+y-maxStones1+1)
		if n > 0 {
			mn := min(Size-1-x, y, maxStones1)
			xStart := x + mn
			yStart := y - mn
			result += b.rateRow(xStart, yStart, -1, 1, n)
		}
	}

	return result
}

func (b *Board) rateRow(x, y, dx, dy, n int) (result score.Score) {
	stones := Stone(0)
	for i := 0; i < maxStones1; i++ {
		stones += b.stones[y+i*dy][x+i*dx]
	}
	for range n {
		stones += b.stones[y+maxStones1*dy][x+maxStones1*dx]
		score := debugScoreStones(stones)
		result += score
		stones -= b.stones[y][x]
		x += dx
		y += dy
	}
	return result
}

func debugScoreStones(stones Stone) score.Score {
	switch stones {
	case 0x00:
		return 1
	case 0x01, 0x10:
		return 6
	case 0x02, 0x20:
		return 30
	case 0x03, 0x30:
		return 120
	case 0x04, 0x40:
		return 360
	case 0x05, 0x50:
		return 10360
	}
	return 0
}

func (b *Board) debugScoresString(buf *bytes.Buffer) {
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
				rate := b.rateStone(x, y)
				switch rate.State() {
				case score.Nonterminal:
					fmt.Fprintf(buf, "%5d", rate)
				case score.Win:
					fmt.Fprintf(buf, "  Win")
				case score.Draw:
					fmt.Fprintf(buf, " Draw")
				}
				if rate != b.scores[y][x] {
					fmt.Fprint(buf, "#|")
				} else {
					fmt.Fprint(buf, " |")
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
