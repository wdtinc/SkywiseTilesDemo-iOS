//
//  SwarmManager.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/25/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation

@objc open class SwarmManager: NSObject {
	
	@objc open var authentication: Authentication!
	
	@objc open static let sharedManager = SwarmManager()
	
	override fileprivate init() {
		super.init()
	}
	
	let cache = NSCache<AnyObject, AnyObject>()
	let session: URLSession = {
		let sessionConfig = URLSessionConfiguration.default
		sessionConfig.urlCache = URLCache(memoryCapacity: 10*1024*1024, diskCapacity: 15*1024*1025, diskPath: "SwarmCache")
		return URLSession.init(configuration: sessionConfig)
	}()
	
	internal let userAgent = Bundle.main.userAgent
	
	let groups: [[String:String]] = {
		let data = try? Data(contentsOf: URL(fileURLWithPath: Bundle.SwarmBundle.path(forResource: "swarmLayerGroups", ofType: "json")!))
		let groups: [[String:String]] = try! JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [[String:String]]
		return groups
	}()
	
	let mappedAlerts: [String] = {
		let data = try? Data(contentsOf: URL(fileURLWithPath: Bundle.SwarmBundle.path(forResource: "swarmAlertTypes", ofType: "json")!))
		var alerts: [String] = try! JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [String]
		return alerts
	}()
	
	// SwarmGroup accessors for ObjC
	@objc open var layerIdentifiers: [String] { return SwarmBaseLayer.allLayers.map { $0.description } }
	@objc open func localizeLayer(_ identifier: String) -> String {
		let layer = SwarmBaseLayer(string: identifier)
		return SwarmBaseLayer.localize(layer)
	}
	@objc open func layer(_ identifier: String) -> Int {
		return SwarmBaseLayer(string: identifier).rawValue
	}
	@objc open func layerIdentifier(_ baseLayer: Int) -> String {
		return SwarmBaseLayer(rawValue: baseLayer)?.description ?? SwarmBaseLayer.radar.description
	}
	
	@objc open var groupIdentifiers: [String] { return SwarmGroup.allGroups.map { $0.description } }
	@objc open func localizeGroup(_ identifier: String) -> String {
		let group = SwarmGroup(string: identifier)
		return SwarmGroup.localize(group)
	}
	@objc open func group(_ identifier: String) -> Int {
		return SwarmGroup(string: identifier).rawValue
	}
	@objc open func groupIdentifier(_ group: Int) -> String {
		return SwarmGroup(rawValue: group)?.description ?? SwarmGroup.none.description
	}
	
	@objc open var radarOverlay : SwarmOverlay { return overlayForBaseLayer(.radar) }
	@objc open var satelliteOverlay : SwarmOverlay { return overlayForBaseLayer(.satellite) }
	
	@objc open func overlayForBaseLayer(_ layer: SwarmBaseLayer) -> SwarmOverlay {
		assertSetup()
		return SwarmOverlay(name: layer.description, baseLayer: layer.description, style: "")
	}
	
	@objc open func overlayForGroup(_ group: SwarmGroup, baseLayer: SwarmBaseLayer = .radar) -> SwarmOverlay {
		assertSetup()
		let groupId = group.description
		if let matchingGroup = self.groups.filter({ $0["id"] == groupId }).last {
			let name = matchingGroup["layerName"].flatMap { String(format: $0, baseLayer.description)} ?? baseLayer.description
			return SwarmOverlay(name: name, baseLayer: baseLayer.description, style: matchingGroup["layerStyleDefault"] ?? "")
		}
		return overlayForBaseLayer(baseLayer)
	}
	
	@objc open func overlayForType(_ alertType: String, baseLayer: SwarmBaseLayer) -> SwarmOverlay {
		assertSetup()
		if mappedAlerts.contains(alertType) {
			let name = alertType + "," + baseLayer.description + "," + alertType
			let style = "default,default,wapo"
			return SwarmOverlay(name: name, baseLayer: baseLayer.description, style: style)
		} else {
			return overlayForBaseLayer(baseLayer)
		}
	}
	
	fileprivate var errorTimer: Timer? = nil
	
	fileprivate struct URLError: Error {
		let url: URL
		let date: Date
	}
	
	fileprivate var errors = [URLError]()
	
	internal func cacheError(_ url: URL, error: NSError) {
		cache.setObject(error, forKey: url as AnyObject)
		let urlError = URLError(url: url, date: Date())
		onMainQueue {
			self.errors.append(urlError)
			guard self.errorTimer == nil else { return }
			self.errorTimer = Timer.repeatingBlockTimer(30.0) { [weak self] in
				self?.clearErrors()
			}
		}
	}
	
	fileprivate func clearErrors(_ interval: TimeInterval = 45.0) {
		
		let now = Date()
		
		errors
			.filter { (now.timeIntervalSince($0.date)) > interval }
			.forEach { self.cache.removeObject(forKey: $0.url as AnyObject) }
		
		onMainQueue {
			self.errors = self.errors.filter { now.timeIntervalSince($0.date) <= interval }
			if self.errors.isEmpty {
				self.errorTimer?.invalidate()
				self.errorTimer = nil
			}
		}
	}
	
	internal func assertSetup() {
		
		guard authentication != nil else {
			fatalError("ERROR: Skywise authentication has not been set. Get your app ID and key at https://skywise.wdtinc.com.")
		}
	}
}
