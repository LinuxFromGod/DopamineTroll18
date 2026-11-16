//
//  DOLyricsLogItemView.h
//  Dopamine
//
//  Created by tomt000 on 18/01/2024.
//

#import <UIKit/UIKit.h>
#import "DOLoadingIndicator.h"

NS_ASSUME_NONNULL_BEGIN

@interface DOLyricsLogItemView : UIView

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) DOLoadingIndicator *loadingIndicator;
@property (nonatomic) BOOL completed;
@property (nonatomic, strong) UIImpactFeedbackGenerator *feedbackGenerator;

@property (nonatomic, strong) UIImage *completedImage;
@property (nonatomic, strong) UIImage *failedImage;
@property (nonatomic, strong) UIImage *successImage;

- (id)initWithString:(NSString *)string completedImage:(UIImage *)completedImage failedImage:(UIImage *)failedImage successImage:(UIImage *)successImage;
- (void)setCompleted;
- (void)setFailed;
- (void)setSuccess;

@end

NS_ASSUME_NONNULL_END
