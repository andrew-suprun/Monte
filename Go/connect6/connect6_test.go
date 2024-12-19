package connect6

import (
	"fmt"
	"math/rand"
	"monte/board"
	"sort"
	"testing"
	"time"
)

func TestRollout(t *testing.T) {
	scores := [3]int{}
	game := MakeGame()
	game.PlayMove(MakeMove(9, 9, 9, 9))
	game.PlayMove(MakeMove(0, 0, 1, 0))
	for i := range int64(4) {
		fmt.Println("--- Rollout", i)
		newGame := game
		rnd := rand.New(rand.NewSource(time.Now().UnixNano()))
		rolloutScore := newGame.Rollout(rnd)
		if rolloutScore == -1 {
			scores[0]++
		} else if rolloutScore == 0 {
			scores[1]++
		} else if rolloutScore == 1 {
			scores[2]++
		}
	}
	fmt.Println("scores", scores)
}

type byScore []Move

func (b byScore) Len() int {
	return len(b)
}

func (b byScore) Less(i, j int) bool {
	return b[i].score > b[j].score
}

func (b byScore) Swap(i, j int) {
	b[i], b[j] = b[j], b[i]
}

func TestTopMoves(t *testing.T) {
	moves := make([]Move, 0, maxMoves)
	game := MakeGame()
	game.board.PlaceStone(board.Black, 9, 9)
	game.board.PlaceStone(board.White, 8, 8)
	game.board.PlaceStone(board.White, 8, 10)
	game.TopMoves(&moves)

	sort.Sort(byScore(moves))

	fmt.Println(&game.board)
	for i, move := range moves {
		fmt.Printf("%3d %#v\n", i+1, move)
	}
}

func BenchmarkTopMoves(b *testing.B) {
	moves := make([]Move, 0, maxMoves)
	game := MakeGame()
	game.board.PlaceStone(board.Black, 9, 9)
	game.board.PlaceStone(board.White, 8, 8)
	game.board.PlaceStone(board.White, 8, 10)

	b.ResetTimer()
	for range b.N {
		game.TopMoves(&moves)
	}
}
