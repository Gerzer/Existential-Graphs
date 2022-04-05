//
//  ContentView.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI

struct ContentView: View {
	
	@State private var doShowOutline = true
	
	@State private var doHighlightCanvasView = false
	
	@EnvironmentObject private var document: GraphDocument
	
	var body: some View {
		HStack {
			if self.doShowOutline {
				OutlineView(doHighlightCanvasView: self.$doHighlightCanvasView)
					.frame(width: 300)
					.padding(.top)
				Divider()
			}
			GeometryReader { (geometry) in
				CanvasView(viewportSize: geometry.size)
			}
				.overlay {
					RoundedRectangle(cornerRadius: 10, style: .continuous)
						.stroke(self.doHighlightCanvasView ? .yellow : .clear)
						.padding(.trailing)
				}
		}
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Toggle(isOn: self.$doShowOutline) {
						Label("Toggle Outline", systemImage: "sidebar.left")
					}
						.toggleStyle(.button)
				}
			}
	}
	
}

struct ContentViewPreviews: PreviewProvider {
	
	static var previews: some View {
		ContentView()
			.environmentObject(GraphDocument())
			.environmentObject(ViewState())
	}
	
}
