//
//  DOEnvironmentManager.m
//  Dopamine
//
//  Created by Lars Fröder on 10.01.24.
//
//  Simulation stub. The "jailbroken" state lives in a preference key and is
//  only used to decide what the UI should show; nothing is actually modified
//  on the device.
//

#import "DOEnvironmentManager.h"
#import "DOPreferenceManager.h"
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <UIKit/UIKit.h>

#define CPUFAMILY_ARM_VORTEX_TEMPEST   0x07d34d9f
#define CPUFAMILY_ARM_LIGHTNING_THUNDER 0x462504d2

@implementation DOEnvironmentManager

+ (instancetype)sharedManager
{
    static DOEnvironmentManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[DOEnvironmentManager alloc] init];
    });
    return sharedManager;
}

- (NSString *)appVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)appVersionDisplayString
{
    return [self appVersion];
}

- (BOOL)isInstalledThroughTrollStore
{
    return NO;
}

- (BOOL)isJailbroken
{
    return [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"fakeJailbroken" fallback:NO];
}

- (BOOL)isJailbrokenWithOtherJailbreak
{
    return NO;
}

- (BOOL)isBootstrapped
{
    return [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"fakeBootstrapped" fallback:NO];
}

- (NSString *)jailbrokenVersion
{
    if (!self.isJailbroken) return nil;
    return [[DOPreferenceManager sharedManager] preferenceValueForKey:@"fakeJailbrokenVersion"];
}

- (NSString *)systemVersion
{
    return [[UIDevice currentDevice] systemVersion];
}

- (void)setJailbroken:(BOOL)jailbroken withVersion:(NSString *)version
{
    DOPreferenceManager *prefManager = [DOPreferenceManager sharedManager];
    if (jailbroken) {
        [prefManager setPreferenceValue:@YES forKey:@"fakeJailbroken"];
        [prefManager setPreferenceValue:@YES forKey:@"fakeBootstrapped"];
        [prefManager setPreferenceValue:version ?: [self appVersion] forKey:@"fakeJailbrokenVersion"];
    }
    else {
        // A (simulated) reboot clears the jailbroken state, just like on a real device
        [prefManager removePreferenceValueForKey:@"fakeJailbroken"];
        [prefManager removePreferenceValueForKey:@"fakeJailbrokenVersion"];
    }
}

- (BOOL)isSupported
{
    // Always claim support so the whole flow is always available
    return YES;
}

- (BOOL)isArm64e
{
    int32_t cpuType = 0;
    size_t size = sizeof(cpuType);
    sysctlbyname("hw.cputype", &cpuType, &size, NULL, 0);
    int64_t abi = 0;
    size = sizeof(abi);
    sysctlbyname("hw.cpuABI", &abi, &size, NULL, 0);
    return (cpuType & 0x1000000) != 0 || abi == 2;
}

- (BOOL)isSPTM
{
    // iOS 17+ devices use SPTM instead of PPL
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return version.majorVersion >= 17;
}

- (NSString *)versionSupportString
{
    cpu_subtype_t cpuFamily = 0;
    size_t cpuFamilySize = sizeof(cpuFamily);
    sysctlbyname("hw.cpufamily", &cpuFamily, &cpuFamilySize, NULL, 0);

    if ([self isArm64e]) {
        if (cpuFamily == CPUFAMILY_ARM_VORTEX_TEMPEST || cpuFamily == CPUFAMILY_ARM_LIGHTNING_THUNDER) {
            return @"iOS 15.0 - 18.7.1, 26.0 - 26.0.1 (A12/A13, PPL)";
        }
        else if (![self isSPTM]) {
            return @"iOS 15.0 - 17.3.1 (PPL)";
        }
        else {
            return @"iOS 17.0 - 17.3.1 (SPTM)";
        }
    }
    else {
        return @"iOS 15.0 - 16.6.1 (bypasses)";
    }
}

#pragma mark - Fake power actions

// These are visual simulations driven by the UI layer; the methods only
// exist so call sites keep the shape of the original code.

- (void)respring {}
- (void)rebootUserspace {}
- (void)reboot {}

- (BOOL)isJailbreakHidden
{
    return [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"fakeJailbreakHidden" fallback:NO];
}

- (void)setJailbreakHidden:(BOOL)hidden
{
    [[DOPreferenceManager sharedManager] setPreferenceValue:@(hidden) forKey:@"fakeJailbreakHidden"];
}

- (NSError *)reinstallPackageManagers
{
    return nil;
}

@end
