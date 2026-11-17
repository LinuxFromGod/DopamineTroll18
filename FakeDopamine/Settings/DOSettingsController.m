//
//  DOSettingsController.m
//  Dopamine
//
//  Created by tomt000 on 08/01/2024.
//
//  Standalone reimplementation of the settings screen with the same
//  preference keys as the original, but on plain UIKit instead of
//  Preferences.framework.
//

#import "DOSettingsController.h"
#import "DOUIStyle.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOPreferenceManager.h"
#import "DOThemeManager.h"
#import "DOGlobalAppearance.h"
#import "DOPkgManagerPickerViewController.h"
#import "DOCreditsViewController.h"
#import "DOSceneDelegate.h"
#import "DOBootScreenViewController.h"
#import "DOJailbreaker.h"
#import <objc/runtime.h>

@interface DOOptionListController : UIViewController
- (id)initWithTitle:(NSString *)title
                keys:(NSArray *)keys
               names:(NSArray *)names
      preferenceKey:(NSString *)preferenceKey
       defaultIndex:(NSInteger)defaultIndex;
@end

typedef NS_ENUM(NSInteger, DORowKind) {
    DORowSwitch,
    DORowLink,
    DORowButton,
};

@interface DORow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *icon;
@property (nonatomic, assign) DORowKind kind;
@property (nonatomic, copy) NSString *preferenceKey;
@property (nonatomic, assign) BOOL defaultOn;
@property (nonatomic, strong) UIColor *textColor; // DORowButton override, nil = default green
@property (nonatomic, copy) void (^onToggle)(BOOL);
@property (nonatomic, copy) void (^onTap)(void);
@end

@implementation DORow
@end

@interface UISwitch (DORowRefs)
@property (nonatomic, copy) NSString *rowPreferenceKey;
@property (nonatomic, copy) void (^rowToggleBlock)(BOOL);
@end

@interface DOSettingsController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, copy) NSArray<NSArray<DORow *> *> *sections;
@property (nonatomic, copy) NSArray<NSString *> *sectionTitles;
@property (nonatomic, copy) NSString *lastKnownTheme;

- (void)buildSections;
- (void)pushOptionList:(NSString *)title preferenceKey:(NSString *)preferenceKey keys:(NSArray *)keys names:(NSArray *)names defaultIndex:(NSInteger)defaultIndex;
- (void)switchChanged:(UISwitch *)sender;
@end

@implementation DOSettingsController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [DOUIStyle setupViewControllerStyle:self];
    self.lastKnownTheme = [[DOThemeManager sharedInstance] enabledTheme].key;

    UIView *header = [DOUIStyle makeHeader:DOLocalizedString(@"Menu_Settings_Title") withTarget:self];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:5],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:70]
    ]];

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.separatorColor = [UIColor clearColor];
    self.table.backgroundColor = [UIColor clearColor];
    self.table.delegate = self;
    self.table.dataSource = self;
    self.table.rowHeight = 48;
    self.table.estimatedSectionFooterHeight = 10;
    self.table.estimatedSectionHeaderHeight = 30;
    [self.view addSubview:self.table];

    [NSLayoutConstraint activateConstraints:@[
        [self.table.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12],
        [self.table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [self.table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self buildSections];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.lastKnownTheme && ![self.lastKnownTheme isEqualToString:[[DOThemeManager sharedInstance] enabledTheme].key])
    {
        self.lastKnownTheme = [[DOThemeManager sharedInstance] enabledTheme].key;
        NSString *icon = [[DOThemeManager sharedInstance] enabledTheme].icon;
        [[UIApplication sharedApplication] setAlternateIconName:icon completionHandler:^(NSError * _Nullable error) {
            if (error)
                NSLog(@"Error changing app icon: %@", error);
        }];

        // theme change needs a full UI rebuild, exactly like the real app
        [DOSceneDelegate relaunch];
    }
    else {
        [self.table reloadData];
    }
}

#pragma mark - Model

- (void)buildSections
{
    NSMutableArray<NSArray<DORow *> *> *sections = [NSMutableArray new];
    __weak typeof(self) weakSelf = self;

    DORow *(^row)(NSString *, NSString *) = ^DORow *(NSString *title, NSString *icon) {
        DORow *r = [DORow new];
        r.title = title;
        r.icon = icon;
        return r;
    };

    // Exploits
    NSMutableArray *exploits = [NSMutableArray new];
    DORow *kernelExploit = row(DOLocalizedString(@"Kernel Exploit"), @"hammer.fill");
    kernelExploit.kind = DORowLink;
    kernelExploit.onTap = ^{
        [weakSelf pushOptionList:DOLocalizedString(@"Kernel Exploit")
                   preferenceKey:@"selectedKernelExploit"
                            keys:@[@"kfd.landa", @"kfd.smith", @"kfd.physpuppet", @"weightBufs", @"multicast_bytecopy", @"ClearSword", @"DarkSword"]
                           names:@[@"kfd, landa", @"kfd, smith", @"kfd, physpuppet", @"weightBufs", @"multicast_bytecopy", @"ClearSword", @"DarkSword"]
                    defaultIndex:0];
    };
    [exploits addObject:kernelExploit];

    BOOL isArm64e = [[DOEnvironmentManager sharedManager] isArm64e];
    if (isArm64e) {
        DORow *pacBypass = row(DOLocalizedString(@"PAC Bypass"), @"shield.lefthalf.filled");
        pacBypass.kind = DORowLink;
        pacBypass.onTap = ^{
            [weakSelf pushOptionList:DOLocalizedString(@"PAC Bypass")
                       preferenceKey:@"selectedPACBypass"
                                keys:@[@"none", @"badRecovery"]
                               names:@[DOLocalizedString(@"None"), @"badRecovery"]
                        defaultIndex:0];
        };
        [exploits addObject:pacBypass];

        NSString *bypassTitle = [[DOEnvironmentManager sharedManager] isSPTM] ? DOLocalizedString(@"SPTM Bypass") : DOLocalizedString(@"PPL Bypass");
        DORow *pplBypass = row(bypassTitle, @"shield.lefthalf.filled");
        pplBypass.kind = DORowLink;
        pplBypass.onTap = ^{
            [weakSelf pushOptionList:bypassTitle
                       preferenceKey:@"selectedPPLBypass"
                                keys:@[@"dmaFail", @"Titan", @"momentarius", @"opcodes"]
                               names:@[@"dmaFail", @"Titan", @"momentarius", @"opcodes"]
                        defaultIndex:0];
        };
        [exploits addObject:pplBypass];
    }
    [sections addObject:exploits];

    // Jailbreak settings
    NSMutableArray *jbSettings = [NSMutableArray new];
    DORow *tweaks = row(DOLocalizedString(@"Settings_Tweak_Injection"), @"puzzlepiece.extension.fill");
    tweaks.kind = DORowSwitch;
    tweaks.preferenceKey = @"tweakInjectionEnabled";
    tweaks.defaultOn = YES;
    [jbSettings addObject:tweaks];

    DORow *verbose = row(DOLocalizedString(@"Settings_Verbose_Logs"), @"text.justify.left");
    verbose.kind = DORowSwitch;
    verbose.preferenceKey = @"verboseLogsEnabled";
    verbose.defaultOn = NO;
    [jbSettings addObject:verbose];

    DORow *appJIT = row(DOLocalizedString(@"Settings_Apps_JIT"), @"auge");
    appJIT.kind = DORowSwitch;
    appJIT.preferenceKey = @"appJITEnabled";
    appJIT.defaultOn = YES;
    [jbSettings addObject:appJIT];

    DORow *jetsam = row(DOLocalizedString(@"Settings_Jetsam_Multiplier"), @"gauge.with.dial.needle.50percent");
    jetsam.kind = DORowLink;
    jetsam.onTap = ^{
        [weakSelf pushOptionList:DOLocalizedString(@"Settings_Jetsam_Multiplier")
                   preferenceKey:@"jetsamMultiplier"
                            keys:@[@2, @3, @4, @5, @6, @7, @8]
                           names:@[@"1x", @"1.5x", @"2x", @"2.5x", [NSString stringWithFormat:@"3x (%@)", DOLocalizedString(@"Recommended")], @"3.5x", @"4x"]
                    defaultIndex:4];
    };
    [jbSettings addObject:jetsam];

    // Real button (not a toggle): pressing it removes the simulated
    // jailbreak right away, and the main button turns back into "Jailbreak"
    DORow *remove = row(DOLocalizedString(@"Button_Remove_Jailbreak"), @"trash.fill");
    remove.kind = DORowButton;
    remove.textColor = [UIColor colorWithRed:1.0 green:0.27 blue:0.23 alpha:1.0];
    remove.onTap = ^{
        if (![[DOEnvironmentManager sharedManager] isJailbroken]) {
            UIAlertController *info = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Alert_Remove_Not_Jailbroken_Title") message:DOLocalizedString(@"Alert_Remove_Not_Jailbroken_Body") preferredStyle:UIAlertControllerStyleAlert];
            [info addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Close") style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:info animated:YES completion:nil];
            return;
        }

        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:DOLocalizedString(@"Alert_Remove_Jailbreak_Title") message:DOLocalizedString(@"Alert_Remove_Jailbreak_Pressed_Body") preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Continue") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [DOJailbreaker removeSimulatedJailbreak];

            // The removal ends with a userspace reboot, like the real app;
            // after the relaunch the main button reads "Jailbreak" again
            [DOBootScreenViewController presentBootWithDuration:4.0 completion:^{
                [[DOEnvironmentManager sharedManager] performRealRespring];
                [DOSceneDelegate relaunch];
            }];
        }]];
        [confirm addAction:[UIAlertAction actionWithTitle:DOLocalizedString(@"Button_Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [weakSelf presentViewController:confirm animated:YES completion:nil];
    };
    [jbSettings addObject:remove];
    [sections addObject:jbSettings];

    // Simulation (the fake-specific section)
    NSMutableArray *simulation = [NSMutableArray new];
    DORow *panic = row(DOLocalizedString(@"Kernel_Panic"), @"exclamationmark.triangle.fill");
    panic.kind = DORowSwitch;
    panic.preferenceKey = @"panicModeEnabled";
    panic.defaultOn = NO;
    [simulation addObject:panic];
    [sections addObject:simulation];

    // Customization
    NSMutableArray *custom = [NSMutableArray new];
    DORow *theme = row(DOLocalizedString(@"Theme"), @"paintbrush.fill");
    theme.kind = DORowLink;
    theme.onTap = ^{
        [weakSelf pushOptionList:DOLocalizedString(@"Theme")
                   preferenceKey:@"theme"
                            keys:[[DOThemeManager sharedInstance] getAvailableThemeKeys]
                           names:[[DOThemeManager sharedInstance] getAvailableThemeNames]
                    defaultIndex:0];
    };
    [custom addObject:theme];

    DORow *bootlogo = row(DOLocalizedString(@"Custom_Boot_Logo"), @"apple.logo");
    bootlogo.kind = DORowSwitch;
    bootlogo.preferenceKey = @"bootlogoEnabled";
    bootlogo.defaultOn = YES;
    [custom addObject:bootlogo];

    DORow *pkg = row(DOLocalizedString(@"Button_Reinstall_Package_Managers"), @"shippingbox");
    pkg.kind = DORowLink;
    pkg.onTap = ^{
        [weakSelf.navigationController pushViewController:[[DOPkgManagerPickerViewController alloc] init] animated:YES];
    };
    [custom addObject:pkg];
    [sections addObject:custom];

    // Actions
    NSMutableArray *actions = [NSMutableArray new];
    DORow *credits = row(DOLocalizedString(@"Menu_Credits_Title"), @"info.circle.fill");
    credits.kind = DORowLink;
    credits.onTap = ^{
        [weakSelf.navigationController pushViewController:[[DOCreditsViewController alloc] init] animated:YES];
    };
    [actions addObject:credits];

    DORow *reset = row(DOLocalizedString(@"Button_Reset_Settings"), @"arrow.counterclockwise");
    reset.kind = DORowButton;
    reset.onTap = ^{
        [[UIApplication sharedApplication] setAlternateIconName:nil completionHandler:nil];
        [[DOUIManager sharedInstance] resetSettings];
        [DOSceneDelegate relaunch];
    };
    [actions addObject:reset];
    [sections addObject:actions];

    self.sections = sections;
    self.sectionTitles = @[
        DOLocalizedString(@"Section_Exploits"),
        DOLocalizedString(@"Section_Jailbreak_Settings"),
        DOLocalizedString(@"Section_Simulation"),
        DOLocalizedString(@"Section_Customization"),
        DOLocalizedString(@"Section_Actions")
    ];
}

#pragma mark - Push helper

- (void)pushOptionList:(NSString *)title preferenceKey:(NSString *)preferenceKey keys:(NSArray *)keys names:(NSArray *)names defaultIndex:(NSInteger)defaultIndex
{
    DOOptionListController *listVC = [[DOOptionListController alloc] initWithTitle:title keys:keys names:names preferenceKey:preferenceKey defaultIndex:defaultIndex];
    [self.navigationController pushViewController:listVC animated:YES];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.sections[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section >= self.sectionTitles.count)
        return nil;
    return self.sectionTitles[section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section < self.sectionTitles.count &&
        [self.sectionTitles[section] isEqualToString:DOLocalizedString(@"Section_Simulation")]) {
        return DOLocalizedString(@"Panic_Mode_Footer");
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if (![view isKindOfClass:[UITableViewHeaderFooterView class]])
        return;

    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    header.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuse = @"row";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
        cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        cell.contentView.backgroundColor = [UIColor clearColor];
    }

    DORow *row = self.sections[indexPath.section][indexPath.row];
    cell.textLabel.text = row.title;
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.textAlignment = NSTextAlignmentNatural;
    cell.imageView.image = [UIImage systemImageNamed:row.icon withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
    cell.imageView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.8];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    switch (row.kind) {
        case DORowSwitch: {
            UISwitch *toggle = [[UISwitch alloc] init];
            id value = [[DOPreferenceManager sharedManager] preferenceValueForKey:row.preferenceKey];
            toggle.on = value ? [value boolValue] : row.defaultOn;
            [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            toggle.rowPreferenceKey = row.preferenceKey;
            toggle.rowToggleBlock = row.onToggle;
            cell.accessoryView = toggle;
            break;
        }
        case DORowLink:
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
            break;
        case DORowButton:
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.textColor = row.textColor ?: [UIColor colorWithRed:0.0 green:0.66 blue:0.53 alpha:1.0];
            break;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DORow *row = self.sections[indexPath.section][indexPath.row];
    if (row.onTap) row.onTap();
}

- (void)switchChanged:(UISwitch *)sender
{
    [[DOPreferenceManager sharedManager] setPreferenceValue:@(sender.on) forKey:sender.rowPreferenceKey];
    if (sender.rowToggleBlock) sender.rowToggleBlock(sender.on);
}

- (void)dismiss
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Status bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

@end

#pragma mark - Associated helpers on UISwitch

@implementation UISwitch (DORowRefs)

static char kDORowPreferenceKeyKey;
static char kDORowToggleBlockKey;

- (void)setRowPreferenceKey:(NSString *)rowPreferenceKey
{
    objc_setAssociatedObject(self, &kDORowPreferenceKeyKey, rowPreferenceKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)rowPreferenceKey
{
    return objc_getAssociatedObject(self, &kDORowPreferenceKeyKey);
}

- (void)setRowToggleBlock:(void (^)(BOOL))rowToggleBlock
{
    objc_setAssociatedObject(self, &kDORowToggleBlockKey, rowToggleBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(BOOL))rowToggleBlock
{
    return objc_getAssociatedObject(self, &kDORowToggleBlockKey);
}

@end

#pragma mark - Generic option list screen

@implementation DOOptionListController
{
    NSArray *_keys;
    NSArray *_names;
    NSString *_preferenceKey;
    NSString *_title;
    NSInteger _defaultIndex;
    NSMutableArray<UIButton *> *_optionRows;
}

- (id)initWithTitle:(NSString *)title keys:(NSArray *)keys names:(NSArray *)names preferenceKey:(NSString *)preferenceKey defaultIndex:(NSInteger)defaultIndex
{
    if (self = [super init]) {
        _title = title;
        _keys = keys;
        _names = names;
        _preferenceKey = preferenceKey;
        _defaultIndex = defaultIndex;
        _optionRows = [NSMutableArray new];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [DOUIStyle setupViewControllerStyle:self];

    UIView *header = [DOUIStyle makeHeader:_title withTarget:self];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:header];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:5],
        [header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [header.heightAnchor constraintEqualToConstant:70]
    ]];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:scrollView];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:12],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-20],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-40],
    ]];

    id selected = [[DOPreferenceManager sharedManager] preferenceValueForKey:_preferenceKey];
    NSUInteger selectedIndex = (NSUInteger)MAX(0, MIN((NSInteger)_keys.count - 1, _defaultIndex));
    if (selected) {
        for (NSUInteger i = 0; i < _keys.count; i++) {
            if ([[NSString stringWithFormat:@"%@", _keys[i]] isEqualToString:[NSString stringWithFormat:@"%@", selected]]) {
                selectedIndex = i;
                break;
            }
        }
    }

    for (NSUInteger i = 0; i < _keys.count; i++) {
        UIButton *optionRow = [DOUIStyle optionRowWithTitle:_names[i] checked:(i == selectedIndex)];
        optionRow.translatesAutoresizingMaskIntoConstraints = NO;
        [optionRow.heightAnchor constraintEqualToConstant:44].active = YES;
        optionRow.tag = (NSInteger)i;
        [optionRow addTarget:self action:@selector(optionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:optionRow];
        [_optionRows addObject:optionRow];
    }
}

- (void)optionTapped:(UIButton *)sender
{
    NSUInteger index = (NSUInteger)sender.tag;
    [[DOPreferenceManager sharedManager] setPreferenceValue:_keys[index] forKey:_preferenceKey];

    for (NSUInteger i = 0; i < _optionRows.count; i++) {
        UIButton *row = _optionRows[i];
        UIImage *image = [UIImage systemImageNamed:(i == index ? @"checkmark.circle.fill" : @"circle") withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
        [row setImage:image forState:UIControlStateNormal];
    }

    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator impactOccurred];

    // Matches the original Preferences list behavior: pick and go back
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
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
