#import <UIKit/UIKit.h>

static BOOL shouldHideItem(UITabBarItem *item) {
    if (!item.title) return NO;
    NSArray *targets = @[@"Contacts", @"Calls", @"联系人", @"通话"];
    for (NSString *t in targets) {
        if ([item.title isEqualToString:t]) return YES;
    }
    return NO;
}

%hook UITabBar
- (void)setItems:(NSArray *)items animated:(BOOL)animated {
    NSMutableArray *filtered = [NSMutableArray array];
    for (UITabBarItem *item in items) {
        if (!shouldHideItem(item)) {
            [filtered addObject:item];
        }
    }
    if (filtered.count) {
        %orig(filtered, animated);
    }
}
%end

%hook UITabBarController
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated {
    NSMutableArray *filtered = [NSMutableArray array];
    for (UIViewController *vc in viewControllers) {
        NSString *classStr = NSStringFromClass([vc class]);
        BOOL hide = [classStr containsString:@"Contact"] || [classStr containsString:@"Call"];
        if (!hide) {
            [filtered addObject:vc];
        }
    }
    if (filtered.count) {
        %orig(filtered, animated);
    }
}
%end
