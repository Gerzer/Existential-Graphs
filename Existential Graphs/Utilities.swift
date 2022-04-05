//
//  Utilities.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import Foundation
import Combine
import UIKit
import CoreGraphics
import SwiftUI

enum ModelUtilities {
	
	static func flatten(literals originalLiterals: [Literal], cuts originalCuts: [Cut]) -> (literals: Set<Literal>, cuts: Set<Cut>) {
		var literals = Set(originalLiterals)
		var cuts = Set(originalCuts)
		self.flatten(literals: &literals, cuts: &cuts)
		return (literals: literals, cuts: cuts)
	}
	
	static func flatten(literals: inout Set<Literal>, cuts: inout Set<Cut>) {
		for cut in cuts {
			let oldCutsCount = cuts.count
			literals.formUnion(cut.childLiterals)
			cuts.formUnion(cut.childCuts)
			if cuts.count > oldCutsCount {
				self.flatten(literals: &literals, cuts: &cuts)
			}
		}
	}
	
}

extension Optional where Wrapped == Bool {
	
	static prefix func ! (_ value: Self) -> Self {
		if let value = value {
			return !value
		} else {
			return nil
		}
	}
	
}

extension Binding where Value: ExpressibleByNilLiteral {
	
	static var `default`: Self {
		get {
			return Binding {
				return nil
			} set: { (_) in }
		}
	}
	
}

extension CGPoint: AdditiveArithmetic {
	
	func distance(to other: CGPoint) -> CGFloat {
		return sqrt(pow(other.x - self.x, 2) + pow(other.y - self.y, 2))
	}
	
	public static func + (_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
		return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}
	
	public static func - (_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
		return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
	}
	
}

extension CGSize {
	
	var area: CGFloat {
		get {
			return self.width * self.height
		}
	}
	
	static func * (_ lhs: CGSize, _ rhs: CGFloat) -> CGSize {
		return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
	}
	
}

extension CGRect {
	
	var center: CGPoint {
		get {
			return self.origin + CGPoint(x: self.width / 2, y: self.height / 2)
		}
		set {
			self.origin.x = newValue.x - self.width / 2
			self.origin.y = newValue.y - self.height / 2
		}
	}
	
	func allVerticesSatisfy(_ predicate: (CGPoint) throws -> Bool) rethrows -> Bool {
		let minXMinYDoesSatisfy = try predicate(CGPoint(x: self.minX, y: self.minY))
		let minXMaxYDoesSatisfy = try predicate(CGPoint(x: self.minX, y: self.maxY))
		let maxXMinYDoesSatisfy = try predicate(CGPoint(x: self.maxX, y: self.minY))
		let maxXMaxYDoesSatisfy = try predicate(CGPoint(x: self.maxX, y: self.maxY))
		return minXMinYDoesSatisfy && minXMaxYDoesSatisfy && maxXMinYDoesSatisfy && maxXMaxYDoesSatisfy
	}
	
}
