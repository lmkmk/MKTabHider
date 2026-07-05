#import <UIKit/UIKit.h>

static void hideTabsInView(UIView *view) {
    NSArray *banned = @[@"Contacts", @"Calls", @"联系人", @"通话"];
    for (UIView *sub in view.subviews) {
        if ([sub respondsToSelector:@selector(text)]) {
            NSString *t = [sub performSelector:@selector(text)];
            if ([banned containsObject:t]) {
                UIView *p = sub.superview;
                if (p) p.hidden = YES;
            }
        }
        hideTabsInView(sub);
    }
}

%hook TelegramUI.TelegramRootController

- (void)addChildViewController:(UIViewController *)child {
    NSString *cls = NSStringFromClass([child class]);
    if (![cls containsString:@"Contacts"] && ![cls containsString:@"CallList"]) {
        %orig;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            hideTabsInView(self.view);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            hideTabsInView(self.view);
        });
    });
}

%end

%hook ContactListUI.ContactsController
- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController popViewControllerAnimated:NO];
}
%end

%hook CallListUI.CallListController
- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController popViewControllerAnimated:NO];
}
%end
