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

type runner struct {
	procs  [2]proc
	uiChan chan<- ui.Command
}

type proc struct {
	name string
	in   *bufio.Reader
	out  io.WriteCloser
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

	ch := make(chan ui.Command)

	r := runner{
		procs:  procs,
		uiChan: ch,
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

	procId := 0
mainLoop:
	for {
		proc := &r.procs[procId]
		start := time.Now()
		var bestMove events.BestMove

	waitForTimer:
		for time.Since(start) < 5*time.Second {
			proc.send("expand 1000")
			line, err := proc.read()
			if err != nil {
				fmt.Printf("Failed to read procs stdout: %v`\n", err)
			}
		waitForReply:
			for {
				event, err := events.ParseEvent(line)
				if err != nil {
					fmt.Println(err.Error())
					return
				}
				switch event := event.(type) {
				case events.BestMove:
					bestMove = event
					// fmt.Printf("proc %d: %q\n", procId, line)
					break waitForReply
				default:
					fmt.Printf("Unrecognized event: %v\n", event)
				}
			}
			if bestMove.Conclusive {
				break waitForTimer
			}
		}

		r.uiChan <- ui.Move(bestMove.Move)

		if bestMove.Terminal {
			winner := "It's a Draw."
			if bestMove.Score > 1000 {
				winner = "Black Won!"
			} else if bestMove.Score < -1000 {
				winner = "White Won!"
			}
			fmt.Println(winner)
			break mainLoop
		}

		r.procs[0].send("move " + bestMove.Move)
		r.procs[1].send("move " + bestMove.Move)
		procId = 1 - procId
	}
}

func (p *proc) send(f string, a ...any) {
	str := fmt.Sprintf(f, a...)
	_, err := p.out.Write([]byte(str))
	if err != nil {
		panic(err)
	}
	_, err = p.out.Write([]byte{'\n'})
	if err != nil {
		panic(err)
	}
	// fmt.Printf("proc: sent %q\n", str)
}

func (p *proc) read() (string, error) {
	result, err := p.in.ReadString('\n')
	// fmt.Printf("proc: got %q, err %v\n", result, err)
	return result, err
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
	go readErr(err)
	return proc{name: name, in: bufio.NewReader(reader), out: writer}, cmd.Start()
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
