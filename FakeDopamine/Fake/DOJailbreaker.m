//
//  DOJailbreaker.m
//  Dopamine
//
//  Created by Lars Fröder on 10.01.24.
//
//  Simulation engine. Produces the same visible log flow as a real Dopamine
//  run ("lyrics" + optional verbose debug lines), but every step just sleeps
//  for a randomized duration. No exploit code, no system modification.
//

#import "DOJailbreaker.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOPreferenceManager.h"
#import <sys/utsname.h>

// ---------- tuning knobs ----------------------------------------------------

// Probability (0..1) that a run ends in a simulated kernel panic even when
// the panic toggle is off. Small enough to stay rare, big enough to surprise.
static const double kRandomPanicChance = 0.07;

// Extra jitter multiplier range applied randomly to single steps
static const double kHiccupChance = 0.15;

// ----------------------------------------------------------------------------

@interface DOJailbreaker ()
@property (nonatomic, assign) BOOL didFinish;
@property (nonatomic, strong) NSArray<NSString *> *kernelExploitNames;
@property (nonatomic, strong) NSArray<NSString *> *pacBypassNames;
@property (nonatomic, strong) NSArray<NSString *> *pplBypassNames;
@end

@implementation DOJailbreaker

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Names lifted from the real exploit bundles shipped with Dopamine
        _kernelExploitNames = @[@"kfd, landa", @"kfd, smith", @"kfd, physpuppet", @"weightBufs", @"multicast_bytecopy", @"ClearSword", @"DarkSword"];
        _pacBypassNames     = @[@"badRecovery"];
        _pplBypassNames     = @[@"dmaFail", @"Titan", @"momentarius", @"opcodes"];
    }
    return self;
}

#pragma mark - Random helpers

- (double)randomProbability
{
    return (double)arc4random() / UINT32_MAX;
}

- (double)randomBetween:(double)low and:(double)high
{
    return low + [self randomProbability] * (high - low);
}

- (NSTimeInterval)jittered:(NSTimeInterval)duration
{
    NSTimeInterval result = [self randomBetween:duration * 0.8 and:duration * 1.2];
    if ([self randomProbability] < kHiccupChance) {
        // occasional slow step, like memory pressure on a real device
        result += [self randomBetween:1.5 and:4.5];
    }
    return result;
}

- (void)sendVisibleLog:(NSString *)log
{
    [[DOUIManager sharedInstance] sendLog:log debug:NO];
}

- (void)sendDebugLog:(NSString *)log
{
    [[DOUIManager sharedInstance] sendLog:log debug:YES];
}

- (void)visibleStep:(NSString *)log forDuration:(NSTimeInterval)duration
{
    [self sendVisibleLog:log];
    [NSThread sleepForTimeInterval:[self jittered:duration]];
}

- (NSString *)randomHex:(NSUInteger)digits
{
    NSMutableString *hex = [NSMutableString stringWithCapacity:digits];
    NSString *charset = @"0123456789abcdef";
    for (NSUInteger i = 0; i < digits; i++) {
        [hex appendFormat:@"%C", [charset characterAtIndex:arc4random_uniform((uint32_t)charset.length)]];
    }
    return hex;
}

- (NSString *)randomChoice:(NSArray *)array
{
    return array[arc4random_uniform((uint32_t)array.count)];
}

// "kfd.landa" -> "kfd, landa", matching how the real app names exploits
- (NSString *)displayNameForExploitIdentifier:(NSString *)identifier
{
    return [identifier stringByReplacingOccurrencesOfString:@"." withString:@", "];
}

#pragma mark - Exploit selection (mirrors the settings selectors)

- (NSString *)selectedKernelExploit
{
    NSString *selected = [[DOPreferenceManager sharedManager] preferenceValueForKey:@"selectedKernelExploit"];
    return selected ?: @"kfd.landa";
}

- (NSString *)selectedPACBypass
{
    NSString *selected = [[DOPreferenceManager sharedManager] preferenceValueForKey:@"selectedPACBypass"];
    return selected ?: @"none";
}

- (NSString *)selectedPPLBypass
{
    NSString *selected = [[DOPreferenceManager sharedManager] preferenceValueForKey:@"selectedPPLBypass"];
    return selected ?: @"dmaFail";
}

#pragma mark - The show

- (void)runWithError:(NSError **)errOut didRemoveJailbreak:(BOOL*)didRemove showLogs:(BOOL *)showLogs
{
    *errOut = nil;
    *didRemove = NO;
    *showLogs = YES;

    DOPreferenceManager *prefManager = [DOPreferenceManager sharedManager];
    BOOL removeJailbreakEnabled = [prefManager boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO];
    BOOL tweaksEnabled = [prefManager boolPreferenceValueForKey:@"tweakInjectionEnabled" fallback:YES];
    BOOL appJITEnabled = [prefManager boolPreferenceValueForKey:@"appJITEnabled" fallback:YES];
    NSNumber *jetsamMultiplierOption = [prefManager preferenceValueForKey:@"jetsamMultiplier"];

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *startLog = [NSString stringWithFormat:@"Starting Jailbreak (Model: %s, %@, Configuration: {removeJailbreak=%d, tweakInjection=%d, appJIT=%d})", systemInfo.machine, NSProcessInfo.processInfo.operatingSystemVersionString, removeJailbreakEnabled, tweaksEnabled, appJITEnabled];
    [self sendDebugLog:startLog];

    // Store the exploit names that will be announced, so the UI flow matches
    // whatever the user picked in settings
    BOOL isArm64e = [[DOEnvironmentManager sharedManager] isArm64e];

    if (removeJailbreakEnabled) {
        // Fake removal flow: wipe the "bootstrap" including the package
        // manager choice, so the next run goes through bootstrap extraction
        // again, exactly like a real removal
        [self visibleStep:DOLocalizedString(@"Removing Jailbreak") forDuration:4.0];
        [[DOUIManager sharedInstance] resetPackageManagers];
        [prefManager setPreferenceValue:@NO forKey:@"removeJailbreakEnabled"];
        [prefManager removePreferenceValueForKey:@"fakeJailbroken"];
        [prefManager removePreferenceValueForKey:@"fakeBootstrapped"];
        [prefManager removePreferenceValueForKey:@"fakeJailbrokenVersion"];
        *didRemove = YES;
        return;
    }

    // Patchfinding
    [self visibleStep:DOLocalizedString(@"Patchfinding") forDuration:2.4];
    [self sendDebugLog:[NSString stringWithFormat:@"Kernel at /System/Library/Caches/com.apple.kernelcaches/kernelcache"]];
    if ([[DOEnvironmentManager sharedManager] isSPTM]) {
        [self sendDebugLog:@"SPTM at /System/Library/PreinstalledResources/SPTM"];
    }

    // Exploitation
    NSString *kernelExploitName = [self displayNameForExploitIdentifier:[self selectedKernelExploit]];
    [self visibleStep:[NSString stringWithFormat:DOLocalizedString(@"Exploiting Kernel (%@)"), kernelExploitName] forDuration:4.2];
    [self sendDebugLog:[NSString stringWithFormat:@"Got contiguous mapping surface 0x%@", [self randomHex:8]]];
    [self sendDebugLog:[NSString stringWithFormat:@"preserved port? %d", arc4random_uniform(2)]];

    if (isArm64e && ![self.selectedPACBypass isEqualToString:@"none"]) {
        [self visibleStep:[NSString stringWithFormat:DOLocalizedString(@"Bypassing PAC (%@)"), self.selectedPACBypass] forDuration:1.4];
    }

    NSString *pplBypassName = [self selectedPPLBypass];
    if ([[DOEnvironmentManager sharedManager] isSPTM]) {
        [self visibleStep:[NSString stringWithFormat:DOLocalizedString(@"Bypassing SPTM (%@)"), pplBypassName] forDuration:2.1];
    }
    else {
        [self visibleStep:[NSString stringWithFormat:DOLocalizedString(@"Bypassing PPL (%@)"), pplBypassName] forDuration:2.1];
    }

    // Primitives & cleanup
    [self visibleStep:DOLocalizedString(@"Building Phys R/W Primitive") forDuration:2.0];
    [self visibleStep:DOLocalizedString(@"Cleaning Up Exploits") forDuration:1.0];
    [self visibleStep:DOLocalizedString(@"Elevating Privileges") forDuration:1.2];

    // Bootstrap only happens on the first run, like on a real device
    if (![DOEnvironmentManager sharedManager].isBootstrapped) {
        [self visibleStep:@"Extracting Bootstrap" forDuration:4.5];
        [self visibleStep:@"Finalizing Bootstrap" forDuration:1.5];
    }

    [self visibleStep:DOLocalizedString(@"Loading BaseBin TrustCache") forDuration:0.7];

    // Removal toggle was reset above; jailbroken state is set after this point
    [self visibleStep:DOLocalizedString(@"Initializing Environment") forDuration:2.2];

    if (!tweaksEnabled) {
        [self sendDebugLog:@"Creating safe mode marker file since tweaks were disabled in settings"];
    }

    [self visibleStep:DOLocalizedString(@"Initializing Protection") forDuration:1.0];
    [self visibleStep:DOLocalizedString(@"Applying Bind Mount") forDuration:1.2];
    [self visibleStep:DOLocalizedString(@"Checking For Duplicate Apps") forDuration:0.9];

    if (jetsamMultiplierOption) {
        [self sendDebugLog:[NSString stringWithFormat:@"jetsam multiplier: %@", jetsamMultiplierOption]];
    }
    if (!appJITEnabled) {
        [self sendDebugLog:@"App JIT was disabled in settings"];
    }

    [self sendDebugLog:@"Done!"];
}

- (void)finalize
{
    // Called right after fadeToBlack: the real app userspace-reboots here,
    // the simulation hands over to the boot/panic screens
    [[DOEnvironmentManager sharedManager] setJailbroken:YES withVersion:nil];
    self.didFinish = YES;
}

- (BOOL)shouldKernelPanic
{
    BOOL panicEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"panicModeEnabled" fallback:NO];
    if (panicEnabled) return YES;
    return [self randomProbability] < kRandomPanicChance;
}

@end
