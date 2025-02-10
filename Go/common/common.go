package common

import (
	"fmt"
	"math"
)

type Turn int

const (
	First Turn = iota
	Second
)

func (turn Turn) String() string {
	switch turn {
	case First:
		return "First"
	case Second:
		return "Second"
	}
	panic("Turn.String()")
}

type Equatable[T any] interface {
	fmt.Stringer
	Equal(t T) bool
}

type MoveValue[Move Equatable[Move]] struct {
	Move  Move
	Value Value
}

func (m MoveValue[Move]) Less(other MoveValue[Move]) bool {
	return m.Value < other.Value
}

func (m MoveValue[Move]) String() string {
	return fmt.Sprintf("%-7v v: %v", m.Move, m.Value)
}

type Value float32

var (
	Win  Value = Value(math.Inf(1))
	Loss Value = Value(math.Inf(-1))
	Draw Value = Value(math.NaN())
)

func (value Value) IsDecided() bool {
	v := float64(value)
	return math.IsInf(v, 0) || math.IsNaN(v)
}

func (value Value) IsWin() bool {
	v := float64(value)
	return math.IsInf(v, 1)
}

func (value Value) IsLoss() bool {
	v := float64(value)
	return math.IsInf(v, -1)
}

func (value Value) IsDraw() bool {
	v := float64(value)
	return math.IsNaN(v)
}

func (value Value) String() string {
	v := float64(value)
	if math.IsInf(v, 1) {
		return "first-win"
	} else if math.IsInf(v, -1) {
		return "second-win"
	} else if math.IsNaN(v) {
		return "draw"
	}
	return fmt.Sprint(float32(value))
}
