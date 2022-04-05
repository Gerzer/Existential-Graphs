//
//  Literal.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI

class Literal: GraphObject, GraphElement, Unique, Codable {
	
	private enum CodingKeys: CodingKey {
		
		case character, position
		
	}
	
	let character: Character
	
	var frame: CGRect {
		get {
			return CGRect(
				origin: CGPoint(
					x: self.position.x - 20,
					y: self.position.y - 20
				),
				size: CGSize(
					width: 40,
					height: 40
				)
			)
		}
	}
	
	var position: CGPoint {
		didSet {
			self.parent.synchronize()
		}
	}
	
	weak var parent: (any GraphElementContainer)!
	
	var isSelected: Bool = false {
		didSet {
			self.parent.synchronize()
		}
	}
	
	var isHighlighted: Bool = false {
		didSet {
			self.parent.synchronize()
		}
	}
	
	let transform: CGAffineTransform = .identity
	
	var strokeColor: Color {
		get {
			return self.isHighlighted ? .yellow : (self.isSelected ? .blue : .primary)
		}
	}
	
	lazy var positionTransaction = TransformationTransaction(parent: self, valueKeyPath: \.position)
	
	init(_ character: Character, position: CGPoint) {
		self.character = character
		self.position = position
	}
	
	func containsGeometrically(_ point: CGPoint) -> Bool {
		return self.frame.contains(point)
	}
	
}
