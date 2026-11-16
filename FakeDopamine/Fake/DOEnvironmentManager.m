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
#import <signal.h>
#import <string.h>
#import <stdlib.h>

// libproc.h is not exposed by the iOS SDK, but the functions live in
// libSystem, so the two used for respring are declared by hand.
extern int proc_listallpids(void *buffer, int buffersize);
extern int proc_pidpath(pid_t pid, void *pathbuffer, uint32_t pathbufferlen);
#define PROC_PIDPATHINFO_MAXSIZE (4 * 1024)
#define CPUFAMILY_ARM_VORTEX_TEMPEST    0x07d34d9f
#define CPUFAMILY_ARM_LIGHTNING_THUNDER 0x462504d2
#define CPUFAMILY_ARM_FIRESTORM_ICESTORM 0x1b588bb3
#define CPUFAMILY_ARM_AVALANCHE_BLIZZARD 0xda33d83d
#define CPUFAMILY_ARM_EVEREST_SAWTOOTH  0x8765edea

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
    // Preferred source: the kernel exports arm64e capability directly
    // (A12 and newer, including future chips).
    int32_t arm64e = 0;
    size_t size = sizeof(arm64e);
    if (sysctlbyname("hw.optional.arm64e", &arm64e, &size, NULL, 0) == 0 && size == sizeof(arm64e)) {
        return arm64e != 0;
    }

    // Fallback: cpu families that ship with arm64e. hw.cputype cannot be used
    // here — the CPU_ARCH_ABI64 bit is set on every 64-bit device, not just
    // arm64e ones.
    cpu_subtype_t cpuFamily = 0;
    size = sizeof(cpuFamily);
    sysctlbyname("hw.cpufamily", &cpuFamily, &size, NULL, 0);
    switch (cpuFamily) {
        case CPUFAMILY_ARM_VORTEX_TEMPEST:       // A12 / A12X / A12Z
        case CPUFAMILY_ARM_LIGHTNING_THUNDER:    // A13
        case CPUFAMILY_ARM_FIRESTORM_ICESTORM:   // A14 / M1
        case CPUFAMILY_ARM_AVALANCHE_BLIZZARD:   // A15 / M2
        case CPUFAMILY_ARM_EVEREST_SAWTOOTH:     // A16 / A17 Pro
            return YES;
        default:
            return NO;
    }
}

- (BOOL)isSPTM
{
    // iOS 17+ devices use SPTM instead of PPL
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return version.majorVersion >= 17;
}

- (NSString *)versionSupportString
{
        // PPL devices up to iOS 16.x, SPTM devices from iOS 17 through 27.x
        return [self isSPTM] ? @"iOS 15.0 - 27.3 (SPTM)" : @"iOS 15.0 - 27.3 (PPL)";
        // A9/A10-class devices top out before the SPTM era
    }
}

#pragma mark - Power actions

// reboot/rebootUserspace stay visual simulations driven by the UI layer;
// respring attempts the real thing when the environment allows it.

- (void)respring
{
    // The only action that can be done for real from an app: signal
    // SpringBoard and let launchd bring it back. Under TrollStore or a real
    // jailbreak this performs an actual respring; everywhere else it is a
    // no-op and the UI layer falls back to the in-app simulation.
    [self performRealRespring];
}

- (void)rebootUserspace {}
- (void)reboot {}

- (BOOL)performRealRespring
{
    pid_t springboardPid = 0;

    int pidCount = proc_listallpids(NULL, 0);
    if (pidCount <= 0)
        return NO;

    pid_t *pids = malloc(sizeof(pid_t) * pidCount);
    if (!pids)
        return NO;

    int listed = proc_listallpids(pids, pidCount * sizeof(pid_t));
    for (int i = 0; i < listed; i++) {
        char path[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(pids[i], path, sizeof(path)) <= 0)
            continue;
        if (strcmp(path, "/System/Library/CoreServices/SpringBoard.app/SpringBoard") == 0) {
            springboardPid = pids[i];
            break;
        }
    }
    free(pids);

    if (springboardPid <= 0)
        return NO;

    // Killing SpringBoard is safe: launchd relaunches it immediately, which
    // is exactly what the "respring" of a real jailbreak does.
    return kill(springboardPid, SIGKILL) == 0;
}

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