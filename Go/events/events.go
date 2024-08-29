package events

import (
	"errors"
	"fmt"
	"strings"
)

type BestMove struct {
	Move     string
	Terminal bool
	Score    int
}

type Info map[string]string

type Error string

type ParseError struct {
	Text    string
	Message error
}

func (e ParseError) Error() string {
	return e.Message.Error()
}

func ParseEvent(text string) (any, error) {
	text = strings.TrimSpace(text)
	parts := strings.SplitN(text, " ", 2)
	if len(parts) != 2 {
		return nil, ParseError{Text: text, Message: errors.New("missing required parameters")}
	}
	switch parts[0] {
	case "best-move":
		event := BestMove{}
		paramParts := strings.Split(parts[1], "; ")
		for _, part := range paramParts {
			values := strings.Split(part, "=")
			if len(values) != 2 {
				return nil, ParseError{Text: text, Message: errors.New("missing required best-move parameters")}
			}
			switch values[0] {
			case "move":
				event.Move = values[1]

			case "terminal":
				switch values[1] {
				case "true":
					event.Terminal = true
				case "false":
					event.Terminal = false
				default:
					return nil, ParseError{Text: text, Message: errors.New("invalid best-move 'terminal' best-move parameter")}
				}

			case "score":
				_, err := fmt.Sscanf(values[1], "%d", &event.Score)
				if err != nil {
					return nil, ParseError{Text: text, Message: fmt.Errorf("invalid best-move 'score' parameter: %q: %w", values[1], err)}
				}

			default:
				return nil, ParseError{Text: text, Message: fmt.Errorf("invalid best-move parameter: %q", values[0])}
			}
		}
		return event, nil
	case "info":
		info := Info{}
		paramParts := strings.Split(parts[1], "; ")
		for _, param := range paramParts {
			values := strings.Split(param, "=")
			if len(values) != 2 {
				return nil, ParseError{Text: text, Message: errors.New("missing required info parameters")}
			}
			info[values[0]] = values[1]
		}
		return info, nil

	case "error":
		return Error(parts[1]), nil
	}
	return nil, ParseError{Text: text, Message: errors.New("invalid event name")}
}
