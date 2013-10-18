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
    
    CGSize screenSize = [self getScreenBounds];
    
    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(_leftPanelView, _rightPanelView, _mainPanelView);
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:|[_leftPanelView(==%d)]|", (int) screenSize.width] options:0 metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[_leftPanelView(==%d)]|", (int) screenSize.height] options:0 metrics:nil views:viewsDictionary]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:|[_rightPanelView(==%d)]|", (int) screenSize.width] options:0 metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[_rightPanelView(==%d)]|", (int) screenSize.height] options:0 metrics:nil views:viewsDictionary]];
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:[_mainPanelView(==%d)]", (int) screenSize.width] options:0 metrics:nil views:viewsDictionary]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[_mainPanelView(==%d)]|", (int) screenSize.height] options:0 metrics:nil views:viewsDictionary]];
    
    // create constraint for the left edge of the main view
    // we will animate the constant of this constraint for sliding the main view
    _constraintMainViewLeft = [NSLayoutConstraint constraintWithItem:_mainPanelView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0f constant:0.0f];
    
    [self.view addConstraint:_constraintMainViewLeft];
    
    // Setup main layer shadow
    CALayer * layer = _mainPanelView.layer;
    layer.masksToBounds = NO;
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
    layer.shadowOpacity = 0.9f;
    CGRect rect = CGRectMake(0.0f, -40.0f, screenSize.width, screenSize.height+80.0f);
    CGPathRef path = [UIBezierPath bezierPathWithRect:rect].CGPath;
    layer.shadowPath = path;
    layer.shadowRadius = 20.0f;
    
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if( [self.view window] == nil )
    {
        self.delegate = nil;
    }
}

#pragma mark - Child View Controllers

- (void)setMainViewController:(UIViewController *)mainViewController
{
    if( _mainViewController != nil )
    {
        // Clean up
        [_mainViewController removeFromParentViewController];
        _mainViewController.slideViewController = nil;
        [_mainViewController.view removeFromSuperview];
        [_mainViewController release];
    }
    _mainViewController = [mainViewController retain];
    _mainViewController.slideViewController = self;
    [self addChildViewController:_mainViewController];
    
    if( _mainPanelView != nil )
    {
        [self addMainView];
    }
}

- (void)addMainView {
    if (_mainViewController == nil)
        return;

        // Add as subview, if slide view controller view is loaded.
        [self.mainPanelView addSubview:self.mainViewController.view];

    CGSize screenSize = [self getScreenBounds];
    
    UIView* mv = self.mainViewController.view;
    mv.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(mv);
    
    [self.mainPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:|[mv(==%d)]|", (int) screenSize.width] options:0 metrics:nil views:viewsDictionary]];
    [self.mainPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[mv(==%d)]|", (int) screenSize.height] options:0 metrics:nil views:viewsDictionary]];
}

- (void)setLeftViewController:(UIViewController *)leftViewController
{
    if( _leftViewController != nil )
    {
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
    
    if( _leftPanelView != nil )
    {
        [self addLeftView];
    }
}

- (void)addLeftView {
    if (_leftViewController == nil)
        return;

        // Add as subview, if slide view controller view is loaded.
        [self.leftPanelView addSubview:self.leftViewController.view];

    CGSize screenSize = [self getScreenBounds];
    
    UIView* lv = self.leftViewController.view;
    lv.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(lv);
    
    [self.leftPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:|[lv(==%d)]|", (int) screenSize.width] options:0 metrics:nil views:viewsDictionary]];
    [self.leftPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[lv(==%d)]|", (int) screenSize.height] options:0 metrics:nil views:viewsDictionary]];
}

- (void)setRightViewController:(UIViewController *)rightViewController
{
    if( _rightViewController != nil )
    {
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
    
        // Add as subview, if slide view controller view is loaded.
        [self.rightPanelView addSubview:self.rightViewController.view];

    CGSize screenSize = [self getScreenBounds];
    
    UIView* rv = self.rightViewController.view;
    rv.translatesAutoresizingMaskIntoConstraints = NO;
    NSDictionary* viewsDictionary = NSDictionaryOfVariableBindings(rv);
    
    [self.rightPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"H:|[rv(==%d)]|", (int) screenSize.width] options:0 metrics:nil views:viewsDictionary]];
    [self.rightPanelView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|[rv(==%d)]|", (int) screenSize.height] options:0 metrics:nil views:viewsDictionary]];
}

- (void)setMainViewController:(UIViewController *)mainViewController animated:(BOOL)animated
{
    if(!animated)
    {
        self.mainViewController = mainViewController;
        [self showMainViewControllerAnimated:animated];
        return;
    }
    
    CGSize screenSize = [self getScreenBounds];
    float constant = screenSize.width + self.overlapWidth;
    
    if( self.mainViewController != nil )
    {
        // Slide out of sight
        [UIView animateWithDuration:self.slideSpeed
                         animations:^{
                             _constraintMainViewLeft.constant = constant;
                             [self.view layoutIfNeeded];
                         } completion:^(BOOL finished) {
                             // Replace the view controller and slide back in
                             self.mainViewController = mainViewController;
                             [self showMainViewControllerAnimated:animated];
                         }];
                         }
    }

- (CGSize)getScreenBounds {
    return [UIScreen mainScreen].bounds.size;
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
            [self showMainViewControllerAnimated:YES];
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
            [self showMainViewControllerAnimated:YES];
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
            [self showMainViewControllerAnimated:YES];
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
    
    [self.view sendSubviewToBack:self.rightPanelView];
    
    CGSize screenSize = [self getScreenBounds];
    float constant = screenSize.width - self.overlapWidth;

    if( animated )
    {
        [UIView animateWithDuration:self.slideSpeed
                         animations:^{
                             _constraintMainViewLeft.constant = constant;
                             [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            [self addTapViewOverlay];
            if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.leftViewController];
        }];
    }
    else
    {
        _constraintMainViewLeft.constant = constant;
        [self.view layoutIfNeeded];

        [self addTapViewOverlay];
        
        if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
            [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.leftViewController];
    }
}

- (void)showLeftFull {
    CGSize screenSize = [self getScreenBounds];
    float constant = screenSize.width;
    
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
    
    [self.view sendSubviewToBack:self.leftPanelView];
    
    CGSize screenSize = [self getScreenBounds];
    float constant = -screenSize.width + self.overlapWidth;

    if( animated )
    {
        [UIView animateWithDuration:self.slideSpeed
                         animations:^{
                             _constraintMainViewLeft.constant = constant;
                             [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            [self addTapViewOverlay];
            if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.rightViewController];
        }];
    }
    else
    {
        _constraintMainViewLeft.constant = constant;
        [self.view layoutIfNeeded];
        
        [self addTapViewOverlay];
        
        if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
            [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.rightViewController];
    }

}

- (void)showMainViewController
{
    [self showMainViewControllerAnimated:YES];
}

- (void)showMainViewControllerAnimated:(BOOL)animated
{
    self.slidePosition = MKDSlideViewControllerPositionCenter;
    
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
                [self removeTapViewOverlay];
                if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                    [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.mainViewController];
            }];
        }
        else
        {
            _constraintMainViewLeft.constant = 0.0f;
            [self.view layoutIfNeeded];
            
            [self removeTapViewOverlay];
            
            if( [self.delegate respondsToSelector:@selector(slideViewController:didSlideToViewController:)] )
                [self.delegate performSelector:@selector(slideViewController:didSlideToViewController:) withObject:self withObject:self.mainViewController];
        }
        
    }
}

@end
