from collections import InlineList
from testing import assert_true


trait ElementTrait(Comparable, CollectionElement, Stringable):
    ...


@value
struct Heap[
    ElementType: ElementTrait,
    capacity: Int,
]:
    var items: List[ElementType]

    fn __init__(inout self):
        self.items = List[ElementType]()

    fn add(inout self, element: ElementType):
        if not self.items:
            self.items.append(element)
            return

        if len(self.items) == capacity:
            if element <= self.items[0]:
                return
            self.items[0] = element
            self._sift_down()
            return

        self.items.append(element)
        self._sift_up()
        self._check()

    fn _print(self, prefix: String):
        print(prefix, end=": ")
        for item in self.items:
            print(item[], end=", ")
        print()

    fn remove(inout self) -> ElementType:
        var result = self.items[0]
        self.items[0] = self.items.pop()
        self._sift_down()
        self._check()
        return result

    fn _sift_down(inout self):
        var parent_idx = 0
        var top_element = self.items[0]
        while True:
            var first = parent_idx
            var left_child_idx = parent_idx * 2 + 1
            if (
                left_child_idx < len(self.items)
                and self.items[left_child_idx] < top_element
            ):
                first = left_child_idx

            var right_child_idx = parent_idx * 2 + 2
            if (
                right_child_idx < len(self.items)
                and self.items[right_child_idx] < top_element
                and self.items[right_child_idx] < self.items[left_child_idx]
            ):
                first = right_child_idx

            if parent_idx == first:
                break

            self.items[parent_idx] = self.items[first]
            parent_idx = first

        self.items[parent_idx] = top_element

    fn _sift_up(inout self):
        var child_idx = len(self.items) - 1
        var child = self.items[child_idx]
        var parent_idx = (child_idx - 1) // 2

        while child_idx > 0 and child < self.items[parent_idx]:
            self.items[child_idx] = self.items[parent_idx]
            child_idx = parent_idx
            parent_idx = (parent_idx - 1) // 2

        self.items[child_idx] = child

    fn _check(self):
        for child_idx in range(1, len(self.items)):
            var parent_idx = (child_idx - 1) // 2
            debug_assert(
                self.items[parent_idx] <= self.items[child_idx], "FAILURE"
            )
