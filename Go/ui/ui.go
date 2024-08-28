package ui

import (
	"errors"
	"fmt"
	"image/color"
	"strings"

	rl "github.com/gen2brain/raylib-go/raylib"
)

const boardSize = 1000
const radius = boardSize/40 - 1
const diameter = boardSize / 20

type Command interface {
	private()
}

type Move string

func (Move) private() {}

type move struct {
	x1, y1, x2, y2 int32
}

type connect6 struct {
	moves []move
}

func (g *connect6) handleCommand(cmd Command) error {
	fmt.Println("### Got", cmd)
	switch cmd := cmd.(type) {
	case Move:
		m, err := parseMove(cmd)
		if err != nil {
			return err
		}
		g.moves = append(g.moves, m)
	}
	return nil
}

func Run(commands <-chan Command) {
	fmt.Println("### Stared UI")
	c6 := connect6{}
	rl.InitWindow(boardSize, boardSize, "Connect6")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		select {
		case cmd := <-commands:
			c6.handleCommand(cmd)
		default:
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.Brown)

		var i int32 = diameter
		for ; i <= diameter+20*diameter; i += diameter {
			rl.DrawLine(diameter+1, i+1, boardSize+1-diameter, i+1, color.RGBA{0, 0, 0, 195})
			rl.DrawLine(diameter, i, boardSize-diameter, i, color.RGBA{0, 0, 0, 255})
			rl.DrawLine(i+1, diameter+1, i+1, boardSize+1-diameter, color.RGBA{0, 0, 0, 195})
			rl.DrawLine(i, diameter, i, boardSize-diameter, color.RGBA{0, 0, 0, 255})
		}

		curColor := rl.Black
		nextCol := rl.White
		for _, move := range c6.moves {
			rl.DrawCircle((move.x1+1)*diameter, (move.y1+1)*diameter, radius, curColor)
			rl.DrawCircle((move.x2+1)*diameter, (move.y2+1)*diameter, radius, curColor)
			curColor, nextCol = nextCol, curColor
		}

		rl.EndDrawing()
	}
}

func parseMove(mov Move) (move, error) {
	tokens := strings.Split(string(mov), "+")
	if len(tokens) != 2 {
		return move{}, errors.New("invalid token")
	}
	x1, y1, err1 := parseToken(tokens[0])
	x2, y2, err2 := parseToken(tokens[1])
	if err1 != nil || err2 != nil {
		return move{}, errors.New("invalid token")
	}
	return move{x1, y1, x2, y2}, nil
}

func parseToken(token string) (int32, int32, error) {
	if len(token) < 2 || len(token) > 3 {
		return 0, 0, errors.New("invalid token")
	}
	if token[0] < 'a' || token[0] > 's' {
		return 0, 0, errors.New("invalid token")
	}
	if token[1] < '0' || token[1] > '9' {
		return 0, 0, errors.New("invalid token")
	}
	var x = token[0] - 'a'
	var y = token[1] - '0'
	if len(token) == 3 {
		if token[2] < '0' || token[2] > '9' {
			return 0, 0, errors.New("invalid token")
		}
		y = 10*y + token[2] - '0'
	}
	y = 19 - y
	if x >= 19 || y >= 19 {
		return 0, 0, errors.New("invalid token")
	}
	return int32(x), int32(y), nil
}
