//
//  DOPanicScreenViewController.m
//  Dopamine
//

#import "DOPanicScreenViewController.h"
#import <sys/utsname.h>

@interface DOPanicScreenViewController ()
@property (nonatomic, strong) UIImageView *logoView;
@property (nonatomic, strong) UITextView *panicTextView;
@property (nonatomic, copy) void (^completionBlock)(void);
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) NSArray<NSString *> *panicLines;
@end

@implementation DOPanicScreenViewController

+ (void)presentPanicWithCompletion:(void(^)(void))completion
{
    UIWindowScene *windowScene = (UIWindowScene *)[[[UIApplication sharedApplication] connectedScenes] anyObject];

    DOPanicScreenViewController *panicVC = [[self alloc] init];
    panicVC.completionBlock = completion;

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.rootViewController = panicVC;
    window.windowLevel = UIWindowLevelAlert + 100;
    window.backgroundColor = [UIColor blackColor];
    [window makeKeyAndVisible];
    panicVC.overlayWindow = window;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    self.logoView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"apple.logo"]];
    self.logoView.tintColor = [UIColor whiteColor];
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.logoView];

    [NSLayoutConstraint activateConstraints:@[
        [self.logoView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.logoView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:150],
        [self.logoView.widthAnchor constraintEqualToConstant:60],
        [self.logoView.heightAnchor constraintEqualToConstant:60],
    ]];

    self.panicTextView = [[UITextView alloc] init];
    self.panicTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.panicTextView.backgroundColor = [UIColor clearColor];
    self.panicTextView.textColor = [UIColor whiteColor];
    self.panicTextView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    self.panicTextView.editable = NO;
    [self.view addSubview:self.panicTextView];

    [NSLayoutConstraint activateConstraints:@[
        [self.panicTextView.topAnchor constraintEqualToAnchor:self.logoView.bottomAnchor constant:40],
        [self.panicTextView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.panicTextView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.panicTextView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20],
    ]];

    self.panicLines = [self generatePanicLines];

    // A real panic freezes for a beat before any output appears
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self typeOutPanicLines];
    });
}

- (NSArray<NSString *> *)generatePanicLines
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machine = [NSString stringWithUTF8String:systemInfo.machine];

    NSString *caller = [self randomHexBlock];

    NSMutableArray *lines = [NSMutableArray arrayWithArray:@[
        [NSString stringWithFormat:@"panic(cpu %d caller 0x%@): AMFI: code signature invalid: entry point does not satisfy Apple's requirements", arc4random_uniform(6), caller],
        [NSString stringWithFormat:@"      %s /var/jb/basebin/launchdhook.dylib: 0x%04x -> 0x%04x (valid page but not Apple-signed)", machine.UTF8String, arc4random_uniform(0xFFFF), arc4random_uniform(0xFFFF)],
        @"Debugger message: panic",
        @"Memory ID: 0x6",
        [NSString stringWithFormat:@"OS release: %s", NSProcessInfo.processInfo.operatingSystemVersionString.UTF8String],
        @"Kernel version:",
        [NSString stringWithFormat:@"    Darwin Kernel Version 23.4.0: %@", [self randomDateString]],
        @"** PANIC IF INCORRECT: a freed zone element was modified",
        [NSString stringWithFormat:@"    Zone: %@  Element: 0x%@  Corrupt value: 0x%@", [self randomChoice:@[@"kalloc.64", @"kalloc.128", @"ipc.kmsgs", @"IOSurface"]], [self randomHexBlock], [self randomHexBlock]],
        @"    Kernel flags: 0x%x", // placeholder, replaced below
        @"Last port: 0x%@",
        @"Backup port: 0x%@",
        @"** PANIC CPU %d: waiting for debugger or reboot",
    ]];

    // fix the placeholder entries with real random values
    lines[9]  = [NSString stringWithFormat:@"    Kernel flags: 0x%08x", arc4random_uniform(UINT16_MAX)];
    lines[10] = [NSString stringWithFormat:@"Last port: 0x%@", [self randomHexBlock]];
    lines[11] = [NSString stringWithFormat:@"Backup port: 0x%@", [self randomHexBlock]];
    lines[12] = [NSString stringWithFormat:@"** PANIC CPU %d: waiting for debugger or reboot", arc4random_uniform(6)];

    return lines;
}

- (NSString *)randomHexBlock
{
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < 16; i++) {
        [hex appendFormat:@"%x", arc4random_uniform(16)];
    }
    return hex;
}

- (NSString *)randomDateString
{
    NSArray *dates = @[@"Sun Mar 10 21:07:02 EDT 2024", @"Tue Apr 30 05:12:44 PDT 2024", @"Mon Sep 9 14:03:21 PDT 2024"];
    return dates[arc4random_uniform((uint32_t)dates.count)];
}

- (NSString *)randomChoice:(NSArray *)array
{
    return array[arc4random_uniform((uint32_t)array.count)];
}

- (void)typeOutPanicLines
{
    // logo vanishes like the display going into panic dump mode
    [UIView animateWithDuration:0.4 animations:^{
        self.logoView.alpha = 0;
    }];

    __block NSUInteger index = 0;
    __weak typeof(self) weakSelf = self;

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.28 * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(timer, ^{
        if (index >= weakSelf.panicLines.count) {
            dispatch_source_cancel(timer);

            // hold the panic on screen, then hand over to the reboot
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                void (^completionBlock)() = weakSelf.completionBlock;
                [UIView animateWithDuration:0.5 animations:^{
                    weakSelf.overlayWindow.alpha = 0.0;
                } completion:^(BOOL finished) {
                    weakSelf.overlayWindow.hidden = YES;
                    weakSelf.overlayWindow = nil;
                    if (completionBlock) completionBlock();
                }];
            });
            return;
        }

        NSString *line = weakSelf.panicLines[index++];
        weakSelf.panicTextView.text = [weakSelf.panicTextView.text stringByAppendingString:[line stringByAppendingString:@"\n"]];
        [weakSelf.panicTextView scrollRangeToVisible:NSMakeRange(weakSelf.panicTextView.text.length, 0)];
    });
    dispatch_resume(timer);
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
