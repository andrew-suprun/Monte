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
	sixStones   Score = 10_000
)

func scoreStones(stone, stones Stone) Score {
	if stone == Black {
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
