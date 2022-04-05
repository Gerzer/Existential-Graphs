//
//  Bounded.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 3/16/22.
//

import CoreGraphics

protocol Bounded {
	
	var frame: CGRect { get }
	
	func intersectsGeometrically(_ other: any Bounded) -> Bool
	
}

extension Bounded {
	
	func intersectsGeometrically(_ other: any Bounded) -> Bool {
		return self.frame.intersects(other.frame)
	}
	
}
