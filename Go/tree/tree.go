package tree

import (
	"bytes"
	"fmt"
	"math"

	. "monte/common"
)

// type Board[move Equatable[move], self any] interface {
type Board[self any, move any] interface {
	Copy() self
	Rollout(Turn, int) Value
}

type Game[board Board[board, move], move Equatable[move]] interface {
	TopMoves(board, *[]MoveValue[move])
	PlayMove(move)
	ExpFactor() float64
}

type Tree[board Board[board, move], move Equatable[move]] struct {
	nodes    []node
	moves    []move
	topMoves []MoveValue[move]
}

type node struct {
	firstChild int32
	lastChild  int32
	nSims      int32
	value      Value
}

func NewTree[board Board[board, move], move Equatable[move]]() *Tree[board, move] {
	var m move
	return &Tree[board, move]{
		nodes: []node{{}},
		moves: []move{m},
	}
}

func (tree *Tree[board, move]) Expand(b board, game Game[board, move]) {
	if !tree.nodes[0].value.IsDecided() {
		tree.expand(b.Copy(), game, 0)
		// tree.validate() // TODO: implement
	}

	// undecided := 0
	// for i := root.firstChild; i < root.lastChild; i++ {
	// 	child := tree.nodes[i]
	// 	if !child.value.IsDecided() {
	// 		if child.nSims > 1 {
	// 			undecided++
	// 		} else {
	// 			return root.Decision(), false
	// 		}
	// 	}
	// }
	// return root.Decision(), undecided == 1
}

func (tree *Tree[board, move]) CommitMove(toPlay move) {
	idx := int32(-1)
	root := tree.nodes[0]
	for childIdx := root.firstChild; childIdx < root.lastChild; childIdx++ {
		if tree.moves[childIdx].Equal(toPlay) {
			idx = childIdx
			break
		}
	}

	if idx != -1 {
		newNodes := []node{tree.nodes[idx]}
		newMoves := []move{tree.moves[idx]}
		newIdx := 0
		for newIdx < len(newNodes) {
			oldFirstChild := newNodes[newIdx].firstChild
			oldLastChild := newNodes[newIdx].lastChild
			if oldFirstChild == 0 && oldLastChild == 0 {
				newIdx++
				continue
			}
			newNodes[newIdx].firstChild = int32(len(newNodes))
			newNodes = append(newNodes, tree.nodes[oldFirstChild:oldLastChild]...)
			newMoves = append(newMoves, tree.moves[oldFirstChild:oldLastChild]...)
			newNodes[newIdx].lastChild = int32(len(newNodes))
			newIdx++
		}
		tree.nodes = newNodes
		tree.moves = newMoves

		return
	}

	tree.nodes = tree.nodes[:0]
	tree.nodes = append(tree.nodes, node{})
	tree.moves = tree.moves[:0]
	tree.moves = append(tree.moves, toPlay)
}

func (tree *Tree[board, move]) BestMove() move { // TODO: return forced move indicator
	root := tree.nodes[0]
	bestValue := tree.nodes[root.firstChild].value
	bestMove := tree.moves[root.firstChild]
	if bestValue.IsDraw() {
		bestValue = 0
	}
	for idx := root.firstChild + 1; idx < root.lastChild; idx++ {
		value := tree.nodes[idx].value
		if value.IsDraw() {
			value = 0
		}
		if bestValue < 0 {
			bestValue = value
			bestMove = tree.moves[idx]
		}
	}
	return bestMove
}

func (tree *Tree[board, move]) DebugAvailableMoves() string {
	buf := &bytes.Buffer{}
	root := tree.nodes[0]
	fmt.Fprintf(buf, "%s: d: %v v: %v n: %d\n", tree.moves[0].String(), root.value, root.value, root.nSims)
	for i := root.firstChild; i < root.lastChild; i++ {
		child := tree.nodes[i]
		fmt.Fprintf(buf, "  [%2d] %s: d: %v v: %v n: %d\n", i, tree.moves[i].String(), child.value, child.value, child.nSims)
	}
	return buf.String()
}

func (tree *Tree[board, move]) expand(b board, game Game[board, move], parentIdx int32) {
	parent := &tree.nodes[parentIdx]

	if parent.firstChild == 0 {
		game.TopMoves(b, &tree.topMoves)
		if len(tree.topMoves) == 0 {
			panic("Function top_moves(game, ...) returns empty result.")
		}

		parent.firstChild = int32(len(tree.nodes))
		parent.lastChild = int32(len(tree.nodes) + len(tree.topMoves))
		for _, child := range tree.topMoves {
			tree.nodes = append(tree.nodes, node{
				nSims: 1,
				value: child.Value,
			})
			tree.moves = append(tree.moves, child.Move)
		}
	} else {
		expFactor := game.ExpFactor()
		selectedChildIdx := int32(-1)
		logParentSims := math.Log(float64(parent.nSims))
		maxV := math.Inf(-1)
		for idx := parent.firstChild; idx < parent.lastChild; idx++ {
			child := tree.nodes[idx]
			if child.value.IsDecided() {
				continue
			}
			v := float64(child.value)/float64(parent.nSims) + expFactor*math.Sqrt(logParentSims/float64(child.nSims))
			if v > maxV {
				maxV = v
				selectedChildIdx = idx
			}
		}

		game.PlayMove(tree.moves[selectedChildIdx])
		tree.expand(b, game, selectedChildIdx)
	}

	parent = &tree.nodes[parentIdx]
	parent.nSims = int32(0)
	parent.value = Loss
	hasDraw := false
	for i := parent.firstChild; i < parent.lastChild; i++ {
		child := tree.nodes[i]
		if child.value.IsWin() {
			parent.value = Loss
			return
		} else if child.value.IsDraw() {
			hasDraw = true
			continue
		} else if child.value.IsLoss() {
			continue
		}
		parent.nSims += child.nSims
		parent.value += child.value
	}
	parent.value = -parent.value
	if hasDraw && parent.value < 0 {
		parent.value = 0
	}
}

func (tree *Tree[board, move]) String() string {
	buf := &bytes.Buffer{}
	tree.string(buf, 0, 0)
	return buf.String()
}

func (tree *Tree[board, move]) string(buf *bytes.Buffer, idx int32, depth int) {
	buf.WriteRune('\n')
	for range depth {
		buf.WriteString("|   ")
	}

	fmt.Fprint(buf, tree.moves[idx])
	fmt.Fprintf(buf, " [%d] ", idx)
	node := tree.nodes[idx]
	node.string(buf)
	for childIdx := node.firstChild; childIdx < node.lastChild; childIdx++ {
		tree.string(buf, childIdx, depth+1)
	}
}

func (node *node) String() string {
	buf := &bytes.Buffer{}
	node.string(buf)
	return buf.String()
}

func (node *node) string(buf *bytes.Buffer) {
	fmt.Fprintf(buf, "[%d] %.3f", node.nSims, node.value)
}
