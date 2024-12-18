package heap

type Comparable[t any] interface {
	Less(other t) bool
}

func Add[E Comparable[E]](items *[]E, e E) {
	if len(*items) == cap(*items) {
		if !(*items)[0].Less(e) {
			return
		}
		(*items)[0] = e
		siftDown(items)
		return
	}
	*items = append(*items, e)
	siftUp(items)
}

func Validate[E Comparable[E]](items *[]E) {
	for i := range (*items)[1:] {
		if (*items)[i].Less((*items)[(i-1)/2]) {
			panic("### heap.Validate() ###")
		}
	}
}

func siftUp[E Comparable[E]](items *[]E) {
	childIdx := len(*items) - 1
	child := (*items)[childIdx]
	for childIdx > 0 && child.Less((*items)[(childIdx-1)/2]) {
		parentIdx := (childIdx - 1) / 2
		parent := (*items)[parentIdx]
		(*items)[childIdx] = parent
		childIdx = parentIdx
	}
	(*items)[childIdx] = child
}

func siftDown[E Comparable[E]](items *[]E) {
	idx := 0
	elem := (*items)[idx]
	for {
		first := idx
		leftChildIdx := idx*2 + 1
		if leftChildIdx < len(*items) && (*items)[leftChildIdx].Less(elem) {
			first = leftChildIdx
		}
		rightChildIdx := idx*2 + 2
		if rightChildIdx < len(*items) &&
			(*items)[rightChildIdx].Less(elem) &&
			(*items)[rightChildIdx].Less((*items)[leftChildIdx]) {
			first = rightChildIdx
		}
		if idx == first {
			break
		}

		(*items)[idx] = (*items)[first]
		idx = first
	}
	(*items)[idx] = elem
}
