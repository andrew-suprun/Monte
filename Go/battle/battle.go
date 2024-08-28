package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type proc struct {
	name string
	in   chan string
	out  io.WriteCloser
	err  io.ReadCloser
}

func (p *proc) send(f string, a ...any) {
	str := fmt.Sprintf(f, a...)
	p.out.Write([]byte(str))
	p.out.Write([]byte{'\n'})
	fmt.Printf("sent %q\n", str)
}

type runner struct {
	procs         [2]proc
	currentProcId int
	ticker        <-chan time.Time
	reset         bool
}

func (r *runner) run() {
	r.procs[0].send("move j10+j10")
	r.procs[1].send("move j10+j10")
	r.procs[0].send("go")
	r.procs[1].send("go")
	for !r.reset {
		select {
		case msg := <-r.procs[0].in:
			r.handleMessage(msg, 0)
		case msg := <-r.procs[1].in:
			r.handleMessage(msg, 1)
		case <-r.ticker:
			r.handleTick()
		}
	}
}

func (r *runner) handleMessage(msg string, procId int) {
	msg = strings.TrimSpace(msg)
	fmt.Printf("Got message from %d[%s]: %q\n", procId, r.procs[procId].name, msg)
	tokens := strings.Split(msg, " ")
	switch tokens[0] {
	case "best-move":
		if len(tokens) != 3 {
			fmt.Printf("Invalid best-move command: %q\n", msg)
			return
		}
		fmt.Printf("move by proc%d: %s\n", procId, tokens[1])
		switch tokens[2] {
		case "nonterminal":
			for procId := range r.procs {
				r.procs[procId].send("move %s", tokens[1])
			}
		case "win":
			fmt.Printf("Process %d won", procId)
			r.reset = true
		case "loss":
			fmt.Printf("Process %d lost", procId)
			r.reset = true
		case "draw":
			fmt.Printf("It's a draw")
			r.reset = true
		}
	}
}

func (r *runner) handleTick() {
	r.procs[r.currentProcId].send("info")
	r.procs[r.currentProcId].send("best-move")
	fmt.Printf("tick %d\n", r.currentProcId)
	r.currentProcId = 1 - r.currentProcId
}

func main() {
	if len(os.Args) != 3 {
		fmt.Println("Usage: battle <engine1> <engine1>")
		fmt.Println("       both engines must be in the same")
		fmt.Println("       directory with battle executable")
		return
	}

	var procs [2]proc
	for i := range 2 {
		proc, err := startProc(os.Args[i+1])
		if err != nil {
			fmt.Fprintln(os.Stderr, "Failed to start", os.Args[i+1])
		}
		procs[i] = proc
	}

	r := runner{
		procs:         procs,
		currentProcId: 0,
		ticker:        time.Tick(time.Second),
	}
	r.run()
}

func startProc(name string) (proc, error) {
	dir := filepath.Dir(os.Args[0])
	path := "./" + name
	if dir != "." {
		path = filepath.Join(dir, name)
	}

	cmd := exec.Command(path)
	if cmd.Err != nil {
		return proc{}, cmd.Err
	}
	writer, _ := cmd.StdinPipe()
	reader, _ := cmd.StdoutPipe()
	err, _ := cmd.StderrPipe()
	ch := make(chan string, 20)
	go read(reader, ch)
	go readErr(err)
	return proc{name: name, in: ch, out: writer, err: err}, cmd.Start()
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

func readErr(errs io.ReadCloser) {
	bufReader := bufio.NewReader(errs)
	for {
		line, err := bufReader.ReadString('\n')
		if err == io.EOF {
			break
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, "ERROR: ", err)
			break
		}
		os.Stderr.WriteString(line)
	}
}
