//
//  DOPreferenceManager.m
//  Dopamine
//
//  Created by Lars Fröder on 13.01.24.
//

#import "DOPreferenceManager.h"

@implementation DOPreferenceManager

+ (instancetype)sharedManager
{
    static DOPreferenceManager *preferenceManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        preferenceManager = [[DOPreferenceManager alloc] init];
    });
    return preferenceManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Mirror the on-disk plist layout of the real preference manager,
        // but back it with NSUserDefaults so it works without a jailbreak
        _preferences = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"DOPreferences"].mutableCopy ?: [NSMutableDictionary new];
    }
    return self;
}

- (void)savePreferences
{
    [[NSUserDefaults standardUserDefaults] setObject:_preferences forKey:@"DOPreferences"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)preferenceValueForKey:(NSString *)key
{
    return [_preferences objectForKey:key];
}

- (BOOL)boolPreferenceValueForKey:(NSString *)key fallback:(BOOL)fallback
{
    NSNumber *num = [self preferenceValueForKey:key];
    if (num) {
        return num.boolValue;
    }
    return fallback;
}

- (void)setPreferenceValue:(NSObject *)obj forKey:(NSString *)key
{
    [_preferences setObject:obj forKey:key];
    [self savePreferences];
}

- (void)removePreferenceValueForKey:(NSString *)key
{
    [_preferences removeObjectForKey:key];
    [self savePreferences];
}

@end
