//
//  CanvasView.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
	
	enum DrawingState {
		
		case cut
		
	}
	
	@EnvironmentObject private var document: GraphDocument
	
	@EnvironmentObject private var viewState: ViewState
	
	private(set) var viewportSize: CGSize
	
	func makeUIView(context: Context) -> PKCanvasView {
		let canvasView = PKCanvasView()
		canvasView.isOpaque = false
		canvasView.contentSize = self.viewportSize * 1.2
		canvasView.delegate = context.coordinator
		canvasView.drawingPolicy = .pencilOnly
//		canvasView.minimumZoomScale = 0.5
//		canvasView.maximumZoomScale = 2.0
		canvasView.setContentOffset(
			CGPoint(
				x: self.viewportSize.width * 0.1,
				y: self.viewportSize.height * 0.1
			),
			animated: false
		)
		let graphViewController = UIHostingController(
			rootView: GraphView(
				viewportSize: self.viewportSize
			)
		)
		canvasView.insertSubview(graphViewController.view, at: 0)
		let tapGestureRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
		canvasView.addGestureRecognizer(tapGestureRecognizer)
		let longPressGestureRecognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleLongPress(_:)))
		canvasView.addGestureRecognizer(longPressGestureRecognizer)
		let panGestureRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan(_:)))
		panGestureRecognizer.delegate = PanGestureRecognizerDelegate.create(selectedElement: context.coordinator.selectedElementBinding)
		canvasView.addGestureRecognizer(panGestureRecognizer)
		return canvasView
	}
	
	func updateUIView(_ canvasView: PKCanvasView, context: Context) {
		canvasView.tool = self.viewState.inkingTool
	}
	
	func makeCoordinator() -> CanvasViewDelegate {
		return CanvasViewDelegate(graph: self.document.graph)
	}
	
}

final class CanvasViewDelegate: NSObject, PKCanvasViewDelegate {
	
	private let graph: Graph
	
	private var drawingState: CanvasView.DrawingState?
	
	private var timeOfLastLiteralInsertion: Date = .distantPast
	
	private var selectedElement: (any GraphElement)?
	
	var selectedElementBinding: Binding<(any GraphElement)?> {
		get {
			return Binding {
				return self.selectedElement
			} set: { (newValue) in
				self.selectedElement = newValue
			}
			
		}
	}
	
	init(graph: Graph) {
		self.graph = graph
	}
	
	func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
		if canvasView.tool is PKInkingTool {
			self.drawingState = .cut
		}
	}
	
	func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
		switch self.drawingState {
		case .cut:
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				self.drawCut(in: canvasView)
			}
		default:
			break
		}
		self.drawingState = nil
	}
	
	private func drawCut(in canvasView: PKCanvasView) {
		let strokes = canvasView.drawing.strokes
			.enumerated()
			.sorted { (first, second) in
				return first.element.path.creationDate > second.element.path.creationDate
			}
		guard let (offset, stroke) = strokes.first else {
			print("[CanvasViewDelegate drawCut(in:)] Couldn’t get the most recent stroke")
			return
		}
		defer {
			canvasView.drawing.strokes.remove(at: offset)
		}
		let path = stroke.path.sorted { (first, second) in
			return first.timeOffset < second.timeOffset
		}
		guard let firstStrokePoint = path.first, let lastStrokePoint = path.last else {
			print("[CanvasViewDelegate drawCut(in:)] Couldn’t get both the first and the last stroke points")
			return
		}
		let area = stroke.renderBounds.size.area
		guard area > 100 else {
			print("[CanvasViewDelegate drawCut(in:)] Insufficient area (\(area))")
			return
		}
		let endpointsDistance = firstStrokePoint.location.distance(to: lastStrokePoint.location)
		guard endpointsDistance < 20 else {
			print("[CanvasViewDelegate drawCut(in:)] Insufficient distance between stroke endpoints (\(endpointsDistance))")
			return
		}
		let cut = Cut(frame: stroke.renderBounds, transform: stroke.transform)
		for literal in self.graph.allLiterals {
			if cut.intersectsGeometrically(literal) && !cut.containsGeometrically(literal) {
				// The drawn cut intersects a literal that it doesn’t fully contain and is therefore invalidly placed
				print("[CanvasViewDelegate drawCut(in:)] The drawn cut geometrically intersects a literal that it doesn’t fully contain")
				return
			}
		}
		for otherCut in self.graph.allCuts {
			if cut.intersectsGeometrically(otherCut) && !cut.containsGeometrically(otherCut) && !otherCut.containsGeometrically(cut) {
				// The drawn cut intersects another cut that it doesn’t fully contain and that doesn’t fully contain it and is therefore invalidly placed
				print("[CanvasViewDelegate drawCut(in:)] The drawn cut geometrically intersects another cut that it doesn’t fully contain and that doesn’t fully contain it")
				return
			}
		}
		var insertionPairs: Set<InsertionPair> = []
		for element in self.graph {
			if cut.contains(element) {
				// This graph element was already inserted into the cut during a previous loop iteration
				continue
			}
			if cut.containsGeometrically(element) {
				// Find the deepest container that already contains this element and that geometrically contains the cut
				var currentChild: any GraphElement = element
				var currentParent: any GraphElementContainer = element.parent
				while !currentParent.containsGeometrically(cut) {
					guard let oldParent = currentParent as? any GraphElement else {
						fatalError("The current parent isn’t a graph element")
					}
					guard let newParent = currentParent.parent else {
						fatalError("The top-level parent doesn’t geometrically contain this cut")
					}
					currentChild = oldParent
					currentParent = newParent
				}
				if !cut.containsGeometrically(currentChild) {
					// The drawn cut is probably improperly placed on the canvas—for instance, it might intersect several other cuts
					print("[CanvasViewDelegate drawCut(in:)] The drawn cut doesn’t geometrically contain a child of its geometric container an indirect child of which it does geometrically contain")
					return
				}
				assert(currentParent.containsGeometrically(cut))
				assert(currentParent.contains(element))
				insertionPairs.insert(InsertionPair(parent: cut, child: currentChild))
				insertionPairs.insert(InsertionPair(parent: currentParent, child: cut))
			}
		}
		if insertionPairs.isEmpty {
			// Find the deepest cut that geometrically contains the new cut
			var currentParent: any GraphElementContainer = self.graph
			for otherCut in self.graph.allCuts {
				if otherCut.containsGeometrically(cut) && currentParent.contains(otherCut) {
					currentParent = otherCut
				}
			}
			insertionPairs.insert(InsertionPair(parent: currentParent, child: cut))
		}
		for insertionPair in insertionPairs {
			let (parent, child) = insertionPair.values
			parent.insert(child)
		}
	}
	
	@objc func handleTap(_ sender: UITapGestureRecognizer) {
		if let selectedElement = self.selectedElement {
			selectedElement.isSelected = false
			if let cut = selectedElement as? Cut {
				for nestedElement in cut {
					nestedElement.isSelected = false
				}
			}
			self.selectedElement = nil
		} else {
			let location = sender.location(in: sender.view)
			for element in self.graph where element.containsGeometrically(location) {
				if self.selectedElement == nil {
					self.selectedElement = element
				} else if let container = self.selectedElement as? any GraphElementContainer, container.containsGeometrically(element) {
					self.selectedElement = element
				}
			}
			self.selectedElement?.isSelected = true
			if let cut = self.selectedElement as? Cut {
				for nestedElement in cut {
					nestedElement.isSelected = true
				}
			}
		}
	}
	
	@objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
		guard abs(self.timeOfLastLiteralInsertion.timeIntervalSinceNow) > 1 else {
			return
		}
		self.timeOfLastLiteralInsertion = .now
		let literal = Literal(
			"W", // TODO: Let the user specify the letter
			position: sender.location(in: sender.view)
		)
		var deepestContainer: any GraphElementContainer = self.graph
		for cut in self.graph.allCuts {
			if cut.containsGeometrically(literal) && deepestContainer.contains(cut) {
				deepestContainer = cut
			}
		}
		deepestContainer.insert(literal)
	}
	
	@objc func handlePan(_ sender: UIPanGestureRecognizer) {
		switch sender.state {
		case .began:
			if let literal = self.selectedElement as? Literal {
				literal.positionTransaction.begin()
			} else if let cut = self.selectedElement as? Cut {
				cut.positionTransaction.begin()
				for nestedElement in cut {
					if let nestedLiteral = nestedElement as? Literal {
						nestedLiteral.positionTransaction.begin()
					} else if let nestedCut = nestedElement as? Cut {
						nestedCut.positionTransaction.begin()
					}
				}
			}
		case .changed:
			let delta = sender.translation(in: sender.view)
			do {
				//				if let literal = self.selectedElement as? Literal {
				//					try literal.positionTransaction.apply(delta: delta)
				//				} else if let cut = self.selectedElement as? Cut {
				//					try cut.positionTransaction.apply(delta: delta)
				//					for nestedElement in cut {
				//						if let nestedLiteral = nestedElement as? Literal {
				//							try nestedLiteral.positionTransaction.apply(delta: delta)
				//						} else if let nestedCut = nestedElement as? Cut {
				//							try nestedCut.positionTransaction.apply(delta: delta)
				//						}
				//					}
				//				}
				for element in self.graph where element.isSelected {
					if let literal = element as? Literal {
						try literal.positionTransaction.apply(delta: delta)
					} else if let cut = element as? Cut {
						try cut.positionTransaction.apply(delta: delta)
					}
				}
			} catch is TransformationTransactionError {
				print("[CanvasViewDelegate handlePan(_:)] Couldn’t update the element’s position because a transaction error occured")
			} catch let error {
				print(error.localizedDescription)
			}
			let doesNotIntersect = self.graph
				.filter { (element) in
					return !element.isSelected
				}
				.allSatisfy { (element) in
					if let cut = element as? Cut, let selectedElement = self.selectedElement, cut.containsGeometrically(selectedElement) {
						return true
					} else {
						return !self.selectedElement?.intersectsGeometrically(element) ?? false
					}
				}
			guard let selectedElement = self.selectedElement, doesNotIntersect && selectedElement.parent.containsGeometrically(selectedElement) else {
				sender.state = .cancelled
				return
			}
		case .ended:
			if let literal = self.selectedElement as? Literal {
				literal.positionTransaction.end()
			} else if let cut = self.selectedElement as? Cut {
				cut.positionTransaction.end()
				for nestedElement in cut {
					if let nestedLiteral = nestedElement as? Literal {
						nestedLiteral.positionTransaction.end()
					} else if let nestedCut = nestedElement as? Cut {
						nestedCut.positionTransaction.end()
					}
				}
			}
		case .cancelled:
			do {
				if let literal = self.selectedElement as? Literal {
					try literal.positionTransaction.cancel()
				} else if let cut = self.selectedElement as? Cut {
					try cut.positionTransaction.cancel()
					for nestedElement in cut {
						if let nestedLiteral = nestedElement as? Literal {
							try nestedLiteral.positionTransaction.cancel()
						} else if let nestedCut = nestedElement as? Cut {
							try nestedCut.positionTransaction.cancel()
						}
					}
				}
			} catch is TransformationTransactionError {
				print("[CanvasViewDelegate handlePan(_:)] Couldn’t reset the element’t position because a transaction error occured")
			} catch let error {
				print(error.localizedDescription)
			}
		case .possible, .failed:
			break
		@unknown default:
			fatalError()
		}
	}
	
}

fileprivate class PanGestureRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
	
	private static var stored: [PanGestureRecognizerDelegate] = []
	
	@Binding private var selectedElement: (any GraphElement)?
	
	private init(selectedElement: Binding<GraphElement?>) {
		self._selectedElement = selectedElement
		super.init()
	}
	
	static func create(selectedElement: Binding<GraphElement?>) -> PanGestureRecognizerDelegate {
		let panGestureRecognizerDelegate = PanGestureRecognizerDelegate(selectedElement: selectedElement)
		self.stored.append(panGestureRecognizerDelegate)
		return panGestureRecognizerDelegate
	}
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return self.selectedElement == nil
	}
	
}

fileprivate struct InsertionPair: Hashable {
	
	let parent: any GraphElementContainer
	
	let child: any GraphElement
	
	var values: (parent: any GraphElementContainer, child: any GraphElement) {
		get {
			return (parent: self.parent, child: self.child)
		}
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(self.parent.id)
		hasher.combine(self.child.id)
	}
	
	static func == (_ lhs: InsertionPair, _ rhs: InsertionPair) -> Bool {
		return lhs.hashValue == rhs.hashValue
	}
	
}
