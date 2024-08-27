package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

type proc struct {
	in  chan string
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

	var procs [2]proc
	for i := range 2 {
		proc, err := startProc(procPath(dir, os.Args[i+1]))
		if err != nil {
			fmt.Fprintln(os.Stderr, "Failed to start", os.Args[i+1])
		}
		procs[i] = proc
	}

	currentProcId := 0
	lastTick := time.Now()

	for {
		select {
		case msg := <-procs[0].in:
			handleMessage(msg, 0)
		case msg := <-procs[1].in:
			handleMessage(msg, 1)
			_ = msg
		default:
		}
		if time.Since(lastTick) > time.Second {
			procs[currentProcId].out.Write([]byte("best-move"))
			currentProcId = 1 - currentProcId
		}
	}
}

func handleMessage(msg string, procId int) {
	// TODO: update server to handle 'reset-game' command
	// TODO: update server inform about game terminal state
}

func procPath(dir, name string) string {
	if dir == "." {
		return "./" + name
	}
	return filepath.Join(dir, name)
}

func startProc(path string) (proc, error) {
	cmd := exec.Command(path)
	if cmd.Err != nil {
		return proc{}, cmd.Err
	}
	writer, _ := cmd.StdinPipe()
	reader, _ := cmd.StdoutPipe()
	ch := make(chan string, 20)
	go read(reader, ch)
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
	return proc{in: ch, out: writer}, nil
}

func read(reader io.ReadCloser, ch chan string) {
	bufReader := bufio.NewReader(reader)
	for {
		line, err := bufReader.ReadString('\n')
		if err == io.EOF {
			break
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, "ERROR: ", err)
			break
		}
		ch <- line
	}
}
