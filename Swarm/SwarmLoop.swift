//
//  SwarmLoop.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/13/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation
import MapKit

open class SwarmAnnotation: NSObject, MKAnnotation {
	open dynamic var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
	let overlay: SwarmOverlay
	init(overlay: SwarmOverlay) {
		self.overlay = overlay
		super.init()
	}
}

public extension SwarmOverlay {
	var loopAnnotation: SwarmAnnotation	{ return SwarmAnnotation(overlay: self) }
}

public extension SwarmAnnotation {
	func positionOn(_ mapView: MKMapView) {
		mapView.removeAnnotation(self)
		coordinate = mapView.region.center
		mapView.addAnnotation(self)
	}
}


open class SwarmLoopView: MKAnnotationView {
	
	var swarmOverlay: SwarmOverlay? { return (annotation as? SwarmAnnotation)?.overlay }
	
	open weak var mapView: MKMapView? = nil
	open var swarmImage: UIImage? = nil {
		didSet {
			alpha = swarmOverlay?.alpha ?? 1.0
			imageView.image = swarmImage
		}
	}
	
	let imageView: UIImageView = UIImageView(frame: CGRect())
//	public override init(frame: CGRect) {
//		super.init(frame: frame)
//	}
	
	public override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
		super.init(annotation: nil, reuseIdentifier: "SwarmLoopView")
		backgroundColor = UIColor.clear
		imageView.alpha = 1.0
		addSubview(imageView)
	}
	
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override open func layoutSubviews() {
		super.layoutSubviews()
		if let mapView = mapView {
			let visibleRect = mapView.visibleMapRect
			
			let origin = mapView.convert(visibleRect.northwestCoordinate, toPointTo: mapView)
			let pt =  mapView.convert(visibleRect.southeastCoordinate, toPointTo: mapView)
			let size = CGSize(width: pt.x - origin.x, height: pt.y - origin.y);
			
			var frame = CGRect.zero
			frame.origin = mapView.convert(origin, to: self)
			frame.size = size
//			print(size)
			imageView.frame = frame
		}
	}
	
	override open func draw(_ rect: CGRect) {
		if let swarmOverlay = swarmOverlay, swarmOverlay.debug {
			if let context = UIGraphicsGetCurrentContext() {
				context.setStrokeColor(UIColor.blue.cgColor)
				let rect = bounds
				context.setLineWidth(2.0)
				context.stroke(rect)
				context.move(to: CGPoint(x: 0.0, y: 0.0))
				context.addLine(to: CGPoint(x: rect.width, y: rect.height))
				context.strokePath()
				context.move(to: CGPoint(x: 0.0, y: rect.height))
				context.addLine(to: CGPoint(x: rect.width, y: 0.0))
				context.strokePath()
			}
		}
	}
}

extension MKMapRect {
	func clipRect(_ imageRect: MKMapRect, imageSize: CGSize) -> CGRect {
		let clipX = CGFloat(((origin.x - imageRect.origin.x) / imageRect.size.width) * Double(imageSize.width))
		let clipY = CGFloat(((origin.y - imageRect.origin.y) / imageRect.size.height) * Double(imageSize.height))
		let x2 = CGFloat((((origin.x + size.width) - imageRect.origin.x) / imageRect.size.width) * Double(imageSize.width))
		let y2 = CGFloat((((origin.y + size.height) - imageRect.origin.y) / imageRect.size.height) * Double(imageSize.height))
		return CGRect(x: floor(clipX), y: floor(clipY), width: x2-clipX, height: y2-clipY)
	}
	static func rectFromCoordinates(_ northeast: CLLocationCoordinate2D, southwest: CLLocationCoordinate2D) -> MKMapRect {
		let swTilePoint = MKMapPointForCoordinate(southwest)
		let neTilePoint = MKMapPointForCoordinate(northeast)
		var northeastX = neTilePoint.x
		if (swTilePoint.x > neTilePoint.x) {
			northeastX = neTilePoint.x + MKMapRectWorld.size.width;
		}
		
		return MKMapRect(
			origin: MKMapPoint(x: swTilePoint.x, y: neTilePoint.y),
			size: MKMapSize(width: northeastX - swTilePoint.x, height: swTilePoint.y - neTilePoint.y)
		)
	}
}

class SwarmCompositor {
	
	let swarmOverlay: SwarmOverlay
	let visibleMapRect: MKMapRect
	var tileSize: CGFloat = 256.0
	
	init(overlay: SwarmOverlay, mapRect: MKMapRect) {
		self.swarmOverlay = overlay
		self.visibleMapRect = mapRect
	}
	
	func image(_ timestamp: String, paths: [MKTileOverlayPath]) -> UIImage {
		let z = paths.reduce(0) { $1.z }
		let xpaths = paths.map { $0.x }
		let ypaths = paths.map { $0.y }
		
		let west = xpaths.first!
		let east = xpaths.last!
		let north = ypaths.first!
		let south = ypaths.last!
		
		let worldWidth = Int(pow(Double(2), Double(z)))
		let tiledImageSize = CGSize(width: CGFloat(Set(xpaths).count) * tileSize, height: CGFloat(Set(ypaths).count) * tileSize)
		
		let tileNortheast = MKTileOverlayPath(x: east, y: north, z: z, contentScaleFactor: 1.0).mapRect.northeastCoordinate
		let tileSouthwest = MKTileOverlayPath(x: west, y: south, z: z, contentScaleFactor: 1.0).mapRect.southwestCoordinate
		let tiledMapRect = MKMapRect.rectFromCoordinates(tileNortheast, southwest: tileSouthwest)
		
		let clipRect = visibleMapRect.clipRect(tiledMapRect, imageSize: tiledImageSize)
		
		UIGraphicsBeginImageContext(clipRect.size)
		defer { UIGraphicsEndImageContext() }
		
		let context = UIGraphicsGetCurrentContext()
		
		context?.translateBy(x: -clipRect.origin.x, y: -clipRect.origin.y);

		paths.forEach { (path) in
			let url = swarmOverlay.urlForTile(path, timestamp: timestamp)
			if let image = SwarmManager.sharedManager.cache.object(forKey: url as AnyObject) as? UIImage {
				let x = (path.x < west) ? path.x - west + worldWidth : path.x - west
				let y = path.y - north
				let rect = CGRect(x: CGFloat(x) * tileSize, y: CGFloat(y) * tileSize, width: tileSize, height: tileSize)
				image.draw(in: rect)
				//CGContextStrokeRect(context, rect)
			}
		}
		
		let retImage = UIGraphicsGetImageFromCurrentImageContext()
		
//		let data = UIImagePNGRepresentation(retImage)
//		try! data?.writeToFile("/Users/justin/Desktop/test.png", options: .AtomicWrite)

		return retImage!
	}
}


@objc open class SwarmOverlayCoordinator: NSObject {

	@objc open var animating: Bool { return overlay.animating }
	@objc open var frameDate: Date? { return overlay.frameDate as Date? }

	var alpha: CGFloat = 1.0 {
		didSet {
			overlay.alpha = alpha
			loopView?.alpha = alpha
			renderer.setNeedsDisplay()
		}
	}
	
	@objc open let overlay: SwarmOverlay
	fileprivate weak var mapView: MKMapView? = nil
	
	@objc public init(overlay: SwarmOverlay, mapView: MKMapView) {
		self.overlay = overlay
		self.mapView = mapView
		super.init()
		annotation.positionOn(mapView)
	}
	
	deinit {
		overlay.stopAnimating()
		overlay.stopUpdating()
		mapView?.removeAnnotation(annotation)
		mapView?.remove(overlay)
	}
	
	@objc lazy open var renderer: SwarmTileOverlayRenderer = {
		return SwarmTileOverlayRenderer(overlay: self.overlay)
	}()

	lazy open var annotation: SwarmAnnotation = { self.overlay.loopAnnotation }()
	@objc open fileprivate(set) var loopView: SwarmLoopView? = nil
	
	@objc open func fetchTilesForAnimation(_ mapRect: MKMapRect, readyBlock:@escaping ()->Void) -> Progress {
		return overlay.fetchFramesForAnimation(mapRect, readyBlock: readyBlock)
	}

	@objc open func regionWillChange() {
		overlay.pauseForMove()
		renderer.hidden = false
		if let mapView = mapView {
			annotation.positionOn(mapView)
		}
	}
	
	@objc open func regionDidChange(_ restartAnimation:(()->Void)) {
		overlay.unpauseForMove(restartAnimation)
		if let mapView = mapView {
			annotation.positionOn(mapView)
		}
		renderer.setNeedsDisplay()
	}
	
	@objc open func overlayUpdated(_ restartAnimation:(()->Void)) {
		regionWillChange()
		regionDidChange(restartAnimation)
	}
	
	open func updateImage(_ image:UIImage?) {
		loopView?.swarmImage = image
		renderer.hidden = (image != nil)
	}
	
	@objc open func annotationView(_ frame: CGRect) -> SwarmLoopView {
		let view = mapView?.dequeueReusableAnnotationView(withIdentifier: "SwarmLoopView") as? SwarmLoopView ?? SwarmLoopView(annotation: annotation, reuseIdentifier: "SwarmLoopView")
		view.swarmImage = nil
		view.mapView = mapView
		view.frame = frame
		view.annotation = annotation
		self.loopView = view
		view.layoutSubviews()
		return view
	}
	
	open func stop() {
		overlay.stopUpdating()
		overlay.stopAnimating(jumpToLastFrame: true)
		updateImage(nil)
	}
	
	@objc open func startAnimating(_ onFrameChanged:@escaping ()->Void) {
		overlay.startAnimating { [weak self] (image) in
			self?.updateImage(image)
			onFrameChanged()
		}
	}
	
	@objc open func stopAnimating() {
		overlay.stopAnimating(jumpToLastFrame: true)
		updateImage(nil)
	}
	
	@objc open func startUpdating(_ now: Bool = false, block:@escaping (Bool, NSError?)->()) {
		overlay.startUpdating(now, block: block)
	}
	
	@objc open func stopUpdating() { overlay.stopUpdating() }
}

