//
//  GraphObject.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 3/18/22.
//

import Foundation

class GraphObject: Hashable, Identifiable {
	
	struct ID: Hashable {
		
		private let uuid = UUID()
		
		weak var object: GraphObject?
		
		init(_ object: GraphObject) {
			self.object = object
		}
		
		func hash(into hasher: inout Hasher) {
			hasher.combine(self.uuid)
		}
		
	}
	
	lazy var id = ID(self)
	
	var children: [GraphObject]? {
		get {
			guard let selfAsContainer = self as? GraphElementContainer else {
				return nil
			}
			if selfAsContainer.childLiterals.isEmpty && selfAsContainer.childCuts.isEmpty {
				return nil
			} else {
				return selfAsContainer.childLiterals + selfAsContainer.childCuts
			}
		}
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(self.id)
	}
	
	static func == (_ lhs: GraphObject, _ rhs: GraphObject) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}
	
}
