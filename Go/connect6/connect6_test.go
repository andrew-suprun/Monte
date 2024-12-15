package connect6

import (
	"fmt"
	"math/rand"
	"testing"
	"time"
)

func TestRollout(t *testing.T) {
	scores := [3]int{}
	game := NewGame()
	game.PlayMove(MakeMove(9, 9, 9, 9))
	game.PlayMove(MakeMove(0, 0, 1, 0))
	for i := range int64(4) {
		fmt.Println("--- Rollout", i)
		newGame := *game
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
func BenchmarkRollout(b *testing.B) {
	rnd := rand.New(rand.NewSource(0))
	game := NewGame()
	game.PlayMove(MakeMove(9, 9, 9, 9))
	for range b.N {
		game.Rollout(rnd)
	}
}
