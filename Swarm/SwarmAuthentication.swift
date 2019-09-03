//
//  SwarmAuthentication.swift
//  SkywiseTilesDemo
//
//  Created by Ross Kimes on 5/25/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation

@objc public protocol Authentication {
	var baseURL: String { get }
	
	var app_id: String { get }
	var app_key: String { get }
	
	func authenticatedURLRequest(forURL urlString: String) -> URLRequest?
}


@objc open class SkywiseAuthentication: NSObject, Authentication {
	
	public init(app_id: String, app_key: String) {
		self.app_id = app_id
		self.app_key = app_key
		super.init()
	}
	
	public let app_id: String
	public let app_key: String
	
	public let baseURL: String = "http://skywisetiles.wdtinc.com/"
	
	fileprivate let userAgent = Bundle.main.userAgent
	
	open func authenticatedURLRequest(forURL urlString: String) -> URLRequest? {
		
		let fullString = baseURL + urlString
		
		guard let url = URL(string: fullString) else { return nil }
		
		let urlRequest = NSMutableURLRequest(url: url);
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
		urlRequest.setValue(app_id, forHTTPHeaderField: "app_id")
		urlRequest.setValue(app_key, forHTTPHeaderField: "app_key")
		
		return urlRequest as URLRequest
	}
}
