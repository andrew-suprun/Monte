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
  class Node: CustomStringConvertible {
    var move: Game.Move
    var score: Float
    var children = [Node]()
    var nDescendants: Float

    convenience init() {
      self.init(move: Game.Move(player: .second, score: 0))
    }

    init(move: Game.Move) {
      self.move = move
      self.score = move.score
      nDescendants = 0
    }
  
    var description: String {
      return "\(move) node-score: \(score) children: \(children.count) descendants: \(nDescendants)"
    }
  }

  var root = Node()

  func extend() {
    var game = Game()
    let path = selectPath(game: &game)
    // print("\nselected path:")
    // for node in path {
    //   print(node)
    // }
    // print()
    let leaf = path.last!
    let moves = game.extend()
    assert(!moves.isEmpty)
    let descendats = Float(moves.count)
    leaf.children = moves.map { Node(move: $0) }

    for node in path {
      node.nDescendants += descendats
    }

    for node in path.reversed() {
      if node.move.player == .first {
        if node.children.count > 1 {
          node.score = node.children.min {$0.score < $1.score }!.score
        } else {
          node.score = node.children[0].score
        } 
      } else {
        if node.children.count > 1 {
          node.score = node.children.max {$0.score < $1.score }!.score
        } else {
          node.score = node.children[0].score
        } 
      }
    }
  }

  func selectPath(game: inout Game) -> [Node] {
    var node = root
    var path = [Node]()

    while true {
      path.append(node)
      if let child = selectChild(parent: node) {
        node = child
        game.make(move: node.move)
      } else {
        return path
      }
    }
  }

  func selectChild(parent: Node) -> Node? {
    guard !parent.children.isEmpty else { return nil }
    let parentDescendants = log(parent.nDescendants)
    var selectedChild = parent.children[0]
    if selectedChild.children.isEmpty {
      return selectedChild
    }
    var selectedScore = selectedChild.score + Game.exploreFactor * sqrt(parentDescendants / selectedChild.nDescendants)

    for child in parent.children.dropFirst() {
      if child.children.isEmpty {
        return child
      }
      let score = child.score + Game.exploreFactor * sqrt(parentDescendants / child.nDescendants)

      if (parent.move.player == .first && selectedScore < score) || (parent.move.player == .second && selectedScore > score) {
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
    print(node)
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
    for _ in 1...Int.random(in: 2...5) {
      let score =
        if currentPlayer == .first { Float(Int.random(in: 10...20)) } else {
          -Float(Int.random(in: 10...20))
        }
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
    return "move-id: \(id): player: \(player) move-score: \(score)"
  }
}

var tree = SearchTree<TestGame>()
for _ in 1...20 {
  // tree.debug()
  tree.extend()
}
