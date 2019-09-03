//
//  WDTRendererLoopViewController
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/4/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

#import "WDTRendererLoopViewController.h"
#import "WDTLayersViewController.h"
@import Swarm;

@interface WDTRendererLoopViewController ()

@property (nonatomic, weak) MKMapView *mapView;
@property (nonatomic, weak) UIButton *playButton;
@property (nonatomic, weak) UIProgressView *progressView;
@property (nonatomic, weak) UILabel *dateLabel;

@property (nonatomic, strong) NSProgress *progress;

@property (nonatomic, strong) SwarmOverlay *swarmOverlay;
@property (nonatomic, strong) SwarmTileOverlayRenderer *swarmRenderer;

@property (nonatomic) NSInteger baseLayer;
@property (nonatomic) NSInteger group;

@end


@implementation WDTRendererLoopViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[self setOverlay:SwarmBaseLayerRadar group:SwarmGroupNone];
	self.navigationItem.prompt = NSStringFromClass([self class]);
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[_swarmOverlay stopUpdating];
	[self endLoop];
}

- (void)setOverlay:(NSInteger)layer group:(NSInteger)group {
	self.baseLayer = layer;
	self.group = group;
	
	SwarmOverlay *overlay = [SwarmManager.sharedManager overlayForGroup:group baseLayer:layer];
	[overlay queryTimes:^(BOOL dataAVailable, NSError * _Nullable inError) {
		self.swarmOverlay = overlay;
		[self updateDateLabel];
	}];
}


#pragma mark Update UI 

- (void)updateDateLabel {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.timeStyle = NSDateFormatterShortStyle;
	NSDate *date = (_swarmOverlay.frameDate) ? _swarmOverlay.frameDate : [NSDate date];
	self.navigationItem.title = [dateFormatter stringFromDate:date];
	self.dateLabel.text = (_swarmOverlay.frameDate) ? _swarmOverlay.frameDate.description : @"";
}

- (void)updateProgressBar {
	self.progressView.progress = _progress.fractionCompleted;
	[UIView animateWithDuration:0.2 animations:^{ self.progressView.alpha = (self.progressView.progress >= 1.0) ? 0.0 : 1.0; }];
}

#pragma mark Setters

- (void)setSwarmOverlay:(SwarmOverlay *)swarmOverlay {
	if (_swarmOverlay) {
		[self.mapView removeOverlay:_swarmOverlay];
		[self endLoop];
		[_swarmOverlay stopUpdating];
	}
	
	_swarmOverlay = swarmOverlay;
	
	if (_swarmOverlay) {
		__weak __typeof(self) weakSelf = self;
		[_swarmOverlay startUpdating:false block:^(BOOL dataAvailable, NSError * _Nullable error) {
			[weakSelf.swarmRenderer setNeedsDisplay];
			[weakSelf updateDateLabel];
		}];
		[_mapView addOverlay:_swarmOverlay level: MKOverlayLevelAboveRoads];
	}
}

- (void)setProgress:(NSProgress *)progress {
	if (_progress) {
		[_progress removeObserver:self forKeyPath:@"fractionCompleted"];
	}
	_progress = progress;
	if (_progress) {
		[_progress addObserver:self forKeyPath:@"fractionCompleted" options:NSKeyValueObservingOptionInitial context:nil];
	}
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context	{
	if ([keyPath isEqualToString:@"fractionCompleted"]) {
		dispatch_async(dispatch_get_main_queue(), ^{ [self updateProgressBar]; });
	}
}

- (IBAction)toggleLoop:(id)sender {
	if (!_swarmOverlay) { return; }
	
	if (_swarmOverlay.animating) {
		[self endLoop];
	} else {
		[self beginLoop];
	}
}

- (void)beginLoop {
	[_playButton setTitle:@"Loading..." forState:UIControlStateNormal];
	__weak __typeof(self) weakSelf = self;
	self.progress = [_swarmOverlay fetchTilesForAnimation:_mapView.visibleMapRect readyBlock:^ {
		[weakSelf.playButton setTitle:@"Stop" forState:UIControlStateNormal];
		[weakSelf.swarmOverlay startAnimating: ^(UIImage* image){
			[weakSelf updateDateLabel];
			[weakSelf.swarmRenderer setNeedsDisplayInMapRect:weakSelf.mapView.visibleMapRect];
		}];
	}];
}

- (void) endLoop {
	[_swarmOverlay stopAnimatingWithJumpToLastFrame:YES];
	[_playButton setTitle:@"Play" forState:UIControlStateNormal];
	[self updateDateLabel];
	[_swarmRenderer setNeedsDisplayInMapRect:_mapView.visibleMapRect];
}

#pragma mark MKMapViewDelegate methods

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
	[_swarmOverlay pauseForMove];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
	[_swarmOverlay unpauseForMove:^{
		[self beginLoop];
	}];
	[_swarmRenderer setNeedsDisplay];
}

-(MKOverlayRenderer*)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
	if ([overlay isKindOfClass:[SwarmOverlay class]]) {
		SwarmTileOverlayRenderer *renderer = [[SwarmTileOverlayRenderer alloc] initWithOverlay:overlay];
		self.swarmRenderer = renderer;
		return renderer;
	}
	else if ([overlay isKindOfClass:[MKTileOverlay class]]) {
		return [[MKTileOverlayRenderer alloc] initWithOverlay:overlay];
	}
	return [[MKOverlayRenderer alloc] initWithOverlay:overlay];
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if ([segue.identifier isEqualToString:@"displaySettings"]) {
		UINavigationController *navController = segue.destinationViewController;
		WDTLayersViewController *layerSettings = (WDTLayersViewController*)navController.topViewController;
		layerSettings.selectedGroup = self.group;
		layerSettings.selectedLayer = self.baseLayer;
	}
	
}

- (IBAction)unwindFromSettings:(UIStoryboardSegue *)segue {
	if ([segue.sourceViewController isKindOfClass:[WDTLayersViewController class]]) {
		WDTLayersViewController *layersSettings = (WDTLayersViewController*)segue.sourceViewController;
		[self setOverlay:layersSettings.selectedLayer group:layersSettings.selectedGroup];
	}
}

@end
