import Core

extension Module {

  /// Inserts `end_borrow` instructions after the last use of each `borrow` instruction in `f`,
  /// reporting errors and warnings to `diagnostics`.
  ///
  /// - Requires: `f` is in `self`.
  public mutating func closeBorrows(in f: Function.ID, diagnostics: inout DiagnosticSet) {
    for blockToProcess in blocks(in: f) {
      for i in instructions(in: blockToProcess) {
        switch self[i] {
        case let borrow as BorrowInstruction:
          // Compute the live-range of the instruction.
          let borrowResult = Operand.register(i, 0)
          let borrowLifetime = lifetime(of: borrowResult)

          // Delete the borrow if it's never used.
          if borrowLifetime.isEmpty {
            if let decl = borrow.binding {
              diagnostics.insert(.unusedBinding(name: decl.baseName, at: borrow.site))
            }
            removeInstruction(i)
            continue
          }

          // Insert `end_borrow` after the instruction's last users.
          for lastUse in borrowLifetime.maximalElements() {
            insert(
              makeEndBorrow(borrowResult, anchoredAt: self[lastUse.user].site),
              after: lastUse.user)
          }

        default:
          break
        }
      }
    }
  }

  private func lifetime(of operand: Operand) -> Lifetime {
    // Nothing to do if the operand has no use.
    guard let uses = uses[operand] else { return Lifetime(operand: operand) }

    // Compute the live-range of the operand.
    var result = liveRange(of: operand, definedIn: operand.block!)

    // Extend the lifetime with that of its borrows.
    for use in uses {
      switch self[use.user] {
      case is BorrowInstruction:
        let x = lifetime(of: results(of: use.user).uniqueElement!)
        result = extend(lifetime: result, with: x)

      case is ElementAddrInstruction where use.index == 0:
        let x = lifetime(of: results(of: use.user).uniqueElement!)
        result = extend(lifetime: result, with: x)

      default:
        continue
      }
    }

    return result
  }

}

extension Diagnostic {

  fileprivate static func unusedBinding(name: Identifier, at site: SourceRange) -> Diagnostic {
    .warning("binding '\(name)' was never used", at: site)
  }

}