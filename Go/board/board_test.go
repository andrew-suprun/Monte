package board

import (
	"bytes"
	"fmt"
	"math/rand"
	"monte/heap"
	"testing"
)

type testPlace struct {
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
	places := []testPlace{}
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
		places = append(places, testPlace{x, y, stone})
		b.PlaceStone(stone, x, y)
	}
	t.Logf("%#v\n", &b)
}

func TestTopPlaces(t *testing.T) {
	places := make([]Place, 0, 30)
	board := MakeBoard()
	board.PlaceStone(Black, 9, 9)
	board.PlaceStone(White, 8, 8)
	board.PlaceStone(White, 8, 10)
	board.TopPlaces(&places)
	heap.Validate(&places)
	m := map[Score]int{}
	for _, place := range places {
		m[place.Score] = m[place.Score] + 1
	}
	if m[175] != 1 || m[121] != 2 {
		t.Fail()
	}
	fmt.Println(m)
}

func TestRollout(t *testing.T) {
	board := MakeBoard()
	board.PlaceStone(Black, 9, 9)
	board.PlaceStone(White, 8, 8)
	board.PlaceStone(White, 8, 10)
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
