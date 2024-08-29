package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"monte/events"
	"monte/ui"
)

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

	ch := make(chan ui.Command)

	r := runner{
		procs:         procs,
		currentProcId: 0,
		ticker:        time.Tick(2000 * time.Millisecond),
		uiChan:        ch,
	}
	go r.run()
	ui.Run(ch)
	r.procs[0].send("quit")
	r.procs[1].send("quit")
}

func (r *runner) run() {
	r.procs[0].send("move j10+j10")
	r.procs[1].send("move j10+j10")
	r.uiChan <- ui.Move("j10+j10")
	r.procs[0].send("move i9+i11")
	r.procs[1].send("move i9+i11")
	r.uiChan <- ui.Move("i9+i11")
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
}

type runner struct {
	procs         [2]proc
	currentProcId int
	ticker        <-chan time.Time
	uiChan        chan<- ui.Command
	reset         bool
}

func (r *runner) handleMessage(msg string, procId int) {
	fmt.Printf("Proc %d: %q\n", procId, msg)
	event, err := events.ParseEvent(msg)
	if err != nil {
		fmt.Printf("Error %v | proc %d\n", err.Error(), procId)
		return
	}
	switch event := event.(type) {
	case events.BestMove:
		r.currentProcId = procId
		// r.uiChan <- ui.Move(event.Move)

		if event.Terminal {
			winner := "It's a Draw"
			if event.Score > 1000 {
				winner = "Black won"
			} else if event.Score < -1000 {
				winner = "White won"
			}
			fmt.Println(winner)
			r.reset = true
		}
	}
}

func (r *runner) handleTick() {
	// r.procs[1-r.currentProcId].send("best-move")
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
