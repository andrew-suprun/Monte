package common

import (
	"fmt"
	"testing"
)

func TestValue(t *testing.T) {
	v := Draw
	if !v.IsDraw() || !v.IsDecided() || fmt.Sprint(v) != "draw" {
		fmt.Println(v.IsDraw(), v.IsDecided(), fmt.Sprint(v))
		t.Fail()
	}
	v = Win
	if !v.IsWin() || !v.IsDecided() || fmt.Sprint(v) != "first-win" {
		fmt.Println(v.IsWin(), v.IsDecided(), fmt.Sprint(v))
		t.Fail()
	}
	v = Loss
	if !v.IsLoss() || !v.IsDecided() || fmt.Sprint(v) != "second-win" {
		fmt.Println(v.IsLoss(), v.IsDecided(), fmt.Sprint(v))
		t.Fail()
	}
	v = 123
	if v.IsDraw() || v.IsWin() || v.IsLoss() || v.IsDecided() || fmt.Sprint(v) != "123" {
		fmt.Println(v.IsDraw(), v.IsWin(), v.IsLoss(), v.IsDecided(), fmt.Sprint(v))
		t.Fail()
	}
}
