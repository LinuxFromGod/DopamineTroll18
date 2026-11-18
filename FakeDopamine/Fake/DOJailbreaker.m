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
#import <unistd.h>

// ---------- tuning knobs ----------------------------------------------------

// Probability (0..1) that a run ends in a simulated kernel panic even when
// the panic toggle is off. Small enough to stay rare, big enough to surprise.
static const double kRandomPanicChance = 0.07;

// Probability (0..1) that a run fails at a realistic point, using the same
// errors users reported in the upstream issue tracker (#887, #899, #912,
// #895, #1022, #1031, #906, #936).
static const double kFailureChance = 0.10;

// Extra jitter multiplier range applied randomly to single steps
static const double kHiccupChance = 0.15;

// ----------------------------------------------------------------------------

// Where a failing run aborts, mirroring real failure reports
typedef NS_ENUM(NSInteger, DOFailurePoint) {
    DOFailurePointNone,
    DOFailurePointKernelcache,  // "Failed to find kernelcache" (#887, #899, #834)
    DOFailurePointPPL,          // "Failed to bypass PPL" (#912, #895, #1022)
    DOFailurePointBasebin,      // basebin deletion error on re-jailbreak (#906, #936)
};

// Trustcache struct offsets and symbol address observed in real logs
static NSString * const kTrustcacheStructLines[] = {
    @"0x0000000000000028 <- kernelStruct.trustcache.struct_size",
    @"0x0000000000000008 <- kernelStruct.trustcache.prevptr",
    @"0x0000000000000020 <- kernelStruct.trustcache.fileptr",
    @"0x0000000000000010 <- kernelStruct.trustcache.type",
    @"0x0000000000000018 <- kernelStruct.trustcache.size",
};
static NSString * const kTxmTrustcacheSymbolLine =
    @"0xfffffff0170104b8 <- kernelSymbol.txm_trustcache_root";

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

// Debug lines in real logs carry the standard NSLog prefix, e.g.
// "2026-09-28 08:04:55.033 Dopamine[555:16444] Kernel at ..."
- (NSString *)timestampedDebug:(NSString *)message
{
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return [NSString stringWithFormat:@"%@ Dopamine[%d:%d] %@",
            [formatter stringFromDate:[NSDate date]], getpid(),
            (int)(1000 + arc4random_uniform(999000)), message];
}

// Real logs show the kernelcache either in the preboot kernel cache or in the
// app container's Documents folder
- (NSString *)randomKernelcachePath
{
    if (arc4random_uniform(2) == 0) {
        return [NSString stringWithFormat:@"/private/preboot/%@/System/Library/Caches/com.apple.kernelcaches/kernelcache", [self randomHex:48]];
    }
    return [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@/Documents/kernelcache", [[NSUUID UUID] UUIDString]];
}

// The trustcache offset lines every real run prints while exploiting
- (void)sendTrustcacheDebugLines
{
    if ([[DOEnvironmentManager sharedManager] isSPTM]) {
        [self sendDebugLog:kTxmTrustcacheSymbolLine];
    }
    for (NSUInteger i = 0; i < sizeof(kTrustcacheStructLines) / sizeof(kTrustcacheStructLines[0]); i++) {
        [self sendDebugLog:kTrustcacheStructLines[i]];
    }
}

- (NSError *)failureErrorForPoint:(DOFailurePoint)point
{
    // Exact errors from the upstream issue tracker
    switch (point) {
        case DOFailurePointKernelcache:
            return [NSError errorWithDomain:@"JBErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to find kernelcache. Ensure your device is properly connected to the internet. If it still does not work, try installing Dopamine via TrollStore instead."}];
        case DOFailurePointPPL:
            return [NSError errorWithDomain:@"JBErrorDomain" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"Failed to bypass PPL"}];
        case DOFailurePointBasebin:
            return [NSError errorWithDomain:@"BootstrapErrorDomain" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"Failed deleting existing basebin file with error: \u201cbasebin\u201d couldn\u2019t be removed."}];
        default:
            return nil;
    }
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
    if (errOut) *errOut = nil;
    if (didRemove) *didRemove = NO;
    if (showLogs) *showLogs = YES;

    DOPreferenceManager *prefManager = [DOPreferenceManager sharedManager];
    BOOL tweaksEnabled = [prefManager boolPreferenceValueForKey:@"tweakInjectionEnabled" fallback:YES];
    BOOL appJITEnabled = [prefManager boolPreferenceValueForKey:@"appJITEnabled" fallback:YES];
    NSNumber *jetsamMultiplierOption = [prefManager preferenceValueForKey:@"jetsamMultiplier"];

    // Decide once whether this run fails, and where, so the branch taken is
    // consistent for the whole run
    DOFailurePoint failurePoint = DOFailurePointNone;
    if ([self randomProbability] < kFailureChance) {
        double pick = [self randomProbability];
        if (pick < 0.4) failurePoint = DOFailurePointKernelcache;
        else if (pick < 0.8) failurePoint = DOFailurePointPPL;
        else failurePoint = DOFailurePointBasebin;

        // Deleting an old basebin only makes sense when one already exists
        if (failurePoint == DOFailurePointBasebin && ![DOEnvironmentManager sharedManager].isBootstrapped) {
            failurePoint = DOFailurePointPPL;
        }
    }

    struct utsname systemInfo;
    uname(&systemInfo);
    // Same start line shape as real runs (issue #1022, #895, #936):
    // Starting Jailbreak (Model: iPhone15,3, Version 17.0 (Build 21A329),
    // Configuration: {removeJailbreak=0, tweakInjection=1, idownload=0, appJIT=1})
    NSString *startLog = [NSString stringWithFormat:@"Starting Jailbreak (Model: %s, %@, Configuration: {removeJailbreak=%d, tweakInjection=%d, idownload=0, appJIT=%d})",
                          systemInfo.machine,
                          NSProcessInfo.processInfo.operatingSystemVersionString,
                          [prefManager boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO],
                          tweaksEnabled,
                          appJITEnabled];
    [self sendDebugLog:startLog];

    // Store the exploit names that will be announced, so the UI flow matches
    // whatever the user picked in settings
    BOOL isArm64e = [[DOEnvironmentManager sharedManager] isArm64e];

    // Downloading the kernelcache, like real 3.x runs
    [self visibleStep:DOLocalizedString(@"Downloading Kernel") forDuration:1.6];
    if (failurePoint == DOFailurePointKernelcache) {
        [self sendDebugLog:[self timestampedDebug:@"Kernelcache could not be downloaded"]];
        *errOut = [self failureErrorForPoint:failurePoint];
        return;
    }
    [self sendDebugLog:[self timestampedDebug:[NSString stringWithFormat:@"Kernel at %@", [self randomKernelcachePath]]]];

    // Patchfinding
    [self visibleStep:DOLocalizedString(@"Patchfinding") forDuration:2.4];
    if ([[DOEnvironmentManager sharedManager] isSPTM]) {
        [self sendDebugLog:[self timestampedDebug:@"SPTM at /System/Library/PreinstalledResources/SPTM"]];
    }

    // Exploitation
    NSString *kernelExploitName = [self displayNameForExploitIdentifier:[self selectedKernelExploit]];
    [self visibleStep:[NSString stringWithFormat:DOLocalizedString(@"Exploiting Kernel (%@)"), kernelExploitName] forDuration:4.2];
    [self sendDebugLog:[NSString stringWithFormat:@"Got contiguous mapping surface 0x%@", [self randomHex:8]]];
    [self sendTrustcacheDebugLines];
    [self sendDebugLog:[NSString stringWithFormat:@"preserved port? %d", arc4random_uniform(2)]];

    if (failurePoint == DOFailurePointBasebin) {
        // Re-jailbreak over an existing "bootstrap": the old basebin is
        // deleted first, and that is where real runs #906/#936 failed
        [self sendDebugLog:[self timestampedDebug:@"Deleting existing basebin"]];
        [NSThread sleepForTimeInterval:[self jittered:1.0]];
        *errOut = [self failureErrorForPoint:failurePoint];
        return;
    }

    if (isArm64e && ![self.selectedPACBypass isEqualToString:@"none"]) {
        [self visibleStep:[NSString stringWithFormat:DOLocalizedString(@"Bypassing PAC (%@)"), self.selectedPACBypass] forDuration:1.4];
    }

    NSString *pplBypassName = [self selectedPPLBypass];
    NSString *bypassStep = [[DOEnvironmentManager sharedManager] isSPTM]
        ? [NSString stringWithFormat:DOLocalizedString(@"Bypassing SPTM (%@)"), pplBypassName]
        : [NSString stringWithFormat:DOLocalizedString(@"Bypassing PPL (%@)"), pplBypassName];
    [self visibleStep:bypassStep forDuration:2.1];
    if (failurePoint == DOFailurePointPPL) {
        // Real runs fail right after the bypass announcement (#912)
        [self sendDebugLog:[self timestampedDebug:@"PPL bypass returned no primitive"]];
        *errOut = [self failureErrorForPoint:failurePoint];
        return;
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

+ (void)removeSimulatedJailbreak
{
    DOPreferenceManager *prefManager = [DOPreferenceManager sharedManager];
    [prefManager setPreferenceValue:@NO forKey:@"removeJailbreakEnabled"];
    [prefManager removePreferenceValueForKey:@"fakeJailbroken"];
    [prefManager removePreferenceValueForKey:@"fakeBootstrapped"];
    [prefManager removePreferenceValueForKey:@"fakeJailbrokenVersion"];
    [[DOEnvironmentManager sharedManager] setJailbreakHidden:NO];
    [[DOUIManager sharedInstance] resetPackageManagers];
}

- (void)finalize
{
    // Called right after fadeToBlack: the real app userspace-reboots here,
    // the simulation hands over to the boot/panic screens. A successful run
    // also lifts "Hide Jailbreak", like a real rejailbreak does.
    [[DOEnvironmentManager sharedManager] setJailbreakHidden:NO];
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
