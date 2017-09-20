//
//  WDTLayersViewController.m
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/19/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

#import "WDTLayersViewController.h"
@import Swarm;

@interface WDTLayersViewController ()
@property (nonatomic, strong) NSArray *layers;
@property (nonatomic, strong) NSArray *groups;
@property (nonatomic, strong) NSString *layerIdentifier;
@property (nonatomic, strong) NSString *groupIdentifier;
@end

@implementation WDTLayersViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	self.layers = [[SwarmManager sharedManager] layerIdentifiers];
	self.groups = [[SwarmManager sharedManager] groupIdentifiers];
	self.layerIdentifier = [[SwarmManager sharedManager] layerIdentifier:_selectedLayer];
	self.groupIdentifier = [[SwarmManager sharedManager] groupIdentifier:_selectedGroup];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case 0: return _layers.count;
		case 1: return _groups.count;
		default: return 0;
	}
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case 0: return @"Layers";
		case 1: return @"Groups";
		default: return nil;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
	
	SwarmManager *manager = [SwarmManager sharedManager];
	
	UITableViewCellAccessoryType accessoryType = ^{
		switch (indexPath.section) {
			case 0:
				return ([self.layerIdentifier isEqualToString:self.layers[indexPath.row]]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
			case 1:
				return ([self.groupIdentifier isEqualToString:self.groups[indexPath.row]]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
				
			default: return UITableViewCellAccessoryNone;
		}
	}();

	switch (indexPath.section) {
		case 0:
		{
			NSString *title = [manager localizeLayer:self.layers[indexPath.row]];
			cell.textLabel.text = title;
		}
			break;
		case 1: {
			NSString *title = [manager localizeGroup:_groups[indexPath.row]];
			cell.textLabel.text = title;
		}
		default:
			break;
	}
	cell.accessoryType = accessoryType;
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath	 {
	switch (indexPath.section) {
		case 0:
			self.selectedLayer = [[SwarmManager sharedManager] layer:self.layers[indexPath.row]];
			break;
		case 1:
			self.selectedGroup = [[SwarmManager sharedManager] group:self.groups[indexPath.row]];
			break;
		default: break;
	}
	[self performSegueWithIdentifier:@"unwindFromSettings" sender:self];
}

@end
