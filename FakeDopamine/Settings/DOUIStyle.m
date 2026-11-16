//
//  DOUIStyle.m
//  Dopamine
//

#import "DOUIStyle.h"
#import "DOThemeManager.h"
#import "DOGlobalAppearance.h"

@implementation DOUIStyle

+ (void)setupViewControllerStyle:(UIViewController *)vc
{
    DOTheme *theme = [[DOThemeManager sharedInstance] enabledTheme];

    vc.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    vc.view.backgroundColor = theme.windowColor;
    vc.view.layer.cornerRadius = 16;
    vc.view.layer.masksToBounds = YES;
    vc.view.layer.cornerCurve = kCACornerCurveContinuous;

    [UISwitch appearanceWhenContainedInInstancesOfClasses:@[[vc class]]].onTintColor = [UIColor colorWithRed: 71.0/255.0 green: 169.0/255.0 blue: 135.0/255.0 alpha: 1.0];
}

+ (UIView *)makeHeader:(NSString *)title withTarget:(id)target
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 70)];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 60)];
    label.text = title;
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:label];

    UIView *border = [[UIView alloc] init];
    border.translatesAutoresizingMaskIntoConstraints = NO;
    border.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    [header addSubview:border];

    UIImage *backImage = [UIImage systemImageNamed:@"chevron.left" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]];
    backImage = [backImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:backImage forState:UIControlStateNormal];
    [backButton setTintColor:[UIColor colorWithWhite:1.0 alpha:0.6]];
    [backButton addTarget:target action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:backButton];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerYAnchor constraintEqualToAnchor:header.centerYAnchor constant:-8],
        [label.centerXAnchor constraintEqualToAnchor:header.centerXAnchor]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [border.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [border.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [border.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12],
        [border.heightAnchor constraintEqualToConstant:1]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [backButton.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:10],
        [backButton.centerYAnchor constraintEqualToAnchor:header.centerYAnchor constant:-7],
        [backButton.widthAnchor constraintEqualToConstant:30],
        [backButton.heightAnchor constraintEqualToConstant:30]
    ]];

    return header;
}

+ (UIButton *)optionRowWithTitle:(NSString *)title checked:(BOOL)checked
{
    UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
    row.layer.cornerRadius = 10;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    row.layer.masksToBounds = YES;
    row.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    row.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    row.tintColor = [UIColor whiteColor];
    row.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];

    NSString *iconName = checked ? @"checkmark.circle.fill" : @"circle";
    UIImage *image = [UIImage systemImageNamed:iconName withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]];
    [row setImage:image forState:UIControlStateNormal];
    [row setTitle:title forState:UIControlStateNormal];
    row.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 0);
    row.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);

    return row;
}

@end
