package heap

import (
	"fmt"
	"math/rand"
	"testing"
)

type elem int

func (e elem) Less(other elem) bool {
	return e < other
}

func less(i, j int) bool {
	return i < j
}

func TestHeap(t *testing.T) {
	items := make([]elem, 0, 20)
	values := make([]elem, 100)
	for i := range elem(100) {
		values[i] = i + 1
	}
	rand.Shuffle(100, func(i, j int) {
		values[i], values[j] = values[j], values[i]
	})
	for i := range 100 {
		Add(&items, values[i])
	}
	items[0] = 200
	fmt.Println(items)
	Validate(&items)
}

func BenchmarkHeap(b *testing.B) {
	items := make([]elem, 0, 20)
	values := make([]elem, 100)
	values2 := make([]elem, 100)
	for i := range elem(100) {
		values[i] = i + 1
	}
	rand.Shuffle(100, func(i, j int) {
		values[i], values[j] = values[j], values[i]
	})

	b.ResetTimer()
	for range b.N {
		copy(values2, values)
		for i := range 100 {
			Add(&items, values2[i])
		}
	}
}
