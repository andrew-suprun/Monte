package connect6

import (
	"fmt"
	"monte/common"
	"sort"
	"testing"
)

func TestRollout(t *testing.T) {
	game := MakeGame(60, 20)
	game.PlayMove(Move{9, 9, 9, 9})
	rolloutScore := game.rollout(Move{8, 8, 8, 10})
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
	moves := make([]common.MoveValue[Move], 0, 60)
	game := MakeGame(60, 20)
	game.PlayMove(Move{9, 9, 9, 9})
	game.PlayMove(Move{8, 8, 8, 10})
	game.TopMoves(&moves)

	sort.Sort(byScore(moves))

	fmt.Println(&game.board)
	for i, move := range moves {
		fmt.Printf("%3d %#v\n", i+1, move)
	}
}

func BenchmarkTopMoves(b *testing.B) {
	moves := make([]common.MoveValue[Move], 0, 60)
	game := MakeGame(200, 30)
	game.PlayMove(Move{9, 9, 9, 9})
	game.PlayMove(Move{8, 8, 8, 10})

	b.ResetTimer()
	for range b.N {
		game.TopMoves(&moves)
	}
}
