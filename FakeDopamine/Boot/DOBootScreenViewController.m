//
//  DOBootScreenViewController.m
//  Dopamine
//

#import "DOBootScreenViewController.h"
#import "DOThemeManager.h"
#import "DOUIManager.h"

@interface DOBootScreenViewController ()
@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressFill;
@property (nonatomic, strong) NSLayoutConstraint *progressFillWidth;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy) void (^completionBlock)(void);
@property (nonatomic, strong) UIWindow *overlayWindow;
@end

@implementation DOBootScreenViewController

+ (void)presentBootWithDuration:(NSTimeInterval)duration completion:(void(^)(void))completion
{
    UIWindowScene *windowScene = (UIWindowScene *)[[[UIApplication sharedApplication] connectedScenes] anyObject];

    DOBootScreenViewController *bootVC = [[self alloc] init];
    bootVC.duration = duration;
    bootVC.completionBlock = completion;

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.rootViewController = bootVC;
    window.windowLevel = UIWindowLevelAlert + 100;
    window.backgroundColor = [UIColor blackColor];
    [window makeKeyAndVisible];

    bootVC.overlayWindow = window;

    [UIView animateWithDuration:0.4 animations:^{
        window.alpha = 1.0;
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    BOOL bootlogoEnabled = [[DOUIManager sharedInstance] isBootlogoEnabled];

    self.logoView = [[UIImageView alloc] init];
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoView.contentMode = UIViewContentModeScaleAspectFit;
    if (bootlogoEnabled) {
        // Same logo the real jailbreak writes to the boot chain
        self.logoView.image = [[DOUIManager sharedInstance] renderBootLogo];
    }
    else {
        // Default boot look: plain Apple logo on black
        self.logoView.image = [UIImage systemImageNamed:@"apple.logo"];
        self.logoView.tintColor = [UIColor whiteColor];
    }
    [self.view addSubview:self.logoView];

    self.progressTrack = [[UIView alloc] init];
    self.progressTrack.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressTrack.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    self.progressTrack.layer.cornerRadius = 2.0;
    self.progressTrack.layer.masksToBounds = YES;
    [self.view addSubview:self.progressTrack];

    self.progressFill = [[UIView alloc] init];
    self.progressFill.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressFill.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    [self.progressTrack addSubview:self.progressFill];

    self.progressFillWidth = [self.progressFill.widthAnchor constraintEqualToConstant:0.0];
    [NSLayoutConstraint activateConstraints:@[
        self.progressFillWidth,
        [self.progressFill.leadingAnchor constraintEqualToAnchor:self.progressTrack.leadingAnchor],
        [self.progressFill.topAnchor constraintEqualToAnchor:self.progressTrack.topAnchor],
        [self.progressFill.bottomAnchor constraintEqualToAnchor:self.progressTrack.bottomAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [self.logoView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.logoView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.logoView.widthAnchor constraintEqualToConstant:70],
        [self.logoView.heightAnchor constraintEqualToConstant:70],

        [self.progressTrack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.progressTrack.topAnchor constraintEqualToAnchor:self.logoView.bottomAnchor constant:40],
        [self.progressTrack.widthAnchor constraintEqualToConstant:240],
        [self.progressTrack.heightAnchor constraintEqualToConstant:4],
    ]];

    // Boot logo doesn't appear immediately, just like on a real boot
    self.logoView.alpha = 0;
    self.progressTrack.alpha = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.6 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5 animations:^{
            self.logoView.alpha = bootlogoEnabled ? 1.0 : 0.9;
            self.progressTrack.alpha = 1.0;
        }];
        [self startProgress];
    });
}

- (void)startProgress
{
    [self.view layoutIfNeeded];

    // Real boot progress advances in uneven chunks with occasional stalls,
    // not in one linear sweep. Build a random schedule of chunk durations
    // that still spans the requested boot time, then animate segment by
    // segment.
    NSUInteger chunkCount = 6 + arc4random_uniform(4);
    NSMutableArray<NSNumber *> *weights = [NSMutableArray new];
    double weightTotal = 0;
    for (NSUInteger i = 0; i < chunkCount; i++) {
        // Skewed weights make some chunks stall noticeably longer
        double weight = 0.6 + (double)arc4random() / UINT32_MAX * 1.8;
        weightTotal += weight;
        [weights addObject:@(weight)];
    }

    CGFloat trackWidth = self.progressTrack.bounds.size.width;
    __weak typeof(self) weakSelf = self;

    __block double cumulativeTime = 0;
    __block double fraction = 0;
    for (NSUInteger i = 0; i < chunkCount; i++) {
        double chunkDuration = self.duration * (weights[i].doubleValue / weightTotal);
        double segmentStart = cumulativeTime;
        cumulativeTime += chunkDuration;
        fraction = (i + 1 == chunkCount)
            ? 1.0
            : MIN(0.96, fraction + (1.0 / chunkCount) * (0.85 + (double)arc4random() / UINT32_MAX * 0.3));
        double targetFraction = fraction;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(segmentStart * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!weakSelf)
                return;
            weakSelf.progressFillWidth.constant = trackWidth * targetFraction;
            [UIView animateWithDuration:chunkDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
                [weakSelf.view layoutIfNeeded];
            } completion:nil];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((cumulativeTime + 0.8) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf finish];
    });
}

- (void)finish
{
    void (^completionBlock)() = self.completionBlock;

    // Fade the overlay away; relaunch happens right after, so the user
    // perceives the app "starting fresh" after a reboot
    [UIView animateWithDuration:0.3 animations:^{
        self.overlayWindow.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.overlayWindow.hidden = YES;
        self.overlayWindow = nil;
        if (completionBlock) completionBlock();
    }];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

@end
