//go:build connect6

package board

import "monte/common"

const (
	maxStones = 6
)

const (
	oneStone    Score = 1
	twoStones   Score = 6
	threeStones Score = 30
	fourStones  Score = 120
	fiveStones  Score = 360
	sixStones   Score = 720
)

func scoreStones(turn common.Turn, stones Stone) Score {
	if turn == common.First {
		switch stones {
		case 0x00:
			return twoStones - oneStone
		case 0x01:
			return threeStones - twoStones
		case 0x02:
			return fourStones - threeStones
		case 0x03:
			return fiveStones - fourStones
		case 0x04:
			return sixStones - fiveStones
		case 0x10:
			return -twoStones
		case 0x20:
			return -threeStones
		case 0x30:
			return -fourStones
		case 0x40:
			return -fiveStones
		}
	} else {
		switch stones {
		case 0x00:
			return twoStones - oneStone
		case 0x01:
			return -twoStones
		case 0x02:
			return -threeStones
		case 0x03:
			return -fourStones
		case 0x04:
			return -fiveStones
		case 0x10:
			return threeStones - twoStones
		case 0x20:
			return fourStones - threeStones
		case 0x30:
			return fiveStones - fourStones
		case 0x40:
			return sixStones - fiveStones
		}
	}
	return 0
}
