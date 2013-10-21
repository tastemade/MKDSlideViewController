//
//  MKDSlideViewController.m
//  MKDSlideViewController
//
//  Created by Marcel Dierkes on 03.12.11.
//  Copyright (c) 2011-2013 Marcel Dierkes. All rights reserved.
//

#import "MKDSlideViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "UIViewController+MKDSlideViewController.h"

typedef NS_ENUM(NSInteger, MKDSlideViewControllerPositionType) {
    MKDSlideViewControllerPositionLeft = -1,
    MKDSlideViewControllerPositionCenter = 0,
    MKDSlideViewControllerPositionRight = 1,
};

@interface UIViewController (MKDSlideViewControllerPrivate)
@property (nonatomic, retain, readwrite) MKDSlideViewController * slideViewController;
@end


@interface MKDSlideViewController ()
@property (nonatomic, assign) MKDSlideViewControllerPositionType slidePosition;

@property (nonatomic, retain) UIView * leftPanelView;
@property (nonatomic, retain) UIView * mainPanelView;
@property (nonatomic, retain) UIView * rightPanelView;

@property (nonatomic, retain) UIPanGestureRecognizer * panGestureRecognizer;
@property (nonatomic, retain) UIView * tapOverlayView;

@property (nonatomic, assign) CGPoint previousLocationInView;

@end

@implementation MKDSlideViewController

- (instancetype)initWithMainViewController:(UIViewController *)mainViewController;
{
    self = [super initWithNibName:nil bundle:nil];
    if( self )
    {
        self.mainViewController = mainViewController;
        
        // Setup defaults
        _slidePosition = MKDSlideViewControllerPositionCenter;
        _handleStatusBarStyleChanges = YES;
        _mainStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
        _leftStatusBarStyle = UIStatusBarStyleBlackOpaque;
        _rightStatusBarStyle = UIStatusBarStyleBlackOpaque;
        _slideSpeed = 0.3f;
        _overlapWidth = 52.0f;
        _enabled = YES;
    }
    return self;
}

- (void)dealloc
{
    [_leftPanelView release];
    [_rightPanelView release];
    [_mainPanelView release];
    
    [_tapOverlayView release];
    
    [_leftViewController release];
    [_rightViewController release];
    [_mainViewController release];
    
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    // Setup Panels
    _leftPanelView = [UIView new];
    _leftPanelView.translatesAutoresizingMaskIntoConstraints = NO;
    _leftPanelView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_leftPanelView];
    
    _rightPanelView = [UIView new];
    _rightPanelView.translatesAutoresizingMaskIntoConstraints = NO;
    _rightPanelView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_rightPanelView];
    
    _mainPanelView = [UIView new];
    _mainPanelView.translatesAutoresizingMaskIntoConstraints = NO;
    _mainPanelView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_mainPanelView];
    [_mainPanelView addGestureRecognizer:self.panGestureRecognizer];

    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(_leftPanelView, _rightPanelView, _mainPanelView);
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_leftPanelView]|" options:0 metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_leftPanelView]|" options:0 metrics:nil views:viewsDictionary]];

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_rightPanelView(==_leftPanelView)]|" options:0 metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_rightPanelView(==_leftPanelView)]|" options:0 metrics:nil views:viewsDictionary]];

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_mainPanelView(==_leftPanelView)]" options:0 metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_mainPanelView(==_leftPanelView)]|" options:0 metrics:nil views:viewsDictionary]];
    
    // create constraint for the left edge of the main view
    // we will animate the constant of this constraint for sliding the main view
    _constraintMainViewLeft = [NSLayoutConstraint constraintWithItem:_mainPanelView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0f constant:0.0f];
    
    [self.view addConstraint:_constraintMainViewLeft];

    if( self.mainViewController.view.superview == nil )
    {
        [self addMainView];
    }
    if( self.leftViewController.view.superview == nil )
    {
        [self addLeftView];
    }
    if( self.rightViewController.view.superview == nil )
    {
        [self addRightView];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    if ([self.view window]==nil) {
        self.delegate = nil;
    }
}

- (void)viewDidLayoutSubviews {
    // Setup main layer shadow
    CALayer * layer = _mainPanelView.layer;
    layer.masksToBounds = NO;
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    layer.shadowOpacity = 0.9f;
    CGRect rect = CGRectMake(0.0f, -40.0f, _mainPanelView.frame.size.width, _mainPanelView.frame.size.height+80.0f);
    CGPathRef path = [UIBezierPath bezierPathWithRect:rect].CGPath;
    layer.shadowPath = path;
    layer.shadowRadius = 20.0f;
}

#pragma mark - Child View Controllers

- (void)setMainViewController:(UIViewController *)mainViewController {
    if( _mainViewController != nil ) {
        // Clean up
        [_mainViewController removeFromParentViewController];
        _mainViewController.slideViewController = nil;
        [_mainViewController.view removeFromSuperview];
        [_mainViewController release];
    }
    _mainViewController = [mainViewController retain];
    _mainViewController.slideViewController = self;
    [self addChildViewController:_mainViewController];
    
    if( _mainPanelView != nil ) {
        [self addMainView];
    }
}

- (void)addMainView {
    if (_mainViewController == nil)
        return;

    UIView* mv = self.mainViewController.view;
    mv.translatesAutoresizingMaskIntoConstraints = NO;

    [self.mainPanelView addSubview:mv];

    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(mv);
    
    [self.mainPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[mv]|" options:0 metrics:nil views:viewsDictionary]];
    [self.mainPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[mv]|" options:0 metrics:nil views:viewsDictionary]];
}

- (void)setLeftViewController:(UIViewController *)leftViewController {
    if( _leftViewController != nil ) {
        // Clean up
        [_leftViewController removeFromParentViewController];
        _leftViewController.slideViewController = nil;
        [_leftViewController.view removeFromSuperview];
        [_leftViewController release];
    }
    
    if (!leftViewController)
        return;
    
    _leftViewController = [leftViewController retain];
    _leftViewController.slideViewController = self;
    [self addChildViewController:_leftViewController];
    
    if( _leftPanelView != nil ) {
        [self addLeftView];
    }
}

- (void)addLeftView {
    if (_leftViewController == nil)
        return;

    UIView* lv = self.leftViewController.view;
    lv.translatesAutoresizingMaskIntoConstraints = NO;

    [self.leftPanelView addSubview:lv];

    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(lv);
    
    [self.leftPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[lv]|" options:0 metrics:nil views:viewsDictionary]];
    [self.leftPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[lv]|" options:0 metrics:nil views:viewsDictionary]];
}

- (void)setRightViewController:(UIViewController *)rightViewController {
    if( _rightViewController != nil ) {
        // Clean up
        [_rightViewController removeFromParentViewController];
        _rightViewController.slideViewController = nil;
        [_rightViewController.view removeFromSuperview];
        [_rightViewController release];
    }
    
    if (!rightViewController)
        return;
    
    _rightViewController = [rightViewController retain];
    _rightViewController.slideViewController = self;
    [self addChildViewController:_rightViewController];
    
    if( _rightPanelView != nil )
    {
        [self addRightView];
    }
}

- (void)addRightView {
    if (_rightViewController == nil)
        return;
    
    UIView* rv = self.rightViewController.view;
    rv.translatesAutoresizingMaskIntoConstraints = NO;

    [self.rightPanelView addSubview:rv];
    
    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(rv);
    
    [self.rightPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[rv]|" options:0 metrics:nil views:viewsDictionary]];
    [self.rightPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[rv]|" options:0 metrics:nil views:viewsDictionary]];
}

- (void)setMainViewController:(UIViewController *)mainViewController animated:(BOOL)animated
{
    [self.mainViewController viewWillDisappear:animated];
    if(!animated)
    {
        self.mainViewController = mainViewController;
        [self.mainViewController viewDidDisappear:animated];
        [self showMainViewControllerAnimated:animated viewEvents:YES];
        return;
    }
    
    float constant = _mainPanelView.frame.size.width + self.overlapWidth;
    
    if( self.mainViewController != nil ) {
        // Slide out of sight
        
        [UIView animateWithDuration:self.slideSpeed
                         animations:^{
                             _constraintMainViewLeft.constant = constant;
                             [self.view layoutIfNeeded];
                         } completion:^(BOOL finished) {
                             // Replace the view controller and slide back in
                             [self.mainViewController viewDidDisappear:animated];
                             self.mainViewController = mainViewController;
                             [self showMainViewControllerAnimated:animated viewEvents:YES];
                         }];
    }
}

#pragma mark - Rotation Handling

- (BOOL)shouldAutorotate {
    return NO;
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

#pragma mark - Panning

- (UIPanGestureRecognizer *)panGestureRecognizer
{
    if( _panGestureRecognizer == nil )
    {
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        _panGestureRecognizer.maximumNumberOfTouches = 1;
        _panGestureRecognizer.delegate = self;
    }
    return _panGestureRecognizer;
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer {
    return self.enabled;
}

- (void)pan:(UIPanGestureRecognizer *)gesture
{
    if (!self.enabled)
        return;
    
    if( gesture.state == UIGestureRecognizerStateBegan )
    {
        self.previousLocationInView = CGPointZero;
        
        if( [self isHandlingStatusBarStyleChanges] )
            [[UIApplication sharedApplication] setStatusBarStyle:self.leftStatusBarStyle animated:YES];
    }
    else if( gesture.state == UIGestureRecognizerStateChanged )
    {
        // Decide, which view controller should be revealed
        if( self.mainPanelView.frame.origin.x <= 0.0f ) {   // left
            [self.view sendSubviewToBack:self.leftPanelView];
        } else {
            [self.view sendSubviewToBack:self.rightPanelView];
        }
        
        // Calculate position offset
        CGPoint locationInView = [gesture translationInView:self.view];
        CGFloat deltaX = locationInView.x - self.previousLocationInView.x;
        
        // Update view frame
        CGRect newFrame = self.mainPanelView.frame;
        newFrame.origin.x +=deltaX;
        
        if (newFrame.origin.x > 0 && !self.leftViewController)
            return;
        if (newFrame.origin.x < 0 && !self.rightViewController)
            return;
        
        _constraintMainViewLeft.constant = newFrame.origin.x;
        [self.view layoutIfNeeded];
        
        self.previousLocationInView = locationInView;
    }
    else if( (gesture.state == UIGestureRecognizerStateEnded) || (gesture.state == UIGestureRecognizerStateCancelled) )
    {
        [self updatePanelsForCurrentPosition];
    }
}

- (void)updatePanelsForCurrentPosition
{
    UIApplication * app = [UIApplication sharedApplication];
    
    MKDSlideViewControllerPositionType position = self.slidePosition;
    CGFloat xOffset = self.mainPanelView.frame.origin.x;
    CGFloat snapThreshold = self.overlapWidth;
    
    CGFloat dividerPosition = 0.0f;
    
    if( position == MKDSlideViewControllerPositionCenter )
    {
        if( (xOffset >= (dividerPosition-snapThreshold)) && (xOffset <= (dividerPosition+snapThreshold)) )
        {
            // Snap to center position
            [self showMainViewControllerAnimated:YES viewEvents:NO];
            if( [self isHandlingStatusBarStyleChanges] )
                [app setStatusBarStyle:self.mainStatusBarStyle animated:YES];
        }
        else if( xOffset < (dividerPosition-snapThreshold) )
        {
            // snap to right position
            [self showRightViewControllerAnimated:YES];
            if( [self isHandlingStatusBarStyleChanges] )
                [app setStatusBarStyle:self.rightStatusBarStyle animated:YES];
        }
        else
        {
            // snap to left position
            [self showLeftViewControllerAnimated:YES];
            if( [self isHandlingStatusBarStyleChanges] )
                [app setStatusBarStyle:self.leftStatusBarStyle animated:YES];
        }

    }
    else if( position == MKDSlideViewControllerPositionLeft )
    {
        dividerPosition = self.view.bounds.size.width - self.overlapWidth;
        
        if( (xOffset >= (dividerPosition-snapThreshold)) && (xOffset <= (dividerPosition+snapThreshold)) )
        {
            // Snap back to left position
            [self showLeftViewControllerAnimated:YES];
            if( [self isHandlingStatusBarStyleChanges] )
                [app setStatusBarStyle:self.leftStatusBarStyle animated:YES];
        }
        else if( xOffset < (dividerPosition-snapThreshold) )
        {
            // snap to center position
            [self showMainViewControllerAnimated:YES viewEvents:NO];
            if( [self isHandlingStatusBarStyleChanges] )
                [app setStatusBarStyle:self.mainStatusBarStyle animated:YES];
        }
        
    }
    else if( position == MKDSlideViewControllerPositionRight )
    {
        dividerPosition = self.overlapWidth;
        CGFloat rightSideX = xOffset+self.mainPanelView.frame.size.width;
        
        if( (rightSideX <= dividerPosition) && (rightSideX < (dividerPosition+snapThreshold)) ) // FIXME: Is a bit buggy.
        {
            // snap to right position
            [self showRightViewControllerAnimated:YES];
            if( [self isHandlingStatusBarStyleChanges] )
                [app setStatusBarStyle:self.rightStatusBarStyle animated:YES];
        }
        else
        {
            // snap to center position
            [self showMainViewControllerAnimated:YES viewEvents:NO];
            if( [self isHandlingStatusBarStyleChanges] )
                [app setStatusBarStyle:self.mainStatusBarStyle animated:YES];
        }
        
    }
    
    self.previousLocationInView = CGPointZero;
}

#pragma mark - Tap Overlay View Handling

- (UIView *)tapOverlayView
{
    if( _tapOverlayView == nil )
    {
        _tapOverlayView = [[UIView alloc] initWithFrame:self.view.bounds];
        _tapOverlayView.backgroundColor = [UIColor clearColor];
        _tapOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showMainViewController)];
        tapGesture.numberOfTapsRequired = 1;
        tapGesture.numberOfTouchesRequired = 1;
        [_tapOverlayView addGestureRecognizer:tapGesture];
        [tapGesture release];
    }
    return _tapOverlayView;
}

- (void)addTapViewOverlay
{
    [self.mainPanelView addSubview:self.tapOverlayView];
}

- (void)removeTapViewOverlay
{
    [self.tapOverlayView removeFromSuperview];
}

#pragma mark - Slide Actions

- (void)showLeftViewController
{
    [self showLeftViewControllerAnimated:YES];
}

- (void)showLeftViewControllerAnimated:(BOOL)animated
{
    self.slidePosition = MKDSlideViewControllerPositionLeft;
    
    if( [self.delegate respondsToSelector:@selector(slideViewController:willSlideToViewController:)] )
        [self.delegate performSelector:@selector(slideViewController:willSlideToViewController:) withObject:self withObject:self.leftViewController];
    
    if( [self isHandlingStatusBarStyleChanges] )
        [[UIApplication sharedApplication] setStatusBarStyle:self.leftStatusBarStyle animated:YES];
    
    [self.leftViewController viewWillAppear:animated];
    
    [self.view sendSubviewToBack:self.rightPanelView];
    
    float constant = _mainPanelView.frame.size.width - self.overlapWidth;

    if( animated )
    {
        [UIView animateWithDuration:self.slideSpeed
                         animations:^{
                             _constraintMainViewLeft.constant = constant;
                             [self.view layoutIfNeeded];
                             
        } completion:^(BOOL finished) {
            [self addTapViewOverlay];
            [self.leftViewController viewDidAppear:animated];
            if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.leftViewController];
        }];
    }
    else
    {
        _constraintMainViewLeft.constant = constant;
        [self.view layoutIfNeeded];
        [self.leftViewController viewDidAppear:animated];
        [self addTapViewOverlay];
        
        if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
            [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.leftViewController];
    }
}

- (void)showLeftFull {
    float constant = _mainPanelView.frame.size.width;
    
    [UIView animateWithDuration:self.slideSpeed
                     animations:^{
                         _constraintMainViewLeft.constant = constant;
                         [self.view layoutIfNeeded];
                     } completion:^(BOOL finished) {
                     }];
}

- (void)showRightViewController
{
    [self showRightViewControllerAnimated:YES];
}

- (void)showRightViewControllerAnimated:(BOOL)animated
{
    self.slidePosition = MKDSlideViewControllerPositionRight;
    
    if( [self.delegate respondsToSelector:@selector(slideViewController:willSlideToViewController:)] )
        [self.delegate performSelector:@selector(slideViewController:willSlideToViewController:) withObject:self withObject:self.rightViewController];
    
    if( [self isHandlingStatusBarStyleChanges] )
        [[UIApplication sharedApplication] setStatusBarStyle:self.rightStatusBarStyle animated:YES];
    
    [self.rightViewController viewWillAppear:animated];
    [self.view sendSubviewToBack:self.leftPanelView];
    
    float constant = -_mainPanelView.frame.size.width + self.overlapWidth;

    if( animated )
    {
        [UIView animateWithDuration:self.slideSpeed
                         animations:^{
                             _constraintMainViewLeft.constant = constant;
                             [self.view layoutIfNeeded];
                             
        } completion:^(BOOL finished) {
            [self addTapViewOverlay];
            [self.rightViewController viewDidAppear:animated];
            if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.rightViewController];
        }];
    }
    else
    {
        _constraintMainViewLeft.constant = constant;
        [self.view layoutIfNeeded];
        [self.rightViewController viewDidAppear:animated];
        [self addTapViewOverlay];
        
        if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
            [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.rightViewController];
    }

}

- (void)showMainViewController
{
    [self showMainViewControllerAnimated:YES viewEvents:NO];
}

- (void)showMainViewControllerAnimated:(BOOL)animated
{
    [self showMainViewControllerAnimated:YES viewEvents:NO];
}

- (void)showMainViewControllerAnimated:(BOOL)animated viewEvents:(BOOL)viewEvents
{
    UIViewController *disappearingViewController = nil;
    if (self.slidePosition == MKDSlideViewControllerPositionLeft) {
        disappearingViewController = self.leftViewController;
    }else if (self.slidePosition == MKDSlideViewControllerPositionRight) {
        disappearingViewController = self.rightViewController;
    }
    self.slidePosition = MKDSlideViewControllerPositionCenter;
    
    [disappearingViewController viewWillDisappear:animated];
    
    if (viewEvents) {
        [self.mainViewController viewWillAppear:animated];
    }
    
    if( [self isHandlingStatusBarStyleChanges] )
        [[UIApplication sharedApplication] setStatusBarStyle:self.mainStatusBarStyle animated:YES];
    
    if( self.mainPanelView.frame.origin.x != CGPointZero.x )
    {
        if( [self.delegate respondsToSelector:@selector(slideViewController:willSlideToViewController:)] )
            [self.delegate performSelector:@selector(slideViewController:willSlideToViewController:) withObject:self withObject:self.mainViewController];
        
        if( animated )
        {
            [UIView animateWithDuration:self.slideSpeed
                             animations:^{
                                 _constraintMainViewLeft.constant = 0.0f;
                                 [self.view layoutIfNeeded];
            } completion:^(BOOL finished) {
                if (viewEvents) {
                    [self.mainViewController viewDidAppear:animated];
                }
               
                [disappearingViewController viewDidDisappear:animated];
                [self removeTapViewOverlay];
                if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                    [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.mainViewController];
            }];
        }
        else
        {
            
            _constraintMainViewLeft.constant = 0.0f;
            [self.view layoutIfNeeded];
            
            if (viewEvents) {
                [self.mainViewController viewDidAppear:animated];
            }
            
            [disappearingViewController viewDidDisappear:animated];
            [self removeTapViewOverlay];
            
            if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.mainViewController];
        }
        
    }else{
        if (viewEvents) {
            [self.mainViewController viewDidAppear:animated];
        }
        [disappearingViewController viewDidDisappear:animated];
    }
}

@end
