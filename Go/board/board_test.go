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
}

func TestRollout(t *testing.T) {
	board := MakeBoard()
	board.PlaceStone(Black, 9, 9)
	board.PlaceStone(White, 9, 10)
	board.PlaceStone(White, 10, 2)
	fmt.Println(board.Rollout(Black, 2))
	fmt.Printf("%#v\n", &board)

	board2 := MakeBoard()
	board2.PlaceStone(Black, 9, 9)
	board2.PlaceStone(White, 8, 8)
	board2.PlaceStone(White, 8, 10)
	if board != board2 {
		t.Fail()
	}
}

func BenchmarkRollout(b *testing.B) {
	board := MakeBoard()
	board.PlaceStone(Black, 9, 9)
	board.PlaceStone(White, 8, 8)
	board.PlaceStone(White, 8, 10)

	for range b.N {
		board.Rollout(Black, 2)
	}
}
