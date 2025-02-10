package connect6

import (
	"fmt"
	"sort"
	"testing"

	"monte/board"
	"monte/common"
)

func TestRollout(t *testing.T) {
	board := board.MakeBoard()
	game := MakeGame(20)
	game.PlayMove(&board, Move{9, 9, 9, 9})
	rolloutScore := game.rollout(&board, Move{8, 8, 8, 10})
	fmt.Println(rolloutScore)
}

type byScore []common.MoveValue[Move]

func (b byScore) Len() int {
	return len(b)
}

func (b byScore) Less(i, j int) bool {
	return b[i].Value > b[j].Value
}

func (b byScore) Swap(i, j int) {
	b[i], b[j] = b[j], b[i]
}

func TestTopMoves(t *testing.T) {
	board := board.MakeBoard()
	game := MakeGame(20)
	moves := make([]common.MoveValue[Move], 0, 60)

	game.PlayMove(&board, Move{9, 9, 9, 9})
	game.PlayMove(&board, Move{8, 8, 8, 10})
	fmt.Println(&board)
	game.TopMoves(&board, &moves)

	sort.Sort(byScore(moves))

	fmt.Println(&board)
	for i, move := range moves {
		fmt.Printf("%3d %v\n", i+1, move)
	}
}

func BenchmarkTopMoves(b *testing.B) {
	board := board.MakeBoard()
	game := MakeGame(30)
	moves := make([]common.MoveValue[Move], 0, 30)
	game.PlayMove(&board, Move{9, 9, 9, 9})
	game.PlayMove(&board, Move{8, 8, 8, 10})

	b.ResetTimer()
	for range b.N {
		game.TopMoves(&board, &moves)
	}
}
