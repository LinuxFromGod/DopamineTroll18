//
//  DOJailbreakButton.h
//  Dopamine
//
//  Created by tomt000 on 13/01/2024.
//

#import <UIKit/UIKit.h>
#import "DOActionMenuButton.h"
#import "DOLyricsLogView.h"
#import "DODebugLogView.h"
#import "DOPkgManagerPickerView.h"
#import <pthread.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOJailbreakButton : UIView

@property (nonatomic, strong) DOActionMenuButton *button;
@property (nonatomic, strong) UIView<DOLogViewProtocol> *logView;
@property (nonatomic, strong) DOPkgManagerPickerView *pkgManagerPickerView;

@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) BOOL didExpand;
@property (nonatomic, assign) pthread_mutex_t canStartJailbreak;

- (instancetype)initWithAction:(UIAction *)actions;
- (void)expandButton:(NSArray<NSLayoutConstraint *> *)constraints;

- (void)lockMutex;
- (void)unlockMutex;

@end

NS_ASSUME_NONNULL_END
