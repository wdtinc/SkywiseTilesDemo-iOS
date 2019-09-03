//
//  ViewController.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 4/27/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import UIKit
import MapKit
import Swarm


class AnnotationLoopViewController: UIViewController  {

	@IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var progressView: UIProgressView!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var playButton: UIButton!
	
	var swarmCoordinator: SwarmOverlayCoordinator? = nil {
		didSet {
			if let oldCoordinator = oldValue {
				endLoop()
				oldCoordinator.stopUpdating()
				mapView.removeOverlay(oldCoordinator.overlay)
			}
			if let coordinator = swarmCoordinator {
				mapView.addOverlay(coordinator.overlay)
				coordinator.startUpdating(block: { [weak self] (dataAvailable, error) in
					print(error as Any)
					if dataAvailable { self?.swarmCoordinator?.overlayUpdated { self?.beginLoop() } }
					self?.updateDateLabel()
				})
			}
		}
	}
	
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
	
	var baseLayer: SwarmBaseLayer = .radar
	var group: SwarmGroup = .none
	
	override func viewDidLoad() {
		super.viewDidLoad()
		setOverlay(baseLayer, group: group)
		self.navigationItem.prompt = String(describing: AnnotationLoopViewController.self);
		mapView.isRotateEnabled = false
		mapView.isPitchEnabled = false
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
	}
	
	func setOverlay(_ baseLayer: SwarmBaseLayer, group: SwarmGroup) {
		self.baseLayer = baseLayer
		self.group = group
		swarmCoordinator = nil
		let overlay = SwarmManager.sharedManager.overlayForGroup(group, baseLayer: baseLayer)//SwarmOverlay(name: "globalirgrid")
		//overlay.loopZoomOffset = 1 //set this offset to 1 to animate at lower zoom level (loads fewer tiles, faster)
		//overlay.debug = true
		overlay.queryTimes { (_, error) in
			print(error as Any)
			self.swarmCoordinator = SwarmOverlayCoordinator(overlay: overlay, mapView: self.mapView)
			self.updateDateLabel()
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		endLoop()
		swarmCoordinator?.stopUpdating()
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		swarmCoordinator?.regionWillChange()
		
		coordinator.animate(alongsideTransition: nil) { (_) in
			self.swarmCoordinator?.regionDidChange { self.beginLoop() }
		}
	}
	
	@IBAction func toggleLoop(_ sender: UIButton) {
		guard let coordinator = swarmCoordinator else { return }
		if coordinator.animating {
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

extension AnnotationLoopViewController {
	
	func beginLoop() {
		guard let coordinator = swarmCoordinator else { return }
		playButton.setTitle("Loading", for: UIControl.State())
		self.progress = coordinator.fetchTilesForAnimation(mapView.visibleMapRect,
			readyBlock: { [weak self] in
				guard let strongSelf = self else { return }
				strongSelf.playButton.setTitle("Stop", for: .normal)
				strongSelf.swarmCoordinator?.startAnimating { [weak self] in
					self?.updateDateLabel()
				}
		})
	}
	
	func endLoop() {
		swarmCoordinator?.stopAnimating()
		playButton.setTitle("Play", for: UIControl.State())
		updateDateLabel()
	}

	func updateProgressBar() {
		progressView.progress = Float( progress?.fractionCompleted ?? 0.0 )
		UIView.animate(withDuration: 0.2, animations: { 
			self.progressView.alpha = (self.progressView.progress >= 1.0) ? 0.0 : 1.0;
		}) 
	}
	
	func updateDateLabel() {
		let dateFormatter = DateFormatter()
		dateFormatter.timeStyle = .short
		let date = swarmCoordinator?.frameDate ?? Date()
		navigationItem.title = dateFormatter.string(from: date)
		self.dateLabel.text = self.swarmCoordinator?.frameDate?.description ?? ""
	}
}


extension AnnotationLoopViewController : MKMapViewDelegate {
	
	func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
		swarmCoordinator?.regionWillChange()
	}
	
	func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		swarmCoordinator?.regionDidChange { self.beginLoop() }
	}
	
	func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
		if let _ = overlay as? SwarmOverlay, let coordinator = swarmCoordinator {
			return coordinator.renderer
		}
		return MKTileOverlayRenderer(overlay: overlay)
	}
	
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		if let _ = annotation as? SwarmAnnotation {
			var frame = self.mapView.bounds
			frame.size.height = frame.size.height - self.topLayoutGuide.length
			let view = swarmCoordinator?.annotationView(frame)
			return view
		}
		return nil
	}
	
	func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
		//loopAnnotationView.regionChanged()
		if let loopAnnotationView = swarmCoordinator?.loopView {
			loopAnnotationView.superview?.sendSubviewToBack(loopAnnotationView)
		}
	}
	
	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		if view == swarmCoordinator?.loopView { mapView.selectedAnnotations = [] }
	}
}


extension AnnotationLoopViewController {
	
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
		if let layerSettings = segue.source as? LayersViewController {
			setOverlay(layerSettings.selectedLayer, group: layerSettings.selectedGroup)
		}
	}
	
}
