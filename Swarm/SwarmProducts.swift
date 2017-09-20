//
//  SwarmProducts.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/5/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation

@objc public enum SwarmBaseLayer: Int { case radar, satellite }

extension SwarmBaseLayer: CustomStringConvertible {
	public var description: String {
		switch self {
		case .radar: return "lowaltradarcontours"
		case .satellite: return "irsatellitegrid"
		}
	}
}

extension SwarmBaseLayer {
	public static func localize(_ layer: SwarmBaseLayer) -> String {
		return NSLocalizedString(layer.description, tableName: "Swarm", bundle: Bundle.SwarmBundle, value: "", comment: "")
	}
	public static var allLayers: [SwarmBaseLayer] {
		var n = 0
		var layers = [SwarmBaseLayer]()
		while let layer = SwarmBaseLayer(rawValue: n) {
			layers.append(layer)
			n += 1
		}
		return layers
	}
	
	var localizedString: String { return SwarmBaseLayer.localize(self) }

	init(string: String) {
		let layers = SwarmBaseLayer.allLayers
		guard let layer = layers.filter({ $0.description == string }).first  else {
			self = .radar
			return
		}
		self = layer
	}
}


@objc public enum SwarmGroup: Int {
	case none, stormAndTornadoes, flood, winter, snow, ice, freezing, fog, fire, wind, hurricaneAndTropical, hurricaneTracks
}

extension SwarmGroup: CustomStringConvertible {
	public var description: String {
		switch self {
		case .none: return "none"
		case .stormAndTornadoes: return "stormandtornadoes"
		case .flood: return "flood"
		case .winter: return "winter"
		case .snow: return "snow"
		case .ice: return "ice"
		case .freezing: return "freezing"
		case .fog: return "fog"
		case .fire: return "fire"
		case .wind: return "wind"
		case .hurricaneAndTropical: return "hurricaneandtropical"
		case .hurricaneTracks: return "hurricanetracks"
		}
	}
}

extension SwarmGroup {

	public static func localize(_ group: SwarmGroup) -> String {
		return NSLocalizedString(group.description, tableName: "Swarm", bundle: Bundle.SwarmBundle, value: "", comment: "")
	}
	
	public static var allGroups: [SwarmGroup] {
		var n = 0
		var groups = [SwarmGroup]()
		while let group = SwarmGroup(rawValue: n) {
			groups.append(group)
			n = n + 1
		}
		return groups
	}

	var localizedString: String { return SwarmGroup.localize(self) }

	init(string: String) {
		let groups = SwarmGroup.allGroups
		guard let group = groups.filter({ $0.description == string }).first  else {
			self = .none
			return
		}
		self = group
	}
}
