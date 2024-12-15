//go:build connect6

package board

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

func scoreStones(stone, stones Stone) (Score, Stone) {
	if stone == Black {
		switch stones {
		case 0x00:
			return twoStones - oneStone, None
		case 0x01:
			return threeStones - twoStones, None
		case 0x02:
			return fourStones - threeStones, None
		case 0x03:
			return fiveStones - fourStones, None
		case 0x04:
			return sixStones - fiveStones, Black
		case 0x10:
			return -twoStones, None
		case 0x20:
			return -threeStones, None
		case 0x30:
			return -fourStones, None
		case 0x40:
			return -fiveStones, None
		}
	} else {
		switch stones {
		case 0x00:
			return twoStones - oneStone, None
		case 0x01:
			return -twoStones, None
		case 0x02:
			return -threeStones, None
		case 0x03:
			return -fourStones, None
		case 0x04:
			return -fiveStones, None
		case 0x10:
			return threeStones - twoStones, None
		case 0x20:
			return fourStones - threeStones, None
		case 0x30:
			return fiveStones - fourStones, None
		case 0x40:
			return sixStones - fiveStones, White
		}
	}
	return 0, None
}
