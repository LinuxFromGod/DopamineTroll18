//
//  DOPanicScreenViewController.h
//  Dopamine
//
//  Simulation of a kernel panic: black screen, Apple logo, then a verbose
//  panic dump typed out line by line before the device "reboots".
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOPanicScreenViewController : UIViewController

// Presents a fullscreen overlay that plays the panic and then calls
// completion on the main queue.
+ (void)presentPanicWithCompletion:(void(^)(void))completion;

@end

NS_ASSUME_NONNULL_END
