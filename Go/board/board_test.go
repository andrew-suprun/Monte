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

func TestPlaceStone(t *testing.T) {
	b := MakeBoard()
	// fmt.Printf("%#v\n", &b)
	b.PlaceStone(Black, 9, 9)
	b.PlaceStone(White, 8, 8)
	b.PlaceStone(White, 8, 10)
	buf := &bytes.Buffer{}
	b.debugScoresString(buf)
	fmt.Println(buf)
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
	for i := len(moves) - 1; i >= 0; i-- {
		b.RemoveStone(moves[i].stone, moves[i].x, moves[i].y)
	}
	t.Logf("%#v\n", &b)
	if MakeBoard() != b {
		t.Fail()
	}
}
