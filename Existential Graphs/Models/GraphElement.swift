//
//  GraphElement.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI

protocol GraphElement: AnyObject, Bounded {
	
	var id: ObjectIdentifier { get }
	
	var position: CGPoint { get set }
	
	/// The container that contains this graph element.
	/// - Warning: Don’t modify the value of this property manually.
	var parent: (any GraphElementContainer)! { get set }
	
	var isSelected: Bool { get set }
	
	var isHighlighted: Bool { get set }
	
	var transform: CGAffineTransform { get }
	
	var strokeColor: Color { get }
	
	func removeFromParent()
	
	func isGeometricallyIn(_ path: CGPath) -> Bool
	
	func containsGeometrically(_ point: CGPoint) -> Bool
	
}

protocol GraphElementContainer: AnyObject, Bounded {
	
	var id: ObjectIdentifier { get }
	
	var parent: (any GraphElementContainer)! { get }
	
	/// The direct child literals of this container.
	/// - Warning: Don’t modify the value of this property manually.
	var childLiterals: [Literal] { get set }
	
	/// The direct child cuts of this container.
	/// - Warning: Don’t modify the value of this property manually.
	var childCuts: [Cut] { get set }
	
	func synchronize()
	
	func insert(_ child: any GraphElement)
	
	@discardableResult func remove(_ child: any GraphElement) -> Bool
	
	func contains(_ child: any GraphElement) -> Bool
	
	func containsGeometrically(_ element: any GraphElement) -> Bool
	
}

protocol IterableAbstractGraphElementContainer: Sequence where Iterator == GraphElementContainerIterator {
	
	var allLiterals: Set<Literal> { get }
	
	var allCuts: Set<Cut> { get }
	
}

typealias IterableGraphElementContainer = GraphElementContainer & IterableAbstractGraphElementContainer

struct GraphElementContainerIterator: IteratorProtocol {
	
	private let literals: [Literal]
	
	private let cuts: [Cut]
	
	private var offset = 0
	
	fileprivate init(literals: [Literal], cuts: [Cut]) {
		self.literals = literals
		self.cuts = cuts
	}
	
	mutating func next() -> (any GraphElement)? {
		if self.offset >= self.literals.count + self.cuts.count {
			return nil
		}
		defer {
			self.offset += 1
		}
		if self.offset < self.literals.count {
			return self.literals[self.offset]
		} else {
			return self.cuts[self.offset - self.literals.count]
		}
	}
	
}

fileprivate class ShallowGraphElementContainer: IterableAbstractGraphElementContainer {
	
	let allLiterals: Set<Literal>
	
	let allCuts: Set<Cut>
	
	init(from container: any GraphElementContainer) {
		self.allLiterals = Set(container.childLiterals)
		self.allCuts = Set(container.childCuts)
	}
	
}

extension GraphElement {
	
	func removeFromParent() {
		self.parent.remove(self)
	}
	
	func isGeometricallyIn(_ path: CGPath) -> Bool {
		return self.frame
			.applying(self.transform)
			.allVerticesSatisfy { (vertex) in
				return path.contains(vertex)
			}
	}
	
}

extension GraphElementContainer {
	
	var shallow: some IterableAbstractGraphElementContainer {
		return ShallowGraphElementContainer(from: self)
	}
	
	func insert(_ child: any GraphElement) {
		if let oldParent = child.parent {
			let removalDidSucceed = oldParent.remove(child)
			assert(removalDidSucceed)
		}
		child.parent = self
		if let literal = child as? Literal {
			self.childLiterals.append(literal)
		} else if let cut = child as? Cut {
			self.childCuts.append(cut)
		} else {
			fatalError("New child is neither a literal nor a cut")
		}
		self.synchronize()
	}
	
	func remove(_ child: any GraphElement) -> Bool {
		if let literal = child as? Literal {
			guard let index = self.childLiterals.firstIndex(of: literal) else {
				print("[GraphElementContainer remove(_:)] The specified literal isn’t a direct child of this container")
				return false
			}
			self.childLiterals.remove(at: index)
		} else if let cut = child as? Cut {
			guard let index = self.childCuts.firstIndex(of: cut) else {
				print("[GraphElementContainer remove(_:)] The specified cut isn’t a direct child of this container")
				return false
			}
			self.childCuts.remove(at: index)
		}
		child.parent = nil
		self.synchronize()
		return true
	}
	
	func contains(_ child: any GraphElement) -> Bool {
		if let literal = child as? Literal, self.childLiterals.contains(literal) {
			return true
		} else if let cut = child as? Cut, self.childCuts.contains(cut) {
			return true
		}
		for cut in self.childCuts {
			if cut.contains(child) {
				return true
			}
		}
		return false
	}
	
}

extension IterableAbstractGraphElementContainer {
	
	func makeIterator() -> GraphElementContainerIterator {
		return GraphElementContainerIterator(literals: Array(self.allLiterals), cuts: Array(self.allCuts))
	}
	
}
