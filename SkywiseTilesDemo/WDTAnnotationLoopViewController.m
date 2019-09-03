//
//  WDTAnnotationLoopViewController.m
//  SkywiseTilesDemo
//
//  Created by Justin Greenfield on 5/19/16.
//  Copyright © 2016 Weather Decision Technologies, Inc. All rights reserved.
//

#import "WDTAnnotationLoopViewController.h"
#import "WDTLayersViewController.h"
@import Swarm;

@interface WDTAnnotationLoopViewController ()

@property (nonatomic, weak) MKMapView *mapView;
@property (nonatomic, weak) UIButton *playButton;
@property (nonatomic, weak) UIProgressView *progressView;
@property (nonatomic, weak) UILabel *dateLabel;

@property (nonatomic, strong) NSProgress *progress;

@property (nonatomic, strong) SwarmOverlayCoordinator *swarmCoordinator;

@property (nonatomic) NSInteger baseLayer;
@property (nonatomic) NSInteger group;

@end

@implementation WDTAnnotationLoopViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	[self setOverlay:SwarmBaseLayerRadar group:SwarmGroupNone];
	self.navigationItem.prompt = NSStringFromClass([self class]);
	_mapView.rotateEnabled = NO;
	_mapView.pitchEnabled = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self endLoop];
	[_swarmCoordinator stopUpdating];
}

- (void)setOverlay:(NSInteger)inLayer group:(NSInteger)inGroup {
	self.baseLayer = inLayer;
	self.group = inGroup;
	self.swarmCoordinator = nil;
	SwarmOverlay *overlay = [[SwarmManager sharedManager] overlayForGroup:self.group baseLayer:self.baseLayer];
	//overlay.loopZoomOffset = 1; //set this offset to 1 to animate at lower zoom level (loads fewer tiles, faster)
	[overlay queryTimes:^(BOOL dataAvailable, NSError * _Nullable error) {
		self.swarmCoordinator = [[SwarmOverlayCoordinator alloc] initWithOverlay:overlay mapView:self.mapView];
		[self updateDateLabel];
	}];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	[_swarmCoordinator regionWillChange];
	[coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
		[self.swarmCoordinator regionDidChange:^{
			[self beginLoop];
		}];
	}];
}

- (void)setSwarmCoordinator:(SwarmOverlayCoordinator *)swarmCoordinator {
	if (_swarmCoordinator != nil) {
		[self endLoop];
		[_swarmCoordinator stopUpdating];
		[_mapView removeOverlay:_swarmCoordinator.overlay];
	}
	_swarmCoordinator = swarmCoordinator;
	if (_swarmCoordinator != nil) {
		[_mapView addOverlay:_swarmCoordinator.overlay];
		__weak __typeof(self) weakSelf = self;
		[_swarmCoordinator startUpdating:false block:^(BOOL dataAvailable, NSError * _Nullable error) {
			if (dataAvailable) {
				[weakSelf.swarmCoordinator overlayUpdated:^{
				[weakSelf beginLoop];
			}];
			}
		}];
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


#pragma mark Update UI

- (void)updateDateLabel {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.timeStyle = NSDateFormatterShortStyle;
	NSDate *date = (_swarmCoordinator.frameDate) ? _swarmCoordinator.frameDate : [NSDate date];
	self.navigationItem.title = [dateFormatter stringFromDate:date];
	self.dateLabel.text = (_swarmCoordinator.frameDate) ? _swarmCoordinator.frameDate.description : @"";
}

- (void)updateProgressBar {
	self.progressView.progress = _progress.fractionCompleted;
	[UIView animateWithDuration:0.2 animations:^{ self.progressView.alpha = (self.progressView.progress >= 1.0) ? 0.0 : 1.0; }];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context	{
	if ([keyPath isEqualToString:@"fractionCompleted"]) {
		dispatch_async(dispatch_get_main_queue(), ^{ [self updateProgressBar]; });
	}
}

- (IBAction)toggleLoop:(id)sender {
	if (!_swarmCoordinator) { return; }
	if (_swarmCoordinator.animating) {
		[self endLoop];
	} else {
		[self beginLoop];
	}
}

- (void)endLoop {
	[_swarmCoordinator stopAnimating];
	[_playButton setTitle:@"Play" forState:UIControlStateNormal];
	[self updateDateLabel];
}

- (void)beginLoop {
	[_playButton setTitle:@"Loading..." forState:UIControlStateNormal];
	__weak __typeof(self) weakSelf = self;
	self.progress = [_swarmCoordinator fetchTilesForAnimation:_mapView.visibleMapRect readyBlock:^{
		[weakSelf.playButton setTitle:@"Stop" forState:UIControlStateNormal];
		[weakSelf.swarmCoordinator startAnimating: ^{
			[weakSelf updateDateLabel];
		}];
	}];
}

#pragma mark MKMapViewDelegate methods

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
	[_swarmCoordinator regionWillChange];
}


- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
	[_swarmCoordinator regionDidChange:^{
		[self beginLoop];
	}];
}


- (MKOverlayRenderer*)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
	if ([overlay isKindOfClass:[SwarmOverlay class]]) {
		return _swarmCoordinator.renderer;
	}
	else if ([overlay isKindOfClass:[MKTileOverlay class]]) {
		return [[MKTileOverlayRenderer alloc] initWithOverlay:overlay];
	}
	return [[MKOverlayRenderer alloc] initWithOverlay:overlay];
}


- (MKAnnotationView*)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
	if ([annotation isKindOfClass:[SwarmAnnotation class]]) {
		CGRect frame = mapView.bounds;
		frame.size.height = frame.size.height - self.topLayoutGuide.length;
		return [_swarmCoordinator annotationView:frame];
	}
	return nil;
}


- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray<MKAnnotationView *> *)views	{
		[_swarmCoordinator.loopView.superview sendSubviewToBack:_swarmCoordinator.loopView];
}


- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
	if (view == _swarmCoordinator.loopView) { mapView.selectedAnnotations = @[]; }
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
