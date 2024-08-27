package main

import "fmt"

type S struct {
	i int
	s string
}

func main() {
	s := S{i: 7, s: "foo"}
	fmt.Println(s)
}
