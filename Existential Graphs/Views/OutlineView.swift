//
//  OutlineView.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 3/18/22.
//

import SwiftUI

struct OutlineView: View {
	
	@State private var selection: GraphObject.ID?
	
	@Binding private(set) var doHighlightCanvasView: Bool
	
	@EnvironmentObject private var document: GraphDocument
	
	@Environment(\.editMode) private var editMode
	
	var body: some View {
		ZStack {
			List([self.document.graph], children: \.children, selection: self.$selection) { (object) in
				if let literal = object as? Literal {
					Label(literal.character.description, systemImage: "character.cursor.ibeam")
						.font(
							.system(
								.body,
								design: .serif
							)
							.italic()
						)
						.swipeActions {
							Button("Remove", role: .destructive) {
								literal.removeFromParent()
							}
						}
				} else if let cut = object as? Cut {
					Label("Cut", systemImage: "circle")
						.font(
							.system(
								.body,
								design: .serif
							)
						)
						.swipeActions {
							Button("Remove", role: .destructive) {
								cut.removeFromParent()
							}
						}
				} else if object is Graph {
					Label("Graph", systemImage: "scribble")
						.font(
							.system(
								.body,
								design: .serif
							)
						)
				} else {
					Label("Unknown", systemImage: "questionmark")
						.font(
							.system(
								.body,
								design: .serif
							)
						)
				}
			}
				.padding(.top)
			VStack(alignment: .leading, spacing: 0) {
				HStack {
					Text("Outline")
						.font(
							.system(
								.largeTitle,
								design: .serif
							)
						)
						.bold()
					Spacer()
					EditButton()
				}
					.padding(.horizontal)
					.background(.background)
				Spacer()
			}
		}
			.onChange(of: self.selection) { (newValue) in
				withAnimation {
					self.document.graph.removeAllHighlighting()
					self.doHighlightCanvasView = false
					if let element = newValue?.object as? GraphElement {
						element.isHighlighted = true
					} else if newValue?.object is Graph {
						self.doHighlightCanvasView = true
					}
				}
			}
			.onChange(of: self.editMode?.wrappedValue.isEditing) { (newValue) in
				if !(newValue ?? false) {
					self.selection = nil
				}
			}
			.onDisappear {
				withAnimation {
					self.document.graph.removeAllHighlighting()
					self.doHighlightCanvasView = false
				}
			}
	}
	
}

struct TreeViewPreviews: PreviewProvider {
	
	static var previews: some View {
		OutlineView(doHighlightCanvasView: .constant(false))
			.environmentObject(
				{ () -> GraphDocument in
					let document = GraphDocument()
					document.graph.insert(
						Literal(
							"A",
							position: .zero
						)
					)
					document.graph.insert(
						Cut(
							childLiterals: [
								Literal(
									"B",
									position: .zero
								),
								Literal(
									"C",
									position: .zero
								)
							],
							childCuts: [
								Cut(
									childLiterals: [
										Literal(
											"D",
											position: .zero
										)
									],
									childCuts: [
										Cut(
											childLiterals: [
												Literal(
													"E",
													position: .zero
												)
											],
											frame: .zero,
											transform: .identity
										)
									],
									frame: .zero,
									transform: .identity
								),
								Cut(
									frame: .zero,
									transform: .identity
								)
							],
							frame: .zero,
							transform: .identity
						)
					)
					return document
				}()
			)
	}
	
}
