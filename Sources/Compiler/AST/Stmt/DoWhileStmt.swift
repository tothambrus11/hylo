/// A do-while loop.
public struct DoWhileStmt: Stmt {

  public var range: SourceRange?

  /// The body of the loop.
  public var body: BraceStmt

  /// The condition of the loop.
  ///
  /// - Note: The condition is evaluated in the lexical scope of the body.
  public var condition: Expr

  public func accept<V: StmtVisitor>(_ visitor: inout V) -> V.Result {
    visitor.visit(doWhile: self)
  }

}

extension DoWhileStmt: CustomStringConvertible {

  public var description: String {
    "do \(body) while \(condition)"
  }

}
