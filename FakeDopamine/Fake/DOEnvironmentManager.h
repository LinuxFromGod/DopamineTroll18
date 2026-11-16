//
//  DOEnvironmentManager.h
//  Dopamine
//
//  Created by Lars Fröder on 10.01.24.
//
//  Simulation stub: reports a plausible environment without ever
//  touching the real system.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOEnvironmentManager : NSObject

+ (instancetype)sharedManager;

- (NSString *)appVersion;
- (NSString *)appVersionDisplayString;

- (BOOL)isInstalledThroughTrollStore;
- (BOOL)isJailbroken;
- (BOOL)isJailbrokenWithOtherJailbreak;
- (BOOL)isBootstrapped;
- (NSString *)jailbrokenVersion;
- (NSString *)systemVersion;

- (BOOL)isSupported;
- (BOOL)isArm64e;
- (BOOL)isSPTM;
- (NSString *)versionSupportString;

- (void)setJailbroken:(BOOL)jailbroken withVersion:(NSString *)version;

- (void)respring;
- (void)rebootUserspace;
- (void)reboot;

// Attempts a real SpringBoard restart (works under TrollStore or a real
// jailbreak, where the sandbox permits signaling SpringBoard). Returns YES
// when the signal was delivered; NO means the environment blocked it and the
// caller's simulated path is the only thing the user will see.
- (BOOL)performRealRespring;

- (BOOL)isJailbreakHidden;
- (void)setJailbreakHidden:(BOOL)hidden;

- (NSError *)reinstallPackageManagers;

@end

NS_ASSUME_NONNULL_END
