import Foundation

protocol Default {
  init()
}

enum Player { case first, second }

protocol MoveProtocol {
  var player: Player { get }
  var score: Float { get }
  
  init(player: Player, score: Float)
}

protocol GameProtocol: Default {
  associatedtype Move: MoveProtocol

  static var exploreFactor: Float { get }
  mutating func make(move: Move)
  func extend() -> [Move]
}

struct SearchTree<Game: GameProtocol> {
  class Node {
    var children = [Node]()
    var move: Game.Move
    
    init() {
      move = Game.Move(player: .second, score: 0)
    }

    init(move: Game.Move) {
      self.move = move
    }
  }

  var root = Node()

  func extend() {
    var game = Game()
    let leaf = selectLeaf(game: &game)
    let moves = game.extend()
    leaf.children = moves.map { Node(move: $0) }
  }

  func selectLeaf(game: inout Game) -> Node {
    var node = root
    var player = Player.first

    while true {
      if let child = selectChild(parent: node, player: player) {
        node = child
        game.make(move: node.move)
        player = if player == .first { .second } else { .first }
      } else {
        return node
      }
    }
  }

  func selectChild(parent: Node, player: Player) -> Node? {
    guard !parent.children.isEmpty else { return nil }
    let dParentChildren = Float(parent.children.count)

    var selectedChild = parent.children[0]
    let dChildren = Float.init(selectedChild.children.count)
    let dScore = selectedChild.move.score
    var selectedScore = dScore + Game.exploreFactor * sqrt(dParentChildren / dChildren)

    for child in parent.children.dropFirst() {
      let dChildren = Float.init(selectedChild.children.count)
      let dScore = selectedChild.move.score
      let score = dScore + Game.exploreFactor * sqrt(dParentChildren / dChildren)

      if (player == .first && selectedScore < score) || (player == .second && selectedScore > score)
      {
        selectedChild = child
        selectedScore = score
      }
    }
    return selectedChild
  }

  func debug() {
    debug(node: root, level: 0)
  }

  func debug(node: Node, level: Int) {
    for _ in 0..<level {
      print("| ", terminator: "")
    }
    print(node.move)
    for child in node.children {
      debug(node: child, level: level + 1)
    }
  }
}

/// Test Game

struct TestGame: GameProtocol {
  typealias Move = TestMove

  static let exploreFactor: Float = 2.0
  var currentPlayer: Player = .first

  mutating func make(move: Move) {
    currentPlayer = if currentPlayer == .first { .second } else { .first }
  }

  func extend() -> [Move] {
    var moves = [TestMove]()
    for _ in 1...5 {
      let score = if currentPlayer == .first { Float(Int.random(in: 10...20)) } else { -Float(Int.random(in: 10...20)) }
      moves.append(TestMove(player: currentPlayer, score: score))
    }
    return moves
  }
}

struct TestMove: MoveProtocol, CustomStringConvertible {
  static var lastId: Int = 0
  let id: Int
  let player: Player
  let score: Float

  init(player: Player, score: Float) {
    Self.lastId += 1
    id = Self.lastId
    self.player = player
    self.score = score
  }

  var description: String {
    return "#\(id): \(player) [\(score)]"
  }
}

var tree = SearchTree<TestGame>()
tree.extend()
tree.extend()
tree.extend()
tree.debug()

