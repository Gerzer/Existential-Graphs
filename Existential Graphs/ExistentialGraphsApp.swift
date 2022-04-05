//
//  ExistentialGraphsApp.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import SwiftUI

@main struct ExistentialGraphsApp: App {
	
	var body: some Scene {
		DocumentGroup {
			return GraphDocument()
		} editor: { (file) in
			ContentView()
				.environmentObject(file.document)
				.environmentObject(ViewState())
		}
	}
	
}
