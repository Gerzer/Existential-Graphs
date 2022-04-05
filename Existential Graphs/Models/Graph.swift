//
//  Graph.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI
import UniformTypeIdentifiers
import LogicParser

class Graph: GraphObject, IterableGraphElementContainer, Sequence, Codable {
	
	private enum CodingKeys: CodingKey {
		
		case childLiterals, childCuts
		
	}
	
	private(set) var parent: (any GraphElementContainer)!
	
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
	
	let frame: CGRect = .infinite
	
	fileprivate weak var document: GraphDocument!
	
	private(set) var isLoading: Bool = false
	
	init(isLoading: Bool = false) {
		self.childLiterals = []
		self.childCuts = []
		self.isLoading = isLoading
	}
	
	fileprivate static func setParent(of element: any GraphElement, to parent: any GraphElementContainer) {
		element.parent = parent
		if let cut = element as? Cut {
			for childElement in cut.shallow {
				self.setParent(of: childElement, to: cut)
			}
		}
	}
	
	func synchronize() {
		(self.allLiterals, self.allCuts) = ModelUtilities.flatten(literals: self.childLiterals, cuts: self.childCuts)
		self.document?.objectWillChange.send()
	}
	
	func containsGeometrically(_: any GraphElement) -> Bool {
		return true
	}
	
	func removeAllHighlighting() {
		for element in self {
			element.isHighlighted = false
		}
	}
	
}

final class GraphDocument: NSObject, ReferenceFileDocument, XMLParserDelegate {
	
	static let readableContentTypes: [UTType] = [.bram, .existentialGraph]
//	static let readableContentTypes: [UTType] = [.existentialGraph]
	
	let graph: Graph
	
	override init() {
		self.graph = Graph()
		super.init()
		self.graph.document = self
	}
	
	required init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		switch configuration.contentType {
		case .bram:
			self.graph = Graph()
			super.init()
			self.graph.document = self
			let parser = XMLParser(data: data)
			parser.delegate = BramXMLParserDelegate.create(for: self.graph)
			parser.parse()
		case .existentialGraph:
			let decoder = JSONDecoder()
			self.graph = try decoder.decode(Graph.self, from: data)
			super.init()
			self.graph.document = self
			for element in self.graph.shallow {
				Graph.setParent(of: element, to: self.graph)
			}
			self.graph.synchronize()
		default:
			throw CocoaError(.fileReadCorruptFile)
		}
	}
	
	func fileWrapper(snapshot: Graph, configuration: WriteConfiguration) throws -> FileWrapper {
		let encoder = JSONEncoder()
		let data = try encoder.encode(self.graph)
		return FileWrapper(regularFileWithContents: data)
	}
	
	func snapshot(contentType: UTType) throws -> Graph {
		return self.graph
	}
	
}

fileprivate final class BramXMLParserDelegate: NSObject, XMLParserDelegate {
	
	private enum Element: String {
		
		case bram = "bram"
		
		case program = "Program"
		
		case version = "Version"
		
		case metadata = "metadata"
		
		case author = "author"
		
		case created = "created"
		
		case modified = "modifiefd"
		
		/// - Note: In the dotBram spec, `"hash"` is deprecated.
		case hash = "hash"
		
		case proof = "proof"
		
		case assumption = "assumption"
		
		case raw = "raw"
		
		/// - Note: In the dotBram spec, `"sen"` is deprecated in favor of `"raw"`.
		case sentence = "sen"
		
		case step = "step"
		
		case rule = "rule"
		
		case premise = "premise"
		
		case goal = "goal"
		
	}
	
	private enum ParsingState {
		
		case waitingForFirstAssumption
		
		case waitingForFirstRawInFirstAssumption
		
		case inFirstRawInFirstAssumption
		
		case finishedFirstRawInFirstAssumption
		
		case finishedFirstAssumption
		
	}
	
	private static var store: [BramXMLParserDelegate] = []
	
	private let graph: Graph
	
	private var parsingState: ParsingState = .waitingForFirstAssumption
	
	private var elementPath: [Element] = []
	
	private var stringData = ""
	
	private init(for graph: Graph) {
		self.graph = graph
	}
	
	static func create(for graph: Graph) -> BramXMLParserDelegate {
		let delegate = BramXMLParserDelegate(for: graph)
		self.store.append(delegate)
		return delegate
	}
	
	static func remove(_ delegate: BramXMLParserDelegate) {
		self.store.removeAll { (candidate) in
			return candidate == delegate
		}
	}
	
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
		guard let element = Element(rawValue: elementName) else {
			print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid dotBram element name")
			return
		}
		switch element {
		case .bram:
			guard self.elementPath.count == 0 else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “bram“ tag")
				return
			}
		case .program:
			guard self.elementPath.count == 1, self.elementPath.last == .bram else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “Program“ tag")
				return
			}
		case .version:
			guard self.elementPath.count == 1, self.elementPath.last == .bram else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “Version“ tag")
				return
			}
		case .metadata:
			guard self.elementPath.count == 1, self.elementPath.last == .bram else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “metadata“ tag")
				return
			}
		case .author:
			guard self.elementPath.count == 2, self.elementPath.last == .metadata else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “author“ tag")
				return
			}
		case .created:
			guard self.elementPath.count == 2, self.elementPath.last == .metadata else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “created“ tag")
				return
			}
		case .modified:
			guard self.elementPath.count == 2, self.elementPath.last == .metadata else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “modified“ tag")
				return
			}
		case .hash:
			guard self.elementPath.count == 2, self.elementPath.last == .metadata else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “hash“ tag")
				return
			}
			print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Warning: Encountered opening tag for deprecated “hash” element; this element will be ignored")
		case .proof:
			guard self.elementPath.count == 1, self.elementPath.last == .bram else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “proof“ tag")
				return
			}
		case .assumption:
			guard self.elementPath.count == 2, self.elementPath.last == .proof else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “assumption“ tag")
				return
			}
			if self.parsingState == .waitingForFirstAssumption {
				self.parsingState = .waitingForFirstRawInFirstAssumption
			}
		case .raw:
			guard self.elementPath.count == 3, self.elementPath.last == .assumption || self.elementPath.last == .step || self.elementPath.last == .goal else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “raw“ tag")
				return
			}
		case .sentence:
			guard self.elementPath.count == 3, self.elementPath.last == .assumption || self.elementPath.last == .step || self.elementPath.last == .goal else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “sen“ tag")
				return
			}
			print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Warning: Encountered opening tag for deprecated “sen” element; this element will be ignored")
		case .step:
			guard self.elementPath.count == 2, self.elementPath.last == .proof else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “step“ tag")
				return
			}
		case .rule:
			guard self.elementPath.count == 3, self.elementPath.last == .step else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “rule“ tag")
				return
			}
		case .premise:
			guard self.elementPath.count == 3, self.elementPath.last == .step else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “premise“ tag")
				return
			}
		case .goal:
			guard self.elementPath.count == 2, self.elementPath.last == .proof else {
				print("[BramXMLParserDelegate parser(_:didStartElement:namespaceURI:qualifiedName:attributes:)] Error: Invalid location for opening “goal“ tag")
				return
			}
		}
		self.stringData = ""
		self.elementPath.append(element)
	}
	
	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		guard let element = Element(rawValue: elementName) else {
			print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Error: Invalid dotBram element name")
			return
		}
		guard self.elementPath.last == element else {
			print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Error: Encountered a closing tag for an element other than the one that was most recently opened")
			return
		}
		switch element {
		case .hash:
			print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Warning: Encountered closing tag for deprecated “hash” element; this element was ignored")
		case .assumption:
			switch self.parsingState {
			case .waitingForFirstRawInFirstAssumption:
				self.parsingState = .waitingForFirstAssumption
			case .finishedFirstRawInFirstAssumption:
				self.parsingState = .finishedFirstAssumption
			case .waitingForFirstAssumption, .inFirstRawInFirstAssumption:
				print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Error: Invalid location for closing “assumption” tag")
			case .finishedFirstAssumption:
				break
			}
		case .raw:
			switch self.parsingState {
			case .inFirstRawInFirstAssumption:
				// TODO: Parse contents of self.stringData into graph elements
				do {
					let parser = LogicParser(self.stringData)
					let rootNode = try parser.parse()
					let elements = self.buildSubgraph(from: rootNode)
					var literals: [Literal] = []
					var cuts: [Cut] = []
					for element in elements {
						if let literal = element as? Literal {
							literals.append(literal)
						} else if let cut = element as? Cut {
							cuts.append(cut)
						} else {
							print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Warning: Encountered a graph element that’s neither a literal nor a cut")
						}
					}
					self.graph.childLiterals = literals
					self.graph.childCuts = cuts
				} catch let error {
					print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Error: \(error.localizedDescription)")
					return
				}
				self.parsingState = .finishedFirstRawInFirstAssumption
			case .waitingForFirstAssumption, .waitingForFirstRawInFirstAssumption:
				print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Error: Invalid location for closing “raw” tag")
			case .finishedFirstRawInFirstAssumption, .finishedFirstAssumption:
				break
			}
		case .sentence:
			print("[BramXMLParserDelegate parser(_:didEndElement:namespaceURI:qualifiedName:)] Warning: Encountered closing tag for deprecated “sen” element; this element was ignored")
		case .bram, .program, .version, .metadata, .author, .created, .modified, .proof, .step, .rule, .premise, .goal:
			break
		}
		self.stringData = ""
		self.elementPath.removeLast()
	}
	
	func parser(_ parser: XMLParser, foundCharacters string: String) {
		self.stringData += string
	}
	
	private func buildSubgraph(from logicNode: any LogicNode) -> [any GraphElement] {
		switch logicNode {
		case let rootNode as RootNode:
			guard let childNode = rootNode.left else {
				// TODO: Handle error case more explicitly
				return []
			}
			return self.buildSubgraph(from: childNode)
		case let atomicNode as AtomicNode:
			// TODO: Set position properly
			return [Literal(atomicNode.character, position: .zero)]
		case let negationNode as NegationNode:
			guard let childNode = negationNode.right else {
				// TODO: Handle error case more explicitly
				return []
			}
			
			// TODO: Set frame properly
			let cut = Cut(frame: .zero)
			
			let children = self.buildSubgraph(from: childNode)
			for child in children {
				cut.insert(child)
			}
			return [cut]
		case let conjunctionNode as ConjunctionNode:
			guard let childNode1 = conjunctionNode.left, let childNode2 = conjunctionNode.right else {
				// TODO: Handle error case more explicitly
				return []
			}
			return self.buildSubgraph(from: childNode1) + self.buildSubgraph(from: childNode2)
		case let disjunctionNode as DisjunctionNode:
			guard let childNode1 = disjunctionNode.left, let childNode2 = disjunctionNode.right else {
				// TODO: Handle error case more explicitly
				return []
			}
			
			// TODO: Set frames properly
			let outerCut = Cut(frame: .zero)
			let innerCut1 = Cut(frame: .zero)
			let innerCut2 = Cut(frame: .zero)
			
			let children1 = self.buildSubgraph(from: childNode1)
			let children2 = self.buildSubgraph(from: childNode2)
			for child in children1 {
				innerCut1.insert(child)
			}
			for child in children2 {
				innerCut2.insert(child)
			}
			outerCut.insert(innerCut1)
			outerCut.insert(innerCut2)
			return [outerCut]
		case let conditionalNode as ConditionalNode:
			guard let childNode1 = conditionalNode.left, let childNode2 = conditionalNode.right else {
				// TODO: Handle error case more explicitly
				return []
			}
			
			// TODO: Set frames properly
			let outerCut = Cut(frame: .zero)
			let innerCut = Cut(frame: .zero)
			
			let children1 = self.buildSubgraph(from: childNode1)
			let children2 = self.buildSubgraph(from: childNode2)
			for child in children1 {
				outerCut.insert(child)
			}
			for child in children2 {
				innerCut.insert(child)
			}
			outerCut.insert(innerCut)
			return [outerCut]
		case let biconditionalNode as BiconditionalNode:
			guard let childNode1 = biconditionalNode.left, let childNode2 = biconditionalNode.right else {
				// TODO: Handle error case more explicitly
				return []
			}
			
			// TODO: Set frames properly
			let outerCut1 = Cut(frame: .zero)
			let outerCut2 = Cut(frame: .zero)
			let innerCut1 = Cut(frame: .zero)
			let innerCut2 = Cut(frame: .zero)
			
			let children1 = self.buildSubgraph(from: childNode1)
			let children2 = self.buildSubgraph(from: childNode1)
			let children3 = self.buildSubgraph(from: childNode2)
			let children4 = self.buildSubgraph(from: childNode2)
			for child in children1 {
				outerCut1.insert(child)
			}
			for child in children2 {
				innerCut2.insert(child)
			}
			for child in children3 {
				outerCut2.insert(child)
			}
			for child in children4 {
				innerCut1.insert(child)
			}
			outerCut1.insert(innerCut1)
			outerCut2.insert(innerCut2)
			return [outerCut1, outerCut2]
		default:
			return []
		}
	}
	
}

extension UTType {
	
	static let bram = UTType(exportedAs: "com.bramhub.bram", conformingTo: .xml)
	
	static let existentialGraph = UTType(exportedAs: "com.bramhub.existential-graph", conformingTo: .json)
	
}
