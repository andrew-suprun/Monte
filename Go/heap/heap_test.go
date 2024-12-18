package heap

import (
	"math/rand"
	"testing"
)

func less(i, j int) bool {
	return i < j
}

func TestHeap(t *testing.T) {
	items := make([]int, 0, 20)
	values := make([]int, 100)
	heap := NewHeap(items, less)
	for i := range 100 {
		values[i] = i + 1
	}
	rand.Shuffle(100, func(i, j int) {
		values[i], values[j] = values[j], values[i]
	})
	for i := range 100 {
		heap.Add(values[i])
	}
	heap.Validate()
}

func BenchmarkHeap(b *testing.B) {
	items := make([]int, 0, 20)
	heap := NewHeap(items, less)
	values := make([]int, 100)
	values2 := make([]int, 100)
	for i := range 100 {
		values[i] = i + 1
	}
	rand.Shuffle(100, func(i, j int) {
		values[i], values[j] = values[j], values[i]
	})

	b.ResetTimer()
	for range b.N {
		copy(values2, values)
		for i := range 100 {
			heap.Add(values2[i])
		}
	}
}
