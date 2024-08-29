package events

import (
	"testing"
)

func TestParser(t *testing.T) {
	ev, err := ParseEvent("best-move terminal=true; score=123")
	m := ev.(BestMove)
	if m.Score != 123 || !m.Terminal {
		t.Logf("ev = %v err = %v", ev, err)
		t.Fail()
	}

}
