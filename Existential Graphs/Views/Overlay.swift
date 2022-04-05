//
//  Overlay.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI

struct Overlay: View {
	
	var body: some View {
		Text("Hello, world!")
			.padding()
			.background(
				.regularMaterial,
				in: RoundedRectangle(
					cornerRadius: 10,
					style: .continuous
				)
			)
	}
	
}

struct OverlayPreviews: PreviewProvider {
	
	static var previews: some View {
		Overlay()
	}
	
}
