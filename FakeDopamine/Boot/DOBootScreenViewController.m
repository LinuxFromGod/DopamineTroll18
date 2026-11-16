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

    __weak typeof(self) weakSelf = self;
    self.progressFillWidth.constant = self.progressTrack.bounds.size.width;

    [UIView animateWithDuration:self.duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        [weakSelf.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf finish];
        });
    }];
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
