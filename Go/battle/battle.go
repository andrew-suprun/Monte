package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

type proc struct {
	in  io.ReadCloser
	out io.WriteCloser
}

func main() {
	if len(os.Args) != 3 {
		fmt.Println("Usage: battle <engine1> <engine1>")
		fmt.Println("       both engines must be in the same")
		fmt.Println("       directory with battle executable")
		return
	}
	dir := filepath.Dir(os.Args[0])
	fmt.Println("dir", dir)
	// procs := [2]proc{startProc(procPath(dir, os.Args[1])), startProc(procPath(dir, os.Args[2]))}
	// fmt.Println("awaiting:", cmd.Err)
	// cmd.Wait()
	// fmt.Println("awaited:", cmd.Err)
}

func procPath(dir, name string) string {
	if dir == "." {
		return "./" + name
	}
	return filepath.Join(dir, name)
}

func startProc(path string) proc {
	cmd := exec.Command("./c6")
	fmt.Println("before start:", cmd.Err)
	writer, _ := cmd.StdinPipe()
	reader, _ := cmd.StdoutPipe()
	go read(reader)
	cmd.Start()
	fmt.Println("after start:", cmd.Err)
	in := bufio.NewReader(os.Stdin)
	for {
		line, _ := in.ReadString('\n')
		fmt.Printf("%q\n", line)
		writer.Write([]byte(line))
		if line == "quit\n" {
			break
		}
	}
	return proc{reader, writer}
}

func read(reader io.ReadCloser) {
	bufReader := bufio.NewReader(reader)
	for {
		line, err := bufReader.ReadString('\n')
		if err == io.EOF {
			break
		}
		if err != nil {
			fmt.Println("ERROR: ", err)
		}
		fmt.Println("read: ", line)
	}
}
