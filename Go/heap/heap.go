package heap

import (
	"bytes"
	"fmt"
)

type Less[E any] func(E, E) bool

type Heap[E any] struct {
	items []E
	less  Less[E]
}

func NewHeap[E any](items []E, less Less[E]) *Heap[E] {
	return &Heap[E]{
		items: items,
		less:  less,
	}
}

func (h *Heap[E]) Add(e E) {
	if len(h.items) == cap(h.items) {
		if !h.less(h.items[0], e) {
			return
		}
		h.items[0] = e
		h.siftDown()
		return
	}
	h.items = append(h.items, e)
	h.siftUp()
}

func (h *Heap[E]) Validate() {
	for i := range h.items[1:] {
		if h.less(h.items[i], h.items[(i-1)/2]) {
			fmt.Println(h.items[(i-1)/2], h.items[i])
			panic("### heap.Validate ###")
		}
	}
}

func (h *Heap[E]) String() string {
	buf := &bytes.Buffer{}
	fmt.Fprintln(buf, "---- Heap")
	for _, item := range h.items {
		fmt.Fprintf(buf, "  - %v\n", item)
	}
	return buf.String()
}

func (h *Heap[E]) siftUp() {
	childIdx := len(h.items) - 1
	child := h.items[childIdx]
	for childIdx > 0 && h.less(child, h.items[(childIdx-1)/2]) {
		parentIdx := (childIdx - 1) / 2
		parent := h.items[parentIdx]
		h.items[childIdx] = parent
		childIdx = parentIdx
	}
	h.items[childIdx] = child
}

func (h *Heap[E]) siftDown() {
	idx := 0
	elem := h.items[idx]
	for {
		first := idx
		leftChildIdx := idx*2 + 1
		if leftChildIdx < len(h.items) && h.less(h.items[leftChildIdx], elem) {
			first = leftChildIdx
		}
		rightChildIdx := idx*2 + 2
		if rightChildIdx < len(h.items) &&
			h.less(h.items[rightChildIdx], elem) &&
			h.less(h.items[rightChildIdx], h.items[leftChildIdx]) {
			first = rightChildIdx
		}
		if idx == first {
			break
		}

		h.items[idx] = h.items[first]
		idx = first
	}
	h.items[idx] = elem
}
