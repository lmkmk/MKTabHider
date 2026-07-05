#import <UIKit/UIKit.h>

%ctor {
    NSLog(@"[MKTabHider] dylib loaded");
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static NSMutableSet *logged;
    if (!logged) logged = [NSMutableSet set];
    NSString *cls = NSStringFromClass([self class]);
    if ([logged containsObject:cls]) return;
    [logged addObject:cls];
    
    NSArray *subs = [self.view subviews];
    NSMutableArray *names = [NSMutableArray array];
    int count = 0;
    for (UIView *v in subs) {
        [names addObject:NSStringFromClass([v class])];
        if (++count >= 10) break;
    }
    NSLog(@"[MKTabHider] VC: %@ | subs: %@", cls, [names componentsJoinedByString:@", "]);
}
%end
