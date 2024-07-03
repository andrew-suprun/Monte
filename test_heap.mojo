from testing import assert_true
from heap import Heap
import random


fn test_heap() raises:
    random.seed()
    var heap = Heap[Int, 20]()
    for _ in range(100):
        var v = int(random.random_si64(0, 100))
        heap.add(v)
    assert_true(len(heap.items) == 20)
    var current = 0
    for _ in range(20):
        var next = heap.remove()
        assert_true(current <= next)
        current = next
