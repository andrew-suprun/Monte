import Foundation

protocol Default {
  init()
}

protocol ScoreProtocol: Default {
  var double: Double { get }
}

protocol GameProtocol: Default {
  associatedtype Move: Default
  associatedtype Score: ScoreProtocol

  static var exploreFactor: Double { get }
  func make(move: Move)
  func extend() -> [(move: Move, score: Score)]
}

enum Player { case first, second }

struct SearchTree<Game: GameProtocol> {
  class Node {
    var children = [Node]()
    var score: Game.Score = Game.Score()
    var move: Game.Move = Game.Move()
    init() {}
    init(move: Game.Move, score: Game.Score) {
      self.move = move
      self.score = score
    }
  }

  var root = Node()

  func extend() {
    var game = Game()
    let leaf = selectLeaf(game: &game)
    leaf.children = game.extend().map { Node(move: $0.move, score: $0.score) }
  }

  func selectLeaf(game: inout Game) -> Node {
    var node = root
    var player = Player.first

    while true {
      if let child = selectChild(parent: node, player: player) {
        node = child
        game.make(move: node.move)
        player = if player == .first { .second } else { .first }
      }
    }
    return node
  }

  func selectChild(parent: Node, player: Player) -> Node? {
    guard !parent.children.isEmpty else { return nil }
    let dParentChildren = Double(parent.children.count)

    var selectedChild = parent.children[0]
    let dChildren = Double.init(selectedChild.children.count)
    let dScore = selectedChild.score.double
    var selectedScore = dScore + Game.exploreFactor * sqrt(dParentChildren / dChildren)

    for child in parent.children.dropFirst() {
      let dChildren = Double.init(selectedChild.children.count)
      let dScore = selectedChild.score.double
      let score = dScore + Game.exploreFactor * sqrt(dParentChildren / dChildren)

      if (player == .first && selectedScore < score) || (player == .second && selectedScore > score)
      {
        selectedChild = child
        selectedScore = score
      }
    }
    return selectedChild
  }
}

/// Test Game

struct TestMove: Default {
  init() {}
}

extension Int32: ScoreProtocol {
  init() {
    self = 0
  }
  var double: Double { Double(self) }

}

var tree = SearchTree<TestGame>()
struct TestGame: GameProtocol {
  typealias Move = TestMove
  typealias Score = Int32

  static let exploreFactor = 2.0

  func make(move: Move) {}
  func extend() -> [(move: Move, score: Score)] {
    return []
  }
}

enum Foo {
  case c(Character)
  case b(UInt8)
  case d(String)
  case e([Int])
  case z(Character)
  case x
  case y(Int)
}

print(MemoryLayout<Foo>.size, MemoryLayout<Foo>.alignment)
