package board

import (
	"bytes"
	"fmt"
	"testing"

	. "monte/common"
	"monte/heap"
)

type testPlace struct {
	x, y int
	turn Turn
}

func TestPlaceStone(t *testing.T) {
	b := MakeBoard()
	// fmt.Printf("%#v\n", &b)
	b.PlaceStone(First, 9, 9)
	b.PlaceStone(Second, 8, 8)
	b.PlaceStone(Second, 8, 10)
	buf := &bytes.Buffer{}
	b.debugScoresString(buf)
	fmt.Println(buf)
}

func TestPlaceStones(t *testing.T) {
	b := MakeBoard()
	b.PlaceStone(First, 9, 9)
	b.PlaceStone(Second, 8, 8)
	b.PlaceStone(Second, 8, 10)
	turn := First
	m := map[int]int{}
outer:
	for {
		for range 2 {
			x, y, _ := b.BestPlace(turn)
			fmt.Printf("place %v [%d:%d]\n", turn, x, y)
			if b.PlaceStone(turn, x, y) {
				break outer
			}
			board := b.Copy()
			ro := int(board.Rollout(turn, 2))
			m[ro]++
		}
		if turn == First {
			turn = Second
		} else {
			turn = First
		}
	}
	t.Logf("%#v\n", &b)
	t.Logf("%v\n", m)
}

func TestTopPlaces(t *testing.T) {
	places := make([]Place, 0, 30)
	board := MakeBoard()
	board.PlaceStone(First, 9, 9)
	board.PlaceStone(Second, 8, 8)
	board.PlaceStone(Second, 8, 10)
	board.TopPlaces(&places)
	heap.Validate(&places)
	m := map[Score]int{}
	for _, place := range places {
		m[place.Score] += 1
	}
	if m[175] != 1 || m[121] != 2 {
		t.Fail()
	}
	fmt.Println(m)
}

func TestRollout(t *testing.T) {
	board := MakeBoard()
	board.PlaceStone(First, 9, 9)
	board.PlaceStone(Second, 8, 8)
	board.PlaceStone(Second, 8, 10)
	b := board.Copy()
	fmt.Println(b.Rollout(First, 2))
	fmt.Printf("%#v\n", &board)

	board2 := MakeBoard()
	board2.PlaceStone(First, 9, 9)
	board2.PlaceStone(Second, 8, 8)
	board2.PlaceStone(Second, 8, 10)
	if board != board2 {
		t.Fail()
	}
}

func BenchmarkCopyBoard(b *testing.B) {
	board := MakeBoard()
	b.ResetTimer()
	for range b.N {
		board2 := board
		board = board2
	}
}

func BenchmarkRollout(b *testing.B) {
	board := MakeBoard()
	b.ResetTimer()
	for range b.N {
		copy := board.Copy()
		copy.Rollout(First, 2)
	}
}
func BenchmarkBestPlace(b *testing.B) {
	board := MakeBoard()
	b.ResetTimer()
	for range b.N {
		board.BestPlace(First)
	}
}
