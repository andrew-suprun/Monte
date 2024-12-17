//go:build !debug

package board

import "bytes"

func (b *Board) validate() {}

func (b *Board) debugScoresString(buf *bytes.Buffer) {}
