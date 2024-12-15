//go:build connect6

package board

import "monte/score"

const (
	maxStones = 6
)

const (
	oneStone    score.Score = 1
	twoStones   score.Score = 5
	threeStones score.Score = 20
	fourStones  score.Score = 60
	fiveStones  score.Score = 1200
	// sixStones   score.Score = 1200
)

func scoreStones(stone, stones Stone) score.Score {
	if stone == Black {
		switch stones {
		case 0x00:
			return 5
		case 0x01:
			return 24
		case 0x02:
			return 90
		case 0x03:
			return 240
		case 0x04:
			return 10_000
		case 0x10:
			return -6
		case 0x20:
			return -30
		case 0x30:
			return -120
		case 0x40:
			return -360
		}
	} else {
		switch stones {
		case 0x00:
			return 5
		case 0x01:
			return -6
		case 0x02:
			return -30
		case 0x03:
			return -120
		case 0x04:
			return -360
		case 0x10:
			return 24
		case 0x20:
			return 90
		case 0x30:
			return 240
		case 0x40:
			return 10_000
		}
	}
	return 0
}

// func scoreStones(stone, stones Stone) score.Score {
// 	if stone == Black {
// 		switch stones {
// 		case 0x00:
// 			return 1
// 		case 0x01:
// 			return twoStones - oneStone
// 		case 0x02:
// 			return threeStones - twoStones
// 		case 0x03:
// 			return fourStones - threeStones
// 		case 0x04:
// 			return fiveStones - fourStones
// 		case 0x10:
// 			return -1
// 		case 0x20:
// 			return -twoStones
// 		case 0x30:
// 			return -threeStones
// 		case 0x40:
// 			return -fourStones
// 		}
// 	} else {
// 		switch stones {
// 		case 0x00:
// 			return 1
// 		case 0x01:
// 			return -1
// 		case 0x02:
// 			return -twoStones
// 		case 0x03:
// 			return -threeStones
// 		case 0x04:
// 			return -fourStones
// 		case 0x10:
// 			return twoStones - oneStone
// 		case 0x20:
// 			return threeStones - twoStones
// 		case 0x30:
// 			return fourStones - threeStones
// 		case 0x40:
// 			return fiveStones - fourStones
// 		}
// 	}
// 	return 0
// }
