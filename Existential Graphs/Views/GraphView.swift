//
//  GraphView.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI

struct GraphView: View {
	
	@EnvironmentObject private var document: GraphDocument
	
	let viewportSize: CGSize
	
	var body: some View {
		ZStack {
			ForEach(Array(self.document.graph.allLiterals)) { (literal) in
				Text(literal.character.description)
					.font(
						.system(
							size: 32,
							weight: .bold,
							design: .serif
						)
					)
					.foregroundColor(literal.strokeColor)
					.position(literal.position)
			}
			ForEach(Array(self.document.graph.allCuts)) { (cut) in
				Ellipse()
					.stroke(cut.strokeColor)
					.background(
						Ellipse()
							.fill(cut.fillColor)
					)
					.frame(width: cut.frame.width, height: cut.frame.height)
					.position(cut.frame.center)
					.transformEffect(cut.transform)
			}
		}
			.foregroundColor(.clear)
			.frame(width: self.viewportSize.width * 1.2, height: self.viewportSize.height * 1.2)
			.position(x: self.viewportSize.width * 0.6, y: self.viewportSize.height * 0.6)
	}
	
}
