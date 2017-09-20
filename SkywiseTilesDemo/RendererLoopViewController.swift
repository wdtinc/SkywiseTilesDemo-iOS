//
//  RendererLoopViewController.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 4/27/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import UIKit
import MapKit
import Swarm


class RendererLoopViewController: UIViewController  {

	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var progressView: UIProgressView!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var playButton: UIButton!
	
	var baseLayer: SwarmBaseLayer = .radar
	var group: SwarmGroup = .none
	
	var swarmOverlay: SwarmOverlay? = nil {
		didSet {
			if let oldOverlay = oldValue {
				self.mapView.remove(oldOverlay)
				oldOverlay.stopUpdating()
				endLoop()
			}
			if let overlay = swarmOverlay {
				overlay.startUpdating(block: { [weak self] (dataAvailable, updateError) in
					self?.swarmRenderer?.setNeedsDisplay()
					self?.updateDateLabel()
				})
				mapView.add(overlay, level: .aboveRoads)
			}
		}
	}
	var swarmRenderer: SwarmTileOverlayRenderer? = nil
	
	var progress: Progress? = nil {
		didSet {
			if let oldProgress = oldValue {
				oldProgress.removeObserver(self, forKeyPath: "fractionCompleted")
			}
			if let newProgress = progress {
				newProgress.addObserver(self, forKeyPath: "fractionCompleted", options: .initial, context: nil)
			}
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setOverlay(baseLayer, group: group)
		self.navigationItem.prompt = String(describing: RendererLoopViewController.self);
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}
	
	func setOverlay(_ baseLayer: SwarmBaseLayer, group: SwarmGroup) {
		self.baseLayer = baseLayer
		self.group = group
		
		let overlay = SwarmManager.sharedManager.overlayForGroup(group, baseLayer: baseLayer)
		overlay.queryTimes { (_, error) in
			self.swarmOverlay = overlay
			self.updateDateLabel()
		}
	}
	
	@IBAction func toggleLoop(_ sender: UIButton) {
		guard let overlay = swarmOverlay else { return }
		if overlay.animating {
			endLoop()
		} else {
			beginLoop()
		}
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == "fractionCompleted" {
			DispatchQueue.main.async { self.updateProgressBar() }
		}
	}
}

extension RendererLoopViewController {
	
	func beginLoop() {
		guard let overlay = swarmOverlay else { return }
		playButton.setTitle("Loading", for: UIControlState())
		self.progress = overlay.fetchTilesForAnimation(self.mapView.visibleMapRect, readyBlock: { [weak self] in
			guard let strongSelf = self else { return }
			strongSelf.playButton.setTitle("Stop", for: .normal)
			strongSelf.swarmOverlay?.startAnimating({ (_) in
				self?.updateDateLabel()
				self?.swarmRenderer?.setNeedsDisplay()//setNeedsDisplayInMapRect((self?.mapView.visibleMapRect)!)
			})
		})
	}
	
	func endLoop() {
		swarmOverlay?.stopAnimating(jumpToLastFrame: true)
		playButton.setTitle("Play", for: UIControlState())
		updateDateLabel()
		swarmRenderer?.setNeedsDisplayIn(mapView.visibleMapRect)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		endLoop()
		swarmOverlay?.stopUpdating()
	}
}

extension RendererLoopViewController {
	func updateProgressBar() {
		progressView.progress = Float( progress?.fractionCompleted ?? 0.0 )
		UIView.animate(withDuration: 0.2, animations: { 
			self.progressView.alpha = (self.progressView.progress >= 1.0) ? 0.0 : 1.0;
		}) 
	}
	
	func updateDateLabel() {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .short
		let date = swarmOverlay?.frameDate ?? Date()
		self.navigationItem.title = dateFormatter.string(from: date)
		self.dateLabel.text = self.swarmOverlay?.frameDate?.description ?? ""
	}
}


extension RendererLoopViewController : MKMapViewDelegate {
	
	func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
		swarmOverlay?.pauseForMove()
	}
	
	func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		swarmOverlay?.unpauseForMove({ 
			self.beginLoop()
		})
		swarmRenderer?.setNeedsDisplay()
	}
	
	func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
		if let swarmOverlay = overlay as? SwarmOverlay {
			let renderer = SwarmTileOverlayRenderer(overlay: swarmOverlay)
			swarmRenderer = renderer
			return renderer
		}
		return MKOverlayRenderer(overlay: overlay)
	}
}

extension RendererLoopViewController {
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "displaySettings" {
			if let navController = segue.destination as? UINavigationController,
				let layerSettings = navController.topViewController as? LayersViewController {
				layerSettings.selectedGroup = group
				layerSettings.selectedLayer = baseLayer
			}
		}
	}
	
	@IBAction func unwindFromSettings(_ segue: UIStoryboardSegue) {
		print(segue)
		if let layerSettings = segue.source as? LayersViewController {
			setOverlay(layerSettings.selectedLayer, group: layerSettings.selectedGroup)
		}
	}

}
