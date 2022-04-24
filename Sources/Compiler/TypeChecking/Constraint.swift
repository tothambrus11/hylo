import Utils

/// A constraint.
public enum Constraint: Hashable {

  /// A set of constraints in a disjunction.
  public struct Minterm: Hashable {

    /// The constraints.
    public var constraints: [Constraint]

    /// The penalties associated with this set.
    public var penalties: Int

  }

  /// A constraint `L == R` specifying that `L` is exactly the same type as `R`.
  ///
  /// - Note: This constraint is commutative.
  case equality(l: Type, r: Type)

  /// A constraint `L <: R` specifying that `L` is a subtype of `R`.
  case subtyping(l: Type, r: Type)

  /// A constraint `L : T1 & ... & Tn` specifying that `L` conforms to the traits `T1, ..., Tn`.
  case conformance(l: Type, traits: Set<TraitType>)

  /// A constraint `L ⤷ R` specifying that `R` is a parameter type and `L` the type of a compatible
  /// argument.
  ///
  /// - Note: Solving a constraint `l ⤷ R` where `R` is a type variable requires that there be
  ///   another constraint on `R` fixing its parameter passing convention.
  case parameter(l: Type, r: Type)

  /// A size constraint denoting a predicate over size parameters.
  case size(AnyExprID)

  /// A disjunction of two or more constraint sets.
  ///
  /// Each set is associated with a penalty to represent the preferred alternatives.
  case disjunction([Minterm])

  /// Returns whether the constraint depends on the specified variable.
  public func depends(on variable: TypeVariable) -> Bool {
    let v = Type.variable(variable)

    switch self {
    case .equality(let l, let r):
      return (v == l) || (v == r)
    case .subtyping(let l, let r):
      return (v == l) || (v == r)
    case .conformance(let l, _):
      return (v == l)
    case .parameter(let l, let r):
      return (v == l) || (v == r)
    case .size:
      return false
    case .disjunction(let minterms):
      return minterms.contains(where: { m in
        m.constraints.contains(where: { c in c.depends(on: variable) })
      })
    }
  }

  /// Calls `modify` with a projection of the types in the constraint.
  ///
  /// - Parameters:
  ///   - modify: A closure that accepts mutable projections of the types contained in the
  ///     constraint and returns whether visitation should continue. The traits on the right hand
  ///     side of a conformance constraint are not visited.
  /// - Returns: `false` if any call to `modify` returns `false`; otherwise, `true`.
  @discardableResult
  public mutating func modifyTypes(_ modify: (inout Type) -> Bool) -> Bool {
    switch self {
    case .equality(var l, var r):
      defer { self = .equality(l: l, r: r) }
      return modify(&l) && modify(&r)

    case .subtyping(var l, var r):
      defer { self = .subtyping(l: l, r: r) }
      return modify(&l) && modify(&r)

    case .conformance(var l, let traits):
      defer { self = .conformance(l: l, traits: traits) }
      return modify(&l)

    case .parameter(var l, var r):
      defer { self = .parameter(l: l, r: r) }
      return modify(&l) && modify(&r)

    case .size:
      return true

    case .disjunction(var minterms):
      for i in 0 ..< minterms.count {
        for j in 0 ..< minterms[i].constraints.count {
          if !minterms[i].constraints[j].modifyTypes(modify) { return false }
        }
      }
      return true
    }
  }

  /// Returns whether this constraint depends on the specified type variable.

}

extension Constraint: CustomStringConvertible {

  public var description: String {
    switch self {
    case .equality(let l, let r):
      return "\(l) == \(r)"

    case .subtyping(let l, let r):
      return "\(l) <: \(r)"

    case .conformance(let l, let traits):
      let t = String.joining(traits, separator: ", ")
      return "\(l) : \(t)"

    case .parameter(let l, let r):
      return "\(l) ⤷ \(r)"

    case .size:
      return "expr"

    case .disjunction(let sets):
      return String.joining(
        sets.map({ (minterm) -> String in
          let cs = String.joining(minterm.constraints, separator: " ∧ ")
          return "{\(cs)}:\(minterm.penalties)"
        }),
        separator: " ∨ ")
    }
  }

}