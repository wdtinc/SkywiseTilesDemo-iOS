//
//  SwarmTileOverlayRenderer.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/25/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import MapKit

open class SwarmTileOverlayRenderer: MKTileOverlayRenderer {
	
	open var hidden: Bool = false {
		didSet {
			guard oldValue != hidden else { return }
			setNeedsDisplay()
		}
	}
	
	fileprivate var swarmOverlay: SwarmOverlay { return self.overlay as! SwarmOverlay }
	
	override open func canDraw(_ inRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
		let swarm = swarmOverlay
		guard swarm.isTimestampValid else { return false }
		
		swarm.zoomScale = zoomScale
		swarm.contentScale = contentScaleFactor
		
		let rects = inRect.subdivided
		let flags: [Bool] = rects.map { mapRect in
			
			let path = mapRect.pathForZoom(zoomScale, contentScale: contentScaleFactor)
			let timeStamp = swarm.currentFrameTimestamp
			let url = swarm.urlForTile(path, timestamp: timeStamp)
			let object = swarm.manager.cache.object(forKey: url as AnyObject)
			
			if object is UIImage || object is NSError {
				return true
			}
			
			
			swarmOverlay.downloadTileAtURL(url) { [weak self] error in
				//				guard error == nil else { return }
				self?.setNeedsDisplay(inRect, zoomScale: zoomScale)
			}
			return false
		}
		let flag = flags.filter { $0 == false }.count == 0
		return flag
	}
	
	override open func draw(_ inRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
		guard !hidden else { return }
		
		let swarm = swarmOverlay
		guard swarm.isTimestampValid else { return }
		let rects = inRect.subdivided
		rects.forEach { mapRect in
			let path = mapRect.pathForZoom(zoomScale, contentScale: contentScaleFactor)
			
			let timeStamp = swarm.currentFrameTimestamp
			let url = swarm.urlForTile(path, timestamp: timeStamp)
			
			let rect = self.rect(for: mapRect)
			
			if let image = swarm.manager.cache.object(forKey: url as AnyObject) as? UIImage {
				UIGraphicsPushContext(context);
				image.draw(in: rect, blendMode: .normal, alpha: swarm.alpha * alpha)
				UIGraphicsPopContext();
			} else {
				let color = UIColor.gray
				context.setFillColor(color.withAlphaComponent(0.1 * alpha).cgColor)
				context.fill(rect)
			}
			if swarmOverlay.debug { drawDebug(path, rect: rect, color: UIColor.blue.withAlphaComponent(0.6), context: context, note: "\(url.path)") }
		}
	}
}

fileprivate extension MKMapRect {
	var subdivided: [MKMapRect] {
		guard #available(iOS 13, *) else {
			return [self]
		}
		
		let newSize = MKMapSize(width: size.width * 0.5, height: size.height * 0.5)
		let a = MKMapRect(origin: origin, size: newSize)
		let b = a.offsetBy(dx: newSize.width, dy: 0.0)
		let c = a.offsetBy(dx: newSize.width, dy: newSize.height)
		let d = a.offsetBy(dx: 0.0, dy: newSize.height)
		return [a, b, c, d]
	}
}
