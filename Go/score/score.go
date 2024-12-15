package score

import (
	"fmt"
)

type (
	Score int32
	State byte
)

const (
	Nonterminal State = iota
	Draw
	Win
)

const (
	drawScore = 0
	winScore  = 1200
)

func (score Score) State() State {
	if score >= winScore {
		return Win
	} else if score == drawScore {
		return Draw
	}
	return Nonterminal
}

func (score Score) String() string {
	if score >= winScore {
		return "Win"
	} else if score == drawScore {
		return "Draw"
	}
	return fmt.Sprintf("%d", score)
}

func (state State) String() string {
	switch state {
	case Nonterminal:
		return "Nonterminal"
	case Draw:
		return "Draw"
	case Win:
		return "Win"
	}
	return ""
}
