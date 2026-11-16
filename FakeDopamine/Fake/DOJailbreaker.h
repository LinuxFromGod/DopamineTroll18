//
//  DOJailbreaker.h
//  Dopamine
//
//  Created by Lars Fröder on 10.01.24.
//
//  Simulation engine: walks the exact log choreography of a real Dopamine
//  run, but every step only sleeps for a randomized amount of time.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOJailbreaker : NSObject

// Same shape as the real jailbreaker so the view controller flow stays intact
- (void)runWithError:(NSError **)errOut didRemoveJailbreak:(BOOL*)didRemove showLogs:(BOOL *)showLogs;
- (void)finalize;

// Picks the ending of the show (boot screen or panic screen)
- (BOOL)shouldKernelPanic;

@end

NS_ASSUME_NONNULL_END
