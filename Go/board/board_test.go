package board

import (
	"bytes"
	"fmt"
	"math/rand"
	"testing"
)

type testMove struct {
	x, y  int
	stone Stone
}

func TestRateStone(t *testing.T) {
	b := MakeBoard()
	b.stones[9][9] = Black
	fmt.Printf("Black, 8, 9: %#v\n", b.rateStone(8, 9))
	// b.stones[8][8] = White
	// b.stones[8][10] = White
	fmt.Printf("Black, 0, 0: %#v\n", b.rateStone(0, 0))
	fmt.Printf("%v\n", &b)
	buf := &bytes.Buffer{}
	b.debugScoresString(buf)
	fmt.Println(buf)
}

func TestPlaceStone(t *testing.T) {
	b := MakeBoard()
	// fmt.Printf("%#v\n", &b)
	b.PlaceStone(Black, 9, 9)
	b.PlaceStone(White, 8, 8)
	b.PlaceStone(White, 8, 10)

	// b.PlaceStone(Black, 8, 9)

	buf := &bytes.Buffer{}
	b.debugScoresString(buf)
	fmt.Println(buf)

	// fmt.Printf("%#v\n", &b)
	// fmt.Println("--- White, 8, 9")
	// fmt.Printf("%#v\n", &b)
	// fmt.Println("--- White, 10, 9")
	// b.PlaceStone(White, 10, 9)
	// fmt.Printf("%#v\n", &b)
}

func TestPlaceStones(t *testing.T) {
	rnd := rand.New(rand.NewSource(3))
	moves := []testMove{}
	b := MakeBoard()
	for range 300 {
		x := rnd.Intn(Size)
		y := rnd.Intn(Size)
		if b.stones[y][x] != None {
			continue
		}
		stone := Black
		if rnd.Intn(2) == 0 {
			stone = White
		}
		moves = append(moves, testMove{x, y, stone})
		b.PlaceStone(stone, x, y)
	}
	t.Logf("%#v\n", &b)
}
