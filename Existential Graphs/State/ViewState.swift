//
//  ViewState.swift
//  Existential Graphs
//
//  Created by Gabriel Jacoby-Cooper on 2/14/22.
//

import Combine
import PencilKit

final class ViewState: ObservableObject {
	
	@Published var inkingTool = PKInkingTool(.pen)
	
}
