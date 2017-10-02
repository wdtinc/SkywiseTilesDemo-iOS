//
//  SwarmTileOverlay.swift
//  Weather Radio
//
//  Created by Justin Greenfield on 4/22/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation
import MapKit


public final class Atomic<T> {
	private let lock = DispatchSemaphore(value: 1)
	private var _value: T
	
	public init(value initialValue: T) {
		_value = initialValue
	}
	
	public var value: T {
		get {
			lock.wait(); defer { lock.signal() }
			return _value
		}
		set {
			lock.wait(); defer { lock.signal() }
			_value = newValue
		}
	}
}


@objc open class SwarmOverlay: MKTileOverlay {
	
	let tileQueue = OperationQueue.queue(concurrentCount: 4)
	
	let dateFormatter = DateFormatter.swarmDateFormatter()
	
	enum ValidTimesError : Error { case nonsenseResponse }
	
	fileprivate let compositeFormat = "swarmweb/comptile/%lu/%lu/%lu.png?LAYERS=%@&TIMES=%@%@"
	fileprivate let tileFormat = "swarmweb/tile/%@/%@/%lu/%lu/%lu.png%@"
	fileprivate let validFramesFormat = "swarmweb/valid_frames?format=json&products=%@"

	let manager = SwarmManager.sharedManager
	
	let name: String
	let baseLayerName: String
	let style: String

	@objc dynamic open fileprivate(set) var frameDate: Date? = nil
	@objc dynamic open fileprivate(set) var latestDate: Date? = nil
	
	@objc open var animating: Bool { return frameTimer != nil || pendingFetch != nil }

	open var alpha: CGFloat = 1.0
	open var debug: Bool = false
	open var dwellCount: Int = 3
	
	open var loopZoomOffset = 0 { didSet { if loopZoomOffset < 0 { loopZoomOffset = 0 } } }
	
	internal var currentFrameTimestamp: String {
		let times = loopTimes.value
		return (index < times.count) ?  times[index] : ""
	}
	
	fileprivate var timestamp: String? = nil
	
	fileprivate var baseTimestamp: String {
		let times = loopTimes.value
		guard let validTimes = validTimes as? [String:AnyObject] else { return "" }
		var baseTimes:[String] = Array((validTimes[baseLayerName] as! [String]).suffix(times.count))
		return baseTimes[index]
	}
	
	fileprivate var frameDwell: Int = 3
	
	fileprivate var updateTimer: Timer? = nil
	fileprivate var frameTimer: Timer? = nil

	fileprivate var pendingFetch: Operation? = nil
	
	fileprivate var index: Int = 0 {
		didSet {
			let timeString = baseTimestamp
			frameDate = dateFormatter.date(from: timeString)
		}
	}
	
	fileprivate var compositeTile: Bool = false
	
	fileprivate let renderedImageCache = NSCache<AnyObject, AnyObject>()
	
	fileprivate var validTimes: AnyObject? = nil
	fileprivate var loopTimes: Atomic<[String]> = Atomic(value: []) {
		didSet { index = loopTimes.value.count }
	}

	internal(set) var zoomScale: MKZoomScale = 0.0
	internal(set) var contentScale: CGFloat = 1.0

	override init(urlTemplate URLTemplate: String?) {
		manager.assertSetup()
		self.name = SwarmBaseLayer.radar.description
		self.baseLayerName = SwarmBaseLayer.radar.description
		self.style = ""
		super.init(urlTemplate: nil)
	}
	
	public init(name: String) {
		manager.assertSetup()
		self.name = name
		self.baseLayerName = name
		self.style = ""
		self.compositeTile = name.components(separatedBy: ",").count > 1
		super.init(urlTemplate: nil)
	}
	
	public init(name: String, baseLayer: String, style: String) {
		manager.assertSetup()
		self.name = name
		self.baseLayerName = baseLayer
		self.style = style
		self.compositeTile = name.components(separatedBy: ",").count > 1
		super.init(urlTemplate: nil)
	}
	
	deinit {
		frameTimer?.invalidate(); frameTimer = nil
		updateTimer?.invalidate(); updateTimer = nil
	}
}


extension SwarmOverlay {
	
	fileprivate var stylesQuery: String { return (style.characters.count > 0) ? ("&STYLES=" + style) : ""  }
	fileprivate var styleParm: String {  return (style.characters.count > 0) ? ("?STYLE=" + style) : "" }
	
	func urlForSwarmCompositeTile(_ path: MKTileOverlayPath, timestamp: String? = nil) -> String {
		return manager.authentication.baseURL + String(format: compositeFormat, path.z, path.x, path.y, name, timestamp ?? self.timestamp!, stylesQuery)
	}
	
	func urlForSwarmTile(_ path: MKTileOverlayPath, timestamp: String? = nil) -> String {
		return manager.authentication.baseURL + String(format: tileFormat, name, timestamp ?? self.timestamp!, path.z, path.x, path.y, styleParm)
	}
	
	func urlForTile(_ path: MKTileOverlayPath, timestamp: String? = nil) -> URL {
		return compositeTile ? URL(string: urlForSwarmCompositeTile(path, timestamp: timestamp))! : URL(string: urlForSwarmTile(path, timestamp:	timestamp))!
	}
	
	func downloadTileAtURL(_ url: URL, result: @escaping (NSError?)->Void) {
		tileQueue.addOperation(downloadOperation(url) { result($1) })
	}

	func downloadOperation(_ url: URL, completionBlock:@escaping (UIImage?, NSError?)->Void) -> Operation {
		var urlRequest = URLRequest(url: url)
		urlRequest.setValue(manager.userAgent, forHTTPHeaderField: "User-Agent")

		let operation = SwarmDownloadOperation()
		
		let urlTask = manager.session.dataTask(with: urlRequest) { [weak operation] (responseData, urlResponse, error) in
			defer { operation?.operationDone() }
			guard let data = responseData, let response = urlResponse as? HTTPURLResponse, let image = UIImage(data: data), error == nil && response.statusCode == 200 else {
				if let error = error as NSError?, error.code != NSURLErrorCancelled {
					//cache error here so we don't keep requesting tile (-999 is cancelled operation, that's okay)
					self.manager.cacheError(url, error: error)
				}
				completionBlock(nil, error as NSError?)
				return
			}
			self.manager.cache.setObject(image, forKey: url as AnyObject)
			completionBlock(image, nil)
		}
		operation.task = urlTask
		return operation
	}
	
	func processValidTimesForAnimation(_ numFrames: Int = 6) -> [String] {
		guard
			let validTimes = validTimes as? [String:AnyObject],
			let baseTimes = validTimes[self.baseLayerName] as? [String]
		else { return [] }
		
		let frames = min(numFrames, baseTimes.count)
		
		let layerKeys = Array(validTimes.keys).filter { $0 != self.baseLayerName }
		
		var keyedTimes = [String: [String]]()
		let radarDates = baseTimes.map { dateFormatter.date(from: $0)! } .suffix(frames)

		latestDate = radarDates.last

		keyedTimes[baseLayerName] = Array((validTimes[baseLayerName] as! [String]).suffix(frames).reversed())
		
		layerKeys.forEach { layerName in
			
			guard let prodDates = (validTimes[layerName] as? [String])?.map({ dateFormatter.date(from: $0)! }) else { return }
			
			let matchedDates: [String] = radarDates.map { radarDate in
				return prodDates.filter { radarDate.timeIntervalSince($0) >= 0.0 }.last ?? prodDates[0]
			}.map { dateFormatter.string(from: $0) }
			keyedTimes[layerName] = Array(matchedDates.suffix(frames).reversed())
		}
		
		let times:[String] = (0 ..< frames).map { i in
			let t: [String] = self.name.components(separatedBy: ",").map { (layer) in
				let layerTimes = keyedTimes[layer]!
				return layerTimes[i]
			}
			return t.joined(separator: ",")
		}
		return Array(times.reversed())
	}
	
	func cancelLoading() {
		tileQueue.cancelAllOperations()
		pendingFetch = nil
	}
	
	func downloadTiles(_ mapRect: MKMapRect, renderFrames: Bool, finishedBlock:@escaping ()->Void) -> Progress {
		let zoomLevelOffset = renderFrames ? loopZoomOffset : 0
		let zoomLevel = (zoomScale > 0) ? max(zoomScale.zoomLevel - zoomLevelOffset, 0) : 0
		
		let paths = tilePaths(mapRect, zoomLevel: zoomLevel, contentScale: contentScale)
		
		if pendingFetch != nil {
			cancelLoading()
		}
		renderedImageCache.removeAllObjects()
		
		var operations = [Operation]()
		let progress = Progress()
		
		let loopCache = NSCache<AnyObject, AnyObject>()
		let times = loopTimes.value
		
		progress.becomeCurrent(withPendingUnitCount: 1)
		let finishedProgress = Progress(totalUnitCount: 1)
		let finishedOperation = BlockOperation {
			times.forEach { [weak self] timestamp in
				guard let strongSelf = self, renderFrames else { return }
				if let image = loopCache.object(forKey: timestamp as AnyObject) as? UIImage {
					strongSelf.renderedImageCache.setObject(image, forKey: timestamp as AnyObject)
				}
			}
			onMainQueue {
				finishedProgress.completedUnitCount = 1
				finishedBlock()
			}
		}
		progress.resignCurrent()
		
		pendingFetch = finishedOperation
		
		times.forEach { loopTime in
			let frameReady = BlockOperation {
				guard renderFrames else { return }
				let compositor = SwarmCompositor(overlay: self, mapRect: mapRect)
				let image = compositor.image(loopTime, paths: paths)
				loopCache.setObject(image, forKey: loopTime as AnyObject)
			}
			let urls = paths.map { urlForTile($0, timestamp: loopTime) }.filter { manager.cache.object(forKey: $0 as AnyObject) == nil }
			
			let swarmOps:[Operation] = urls.map { (url) in
				progress.becomeCurrent(withPendingUnitCount: 1)

				let opProgress = Progress(totalUnitCount: 1)
				let operation = downloadOperation(url) {_,_ in
					onMainQueue { opProgress.completedUnitCount = opProgress.completedUnitCount + 1 }
				}
				progress.resignCurrent()
				return operation
			}
			swarmOps.forEach { frameReady.addDependency($0); operations.append($0) }
			operations.append(frameReady)
			finishedOperation.addDependency(frameReady)
		}
		progress.totalUnitCount = Int64(operations.count - times.count + 1)
		operations.append(finishedOperation)
		
		tileQueue.addOperations(operations, waitUntilFinished: false)
		return progress
	}
}

extension SwarmOverlay {

	var isTimestampValid: Bool { return currentFrameTimestamp.characters.count > 0 }
	
	@objc public func queryTimes(_ completionBlock:@escaping (_ dataAvailable: Bool, _ error: NSError?)->Void) {
		manager.assertSetup()
		
		guard
			let urlRequest = manager.authentication.authenticatedURLRequest(forURL: String(format:validFramesFormat, name))
		else { completionBlock(false, malformedURLError); return }
		
		let task = manager.session.dataTask(with: urlRequest, completionHandler: { (data, response, error) in
			do {
				
				guard
					let data = data,
					let JSON = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:AnyObject], error == nil && (response as? HTTPURLResponse)?.statusCode == 200
				else { throw ValidTimesError.nonsenseResponse }
				
				let oldLoopTimes = self.loopTimes.value
				
				self.validTimes = JSON as AnyObject?
				self.timestamp = self.name.components(separatedBy: ",")
					.map { return (JSON[$0] as? [String])?.last ?? "" }
					.joined(separator: ",")
				self.loopTimes.value = self.processValidTimesForAnimation()
				
				onMainQueue {  completionBlock((oldLoopTimes != self.loopTimes.value), nil) }
			}
			catch {
				let httpError = (response as? HTTPURLResponse)?.errorValue ?? self.validtimesResponseError
				onMainQueue { completionBlock(false, httpError) }
			}
		}) 
		task.resume()
	}
	
	@objc public func fetchTilesForAnimation(_ mapRect: MKMapRect, readyBlock: @escaping (()->Void)) -> Progress {
		return downloadTiles(mapRect, renderFrames: false, finishedBlock: readyBlock)
	}

	public func fetchFramesForAnimation(_ mapRect: MKMapRect, readyBlock: @escaping (()->Void)) -> Progress {
		return downloadTiles(mapRect, renderFrames: true, finishedBlock: readyBlock)
	}
	
	@objc public func startUpdating(_ now: Bool = false, block: @escaping (Bool, NSError?)->Void) {
		updateTimer?.invalidate()
		updateTimer = Timer.repeatingBlockTimer(60.0) { [weak self] in
			self?.queryTimes(block)
		}
		if now { updateTimer?.fire() }
	}
	
	@objc public func stopUpdating() { updateTimer?.invalidate(); updateTimer = nil }
	
	@objc public func startAnimating(_ onFrameChanged: @escaping ((UIImage?)->Void)) {
		frameTimer?.invalidate()
		frameTimer = Timer.repeatingBlockTimer(0.4) { [weak self] in
			guard let strongSelf = self else { return }
			let times = strongSelf.loopTimes.value
			var nextFrame = strongSelf.index + 1
			
			if (nextFrame >= times.count) {
				strongSelf.frameDwell = strongSelf.frameDwell + 1
				if strongSelf.frameDwell < strongSelf.dwellCount {
					return
				}
			}
			
			if nextFrame >= times.count { strongSelf.frameDwell = 0; nextFrame = 0 }
			strongSelf.index = nextFrame
			
			onFrameChanged(strongSelf.renderedImageCache.object(forKey: strongSelf.currentFrameTimestamp as AnyObject) as? UIImage)
		}
	}
	
	@objc public func stopAnimating(jumpToLastFrame: Bool = false) {
		frameTimer?.invalidate(); frameTimer = nil
		cancelLoading()
		if jumpToLastFrame {frameDwell = dwellCount; index = loopTimes.value.count - 1 }
	}
	
	@objc public func pauseForMove() {
		guard animating else { return }
		frameTimer?.fireDate = Date.distantFuture
	}
	
	@objc public func unpauseForMove(_ block:()->Void) {
		guard animating else { return }
		block()
	}
}

extension SwarmOverlay {
	var malformedURLError: NSError { return NSError(domain: String(describing: SwarmOverlay.self), code: 6512, userInfo: [NSLocalizedDescriptionKey:"Malformed URL"]) }
	var validtimesResponseError: NSError { return NSError(domain: String(describing: SwarmOverlay.self), code: 6513, userInfo:[NSLocalizedDescriptionKey:"Couldn't understand response"]) }
}

