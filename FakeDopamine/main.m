//
//  main.m
//  FakeDopamine
//
//  Standalone simulation build. Unlike the real Dopamine main.m, this one has
//  no libjailbreak dependencies and no command line modes: it only launches
//  the app UI.
//

#import <UIKit/UIKit.h>
#import "DOAppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DOAppDelegate class]));
    }
}
