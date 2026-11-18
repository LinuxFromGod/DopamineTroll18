//
//  DOBootScreenViewController.h
//  Dopamine
//
//  Simulation of the userspace reboot boot screen: black background, boot
//  logo and a thin progress bar, exactly like a real Dopamine reboot.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOBootScreenViewController : UIViewController

// Presents a fullscreen overlay window with a boot logo and progress bar
// lasting `duration` seconds, then calls completion on the main queue.
+ (void)presentBootWithDuration:(NSTimeInterval)duration completion:(void(^)(void))completion;

// Presents a fullscreen overlay window that looks like an iOS respring:
// black background with a white system spinner in the middle, lasting
// `duration` seconds, then calls completion on the main queue.
+ (void)presentRespringWithDuration:(NSTimeInterval)duration completion:(void(^)(void))completion;

@end

NS_ASSUME_NONNULL_END
