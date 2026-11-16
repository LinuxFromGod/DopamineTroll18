//
//  DOUIStyle.h
//  Dopamine
//
//  Shared styling helpers, replacing the Preferences.framework based styling
//  of the original app.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOUIStyle : NSObject

// Dark, translucent card look used by all pushed view controllers
+ (void)setupViewControllerStyle:(UIViewController *)vc;

// Header bar with title + back button used on pushed screens
+ (UIView *)makeHeader:(NSString *)title withTarget:(id)target;

// Rounded selection row used by the list screens
+ (UIButton *)optionRowWithTitle:(NSString *)title checked:(BOOL)checked;

@end

NS_ASSUME_NONNULL_END
