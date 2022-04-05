//
//  OutlineView.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 3/18/22.
//

import SwiftUI

struct OutlineView: View {
	
	@EnvironmentObject private var document: GraphDocument
	
	var body: some View {
		List {
			OutlineGroup(self.document.graph, children: \.children) { (graphObject) in
				if let literal = graphObject as? Literal {
					Text(literal.character.description)
				} else if graphObject is Cut {
					Text("Cut")
				} else if graphObject is Graph {
					Text("Graph")
				} else {
					Text("Unknown")
				}
			}
		}
	}
	
}

struct TreeViewPreviews: PreviewProvider {
	
	static var previews: some View {
		OutlineView()
			.environmentObject({ () -> GraphDocument in 
				let document = GraphDocument()
				document.graph.insert(Literal("A", position: .zero))
				document.graph.insert(Cut(
					childLiterals: [
						Literal("B", position: .zero),
						Literal("C", position: .zero)
					],
					childCuts: [
						Cut(
							childLiterals: [
								Literal("D", position: .zero)
							],
							childCuts: [
								Cut(
									childLiterals: [
										Literal("E", position: .zero)
									],
									childCuts: [],
									frame: .zero,
									transform: .identity
								)
							],
							frame: .zero,
							transform: .identity
						),
						Cut(
							childLiterals: [],
							childCuts: [],
							frame: .zero,
							transform: .identity
						)
					],
					frame: .zero,
					transform: .identity
				))
				return document
			}())
	}
	
}
