//
//  SwarmHelpers.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/5/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation
import MapKit

internal func onMainQueue(_ block: @escaping ((Void)->Void)) { DispatchQueue.main.async(execute: block) }

extension Bundle {
	static var SwarmBundle: Bundle { return Bundle(for: SwarmManager.self) }
}

extension OperationQueue {
	class func queue(concurrentCount: Int) -> OperationQueue {
		let queue = OperationQueue()
		queue.maxConcurrentOperationCount = concurrentCount
		return queue
	}
}

extension DateFormatter {
	class func swarmDateFormatter() -> DateFormatter {
		let dateFormatter = DateFormatter()
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
		return dateFormatter
	}
}

private class TimerActor {
	let block : ()->()
	init(block: @escaping ()->()) {
		self.block = block
	}
	dynamic func fire(_ timer: Timer) { block() }
}

extension Timer {
	class func repeatingBlockTimer(_ timeInterval: TimeInterval, block: @escaping (Void)->Void) -> Timer {
		let actor = TimerActor(block: block)
		return Timer.scheduledTimer(timeInterval: timeInterval, target: actor, selector: #selector(TimerActor.fire(_:)), userInfo: nil, repeats: true)
	}
}

// MARK: MapKit extensions

extension MKZoomScale {
	
	var zoomLevel: Int {
		let realScale = self / UIScreen.main.scale
		var z = Int((log(realScale)/log(2.0)+20.0))
		
		z += Int((UIScreen.main.scale - 1.0))
		return z;
	}
	
	var worldTileWidth: Int {
		return Int(pow(Double(2), Double(self.zoomLevel)))
	}
}

extension MKMapRect {
	
	var  mercatorTileOrigin: CGPoint {
		let region = MKCoordinateRegionForMapRect(self)
		
		let x = (region.center.longitude) * (.pi/180.0)
		let y = (region.center.latitude) * (.pi/180.0)
		let logy = log(tan(y)+1.0/cos(y))
		
		let px = (1.0 + (x / .pi)) * 0.5
		let py = (1.0 - (logy / .pi)) * 0.5
		return CGPoint(x: px, y: py)
	}
	
	func pathForZoom(_ scale: MKZoomScale, contentScale: CGFloat = 1.0) -> MKTileOverlayPath {
		let mercatorPoint = self.mercatorTileOrigin
		let tileWidth = scale.worldTileWidth
		let worldTileWidth = CGFloat(tileWidth)
		let x = Int(mercatorPoint.x * worldTileWidth)
		let y = Int(mercatorPoint.y * worldTileWidth)
		func adjustX(_ x:Int) -> Int { return (x >= tileWidth) ? x - tileWidth : x }
		return MKTileOverlayPath(x: adjustX(x), y: y, z: scale.zoomLevel, contentScaleFactor: contentScale)
	}
}

extension MKMapRect {
	
	func tilePaths(_ zoomScale: MKZoomScale, tileSize: CGFloat = 256, contentScale: CGFloat = 1.0) -> [MKTileOverlayPath] {
			return tilePaths(zoomScale.zoomLevel, tileSize: tileSize, contentScale:	contentScale)
		}
	
	func tilePaths(_ zoomLevel: Int, tileSize: CGFloat = 256, contentScale: CGFloat = 1.0) -> [MKTileOverlayPath] {
		let exponent = 20 - zoomLevel
		let calculatedScale = 1/pow(Double(2), Double(exponent))
		
		let minX = Int((MKMapRectGetMinX(self) * calculatedScale) / Double(tileSize))
		let maxX = Int((MKMapRectGetMaxX(self) * calculatedScale) / Double(tileSize))
		let minY = Int((MKMapRectGetMinY(self) * calculatedScale) / Double(tileSize))
		let maxY = Int((MKMapRectGetMaxY(self) * calculatedScale) / Double(tileSize))
		
		let width = Int(pow(Double(2), Double(zoomLevel)))
		func adjustX(_ x: Int) -> Int { return (x >= width) ? x - width : x }
		
		var paths: [MKTileOverlayPath] = []
		
		for x in minX ... maxX {
			for y in minY ... maxY {
				
				let rect = MKMapRect(
					origin: MKMapPoint(
						x: (Double(x) * Double(tileSize)) / calculatedScale,
						y: (Double(y) * Double(tileSize)) / calculatedScale
					),
					size: MKMapSize(
						width: Double(tileSize) / calculatedScale,
						height: Double(tileSize) / calculatedScale
					)
				)
				
				
				if MKMapRectIntersectsRect(rect, self) {
					paths.append(MKTileOverlayPath(x: adjustX(x), y: y, z: zoomLevel, contentScaleFactor: contentScale))
				}
			}
		}
		return paths
	}
}


extension MKMapRect {
	
	var northeastCoordinate: CLLocationCoordinate2D {
		let point = MKMapPointMake(origin.x + size.width, origin.y)
		return MKCoordinateForMapPoint(point)
	}
	
	var southwestCoordinate: CLLocationCoordinate2D {
		let point = MKMapPointMake(origin.x, origin.y + size.height)
		return MKCoordinateForMapPoint(point)
	}
	
	var northwestCoordinate: CLLocationCoordinate2D {
		let point = MKMapPointMake(origin.x, origin.y)
		return MKCoordinateForMapPoint(point)
	}
	
	var southeastCoordinate: CLLocationCoordinate2D {
		let point = MKMapPointMake(origin.x + size.width, origin.y + size.height)
		return MKCoordinateForMapPoint(point)
	}
}


extension MKMapView {
	var visibleSize: CGSize {
		let nw = visibleMapRect.northwestCoordinate
		let se = visibleMapRect.southeastCoordinate
		let origin = convert(nw, toPointTo: self)
		let pt = convert(se, toPointTo: self)
		return CGSize(width: pt.x - origin.x, height: pt.y - origin.y);
	}
}

extension MKTileOverlay {
	func tilePaths(_ mapRect: MKMapRect, zoomScale: MKZoomScale, contentScale: CGFloat = 1.0) -> [MKTileOverlayPath] {
		return mapRect.tilePaths(zoomScale, tileSize: self.tileSize.width, contentScale: contentScale)
	}
	func tilePaths(_ mapRect: MKMapRect, zoomLevel: Int, contentScale: CGFloat = 1.0) -> [MKTileOverlayPath] {
		return mapRect.tilePaths(zoomLevel, tileSize: self.tileSize.width, contentScale: contentScale)
	}
}


extension MKTileOverlayRenderer {	
	func drawDebug(_ path: MKTileOverlayPath, rect: CGRect, color: UIColor = UIColor.red, context: CGContext, note: String = "") {
		UIGraphicsPushContext(context)
		
		let string = note //"x:\(path.x) y:\(path.y) z:\(path.z) " + note
		let attribs: [String:AnyObject] = [NSFontAttributeName: UIFont.systemFont(ofSize: rect.height * 0.1), NSForegroundColorAttributeName: color]
		string.draw(with: rect, options: .usesLineFragmentOrigin, attributes: attribs, context: nil)
		
		context.setStrokeColor(color.cgColor)
		context.setLineWidth(rect.height / 256.0)
		context.stroke(rect)
		
		UIGraphicsPopContext();
	}
}


extension MKTileOverlayPath {
	var mapRect: MKMapRect {
		let exponent = 20 - z
		let calculatedScale = 1/pow(Double(2), Double(exponent))
		let tileSize: Double = 256.0
		
		return MKMapRect(
			origin: MKMapPoint(
				x: (Double(x) * tileSize) / calculatedScale,
				y: (Double(y) * tileSize) / calculatedScale
			),
			size: MKMapSize(
				width: tileSize / calculatedScale,
				height: tileSize / calculatedScale
			)
		)
	}
}

extension HTTPURLResponse {
	var errorValue: NSError {
		return NSError(domain: String(describing: SwarmOverlay.self), code: statusCode, userInfo: infoDictionary)
	}
	
	var infoDictionary: [AnyHashable: Any] {
		return [NSLocalizedDescriptionKey: HTTPURLResponse.localizedString(forStatusCode: statusCode)]
	}
}

extension Bundle {
	internal var userAgent: String {
		let infoDictionary = self.infoDictionary
		let appName = infoDictionary?["CFBundleName"] as? String ?? "MissingBundle"
		let appID = infoDictionary?["CFBundleIdentifier"] as? String ?? "MissingBundleID"
		let appVersion = infoDictionary?["CFBundleShortVersionString"] as? String ?? "MissingAppVersion"
		let swarmPlist = Bundle.SwarmBundle.infoDictionary
		let swarmVersion = swarmPlist?["CFBundleShortVersionString"] as? String ?? "MissingSwarmVersion"
		let swarmExecutable = swarmPlist?["CFBundleExecutable"] as? String ?? "MissingSwarmExecutable"
		let device = UIDevice.current
		let agent = String(format:"%@ %@ (%@ %@ - %@, %@, %@ %@)", appName, appVersion, device.systemName , device.systemVersion, device.model, appID, swarmExecutable, swarmVersion)
		
		return agent
	}
}


