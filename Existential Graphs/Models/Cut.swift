//
//  Cut.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI

class Cut: GraphObject, GraphElement, IterableGraphElementContainer, Unique, Codable {
	
	private enum CodingKeys: CodingKey {
		
		case childLiterals, childCuts, frame, transform
		
	}
	
	var childLiterals: [Literal] {
		didSet {
			self.synchronize()
		}
	}
	
	var childCuts: [Cut] {
		didSet {
			self.synchronize()
		}
	}
	
	private(set) var allLiterals: Set<Literal> = []
	
	private(set) var allCuts: Set<Cut> = []
	
	private(set) var frame: CGRect {
		didSet {
			self.synchronize()
		}
	}
	
	var position: CGPoint {
		get {
			return self.frame.center
		}
		set {
			self.frame.center = newValue
		}
	}
	
	weak var parent: (any GraphElementContainer)!
	
	var isSelected: Bool = false {
		didSet {
			self.synchronize()
		}
	}
	
	var isHighlighted: Bool = false {
		didSet {
			self.synchronize()
		}
	}
	
	private(set) var transform: CGAffineTransform
	
	var strokeColor: Color {
		get {
			return self.isHighlighted ? .yellow : (self.isSelected ? .blue : .primary)
		}
	}
	
	var fillColor: Color {
		get {
			return self.isSelected ? .blue.opacity(0.2) : .clear
		}
	}
	
	var path: CGPath {
		get {
			return CGPath(ellipseIn: self.frame, transform: nil)
		}
	}
	
	lazy var positionTransaction = TransformationTransaction(parent: self, valueKeyPath: \.position)
	
	init(childLiterals: [Literal] = [], childCuts: [Cut] = [], frame: CGRect, transform: CGAffineTransform = .identity) {
		self.childLiterals = childLiterals
		self.childCuts = childCuts
		self.frame = frame
		self.transform = transform
	}
	
	func synchronize() {
		(self.allLiterals, self.allCuts) = ModelUtilities.flatten(literals: self.childLiterals, cuts: self.childCuts)
		self.parent?.synchronize()
	}
	
//	func isGeometricallyIn(_ path: CGPath) -> Bool {
//		self.path.applyWithBlock { (pathElementPointer) in
//			switch pathElementPointer.pointee.type {
//			case .moveToPoint:
//				<#code#>
//			case .addLineToPoint:
//				<#code#>
//			case .addQuadCurveToPoint:
//				<#code#>
//			case .addCurveToPoint:
//				<#code#>
//			case .closeSubpath:
//				<#code#>
//			@unknown default:
//				<#code#>
//			}
//		}
//		return true
//	}
	
	func containsGeometrically(_ point: CGPoint) -> Bool {
		return self.path.contains(point)
	}
	
	func containsGeometrically(_ element: any GraphElement) -> Bool {
		return element.isGeometricallyIn(self.path)
	}
	
}
