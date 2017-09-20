//
//  LayersViewController.swift
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/19/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

import Foundation
import UIKit
import Swarm

class LayersViewController : UITableViewController {
	
	let groups: [SwarmGroup] = SwarmGroup.allGroups
	
	var selectedGroup: SwarmGroup = .none
	var selectedLayer: SwarmBaseLayer = .radar
}

extension LayersViewController  {
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0: return "Base Layers"
		case 1: return "Groups"
		default: return nil
		}
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0: return 2
		case 1: return groups.count
		default: return 0
		}
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		print(indexPath)
		print(tableView.indexPathForSelectedRow as Any)
		switch indexPath.section {
		case 0: selectedLayer = (indexPath.row == 0) ? .radar : .satellite
		case 1: selectedGroup = groups[indexPath.row]
		default: break
		}
		performSegue(withIdentifier: "unwindFromSettings", sender: self)
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
		let accessoryType: UITableViewCellAccessoryType = {
			switch indexPath.section {
			case 0:  return (indexPath.row == selectedLayer.rawValue) ? .checkmark : .none
			case 1: return (indexPath.row == selectedGroup.rawValue) ? .checkmark : .none
			default: return .none
			}
		}()
		switch indexPath.section {
		case 0:
			let title: String = {
			switch indexPath.row {
			case 0: return "Radar"
			case 1: return "Satellite"
			default: return ""
				}
			}()
			cell.textLabel?.text = title
		case 1:
			let title = SwarmGroup.localize(groups[indexPath.row])
			cell.textLabel?.text = title
		default: break
		}
		cell.accessoryType = accessoryType
		return cell
	}
	
	
}
