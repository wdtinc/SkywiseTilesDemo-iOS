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
	
	override open func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
		let swarm = swarmOverlay
		guard swarm.isTimestampValid else { return false }
		
		swarm.zoomScale = zoomScale
		swarm.contentScale = contentScaleFactor
		
		let path = mapRect.pathForZoom(zoomScale, contentScale: contentScaleFactor)
		let timeStamp = swarm.currentFrameTimestamp
		let url = swarm.urlForTile(path, timestamp: timeStamp)
		let object = swarm.manager.cache.object(forKey: url as AnyObject)
		
		if object is UIImage || object is NSError {
			return true
		}
		
		swarmOverlay.downloadTileAtURL(url) { [weak self] error in
			guard error == nil else { return }
			self?.setNeedsDisplayIn(mapRect, zoomScale: zoomScale)
		}
		return false
	}
	
	override open func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
		guard !hidden else { return }
		
		let swarm = swarmOverlay
		guard swarm.isTimestampValid else { return }
		
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

