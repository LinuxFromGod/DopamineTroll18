//
//  DOCreditsViewController.m
//  Dopamine
//
//  Created by tomt000 on 08/01/2024.
//

#import "DOCreditsViewController.h"
#import "DOUIStyle.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOGlobalAppearance.h"

@interface DOCreditsViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@end

@implementation DOCreditsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [DOUIStyle setupViewControllerStyle:self];

    UIView *header = [DOUIStyle makeHeader:DOLocalizedString(@"Menu_Credits_Title") withTarget:self];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:5],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:70]
    ]];

    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = [NSString stringWithFormat:@"LARPMINE %@ - Simulation by LinuxFromGod", [[DOEnvironmentManager sharedManager] appVersionDisplayString]];
    versionLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    versionLabel.textColor = [UIColor whiteColor];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:versionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [versionLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [versionLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],
        [versionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20],
        [versionLabel.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:15]
    ]];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:10],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    // Ordered array instead of a dictionary: dictionary enumeration order is
    // random, which made the credits list reorder on every launch.
    NSArray<NSDictionary *> *people = @[
        @{ @"name": @"LinuxFromGod", @"role": @"LARPMINE", @"url": @"https://github.com/LinuxFromGod" },
        @{ @"name": @"@holygentoo", @"role": @"Telegram", @"url": @"https://t.me/holygentoo" },
        @{ @"name": @"opa334", @"role": @"Dopamine", @"url": @"https://github.com/opa334" },
        @{ @"name": @"tomt000", @"role": @"UI design", @"url": @"https://github.com/tomt000" },
        @{ @"name": @"@xina520", @"role": @"weightBufs base", @"url": @"https://github.com/xina520" },
        @{ @"name": @"@08Tc3wBB", @"role": @"kfd exploit", @"url": @"https://github.com/08Tc3wBB" },
        @{ @"name": @"@tanprathan", @"role": @"momentarius", @"url": @"https://github.com/tanprathan" },
        @{ @"name": @"@BomberFish", @"role": @"ClearSword", @"url": @"https://github.com/BomberFish" },
        @{ @"name": @"@mintzyd", @"role": @"DMA failures", @"url": @"https://github.com/mintzyd" },
    ];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 4;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:15],
        [stack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-25],
        [stack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-40],
    ]];

    for (NSDictionary *person in people) {
        NSString *name = person[@"name"];
        NSString *title = [NSString stringWithFormat:@"%@ (%@)", name, person[@"role"]];
        UIAction *action = [UIAction actionWithTitle:title image:[UIImage systemImageNamed:@"link" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:nil handler:^(__kindof UIAction * _Nonnull act) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:person[@"url"]] options:@{} completionHandler:nil];
        }];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button addAction:action forControlEvents:UIControlEventTouchUpInside];
        button.tintColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button.heightAnchor constraintEqualToConstant:32].active = YES;
        [stack addArrangedSubview:button];
    }
}

- (void)dismiss
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end
