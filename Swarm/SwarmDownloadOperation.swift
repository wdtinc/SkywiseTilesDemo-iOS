//
//  SwarmDownloadOperation.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/5/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation


class SwarmDownloadOperation: Operation {
	var task: URLSessionTask? = nil
	
	override var isAsynchronous: Bool { return true }
	
	fileprivate var operationExecuting: Bool = false
	override var isExecuting: Bool {
		get { return operationExecuting }
		set {
			if (operationExecuting != newValue) {
				willChangeValue(forKey: "isExecuting")
				operationExecuting = newValue
				didChangeValue(forKey: "isExecuting")
			}
		}
	}
	
	fileprivate var operationFinished: Bool = false
	override var isFinished: Bool {
		get { return operationFinished }
		set {
			if operationFinished != newValue {
				willChangeValue(forKey: "isFinished")
				operationFinished = newValue
				didChangeValue(forKey: "isFinished")
			}
		}
	}
	
	fileprivate var started = false
	
	func operationDone() {
		isFinished = started
		isExecuting = false
	}
	
	override func start() {
		guard !isCancelled else {
			isFinished = true
			return
		}
		isExecuting = true
		started = true
		
		main()
	}
	
	override func main() {
		guard let task = task else { operationDone(); return }
		task.resume()
	}
	
	override func cancel() {
		super.cancel()
		task?.cancel()
	}
}
