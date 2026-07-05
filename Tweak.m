#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UIView *findTabBarView(UIView *root) {
    for (UIView *v in root.subviews) {
        NSString *c = NSStringFromClass([v class]);
        if ([c containsString:@"TabBarComponent"] && [c containsString:@"4View"]) return v;
        UIView *found = findTabBarView(v);
        if (found) return found;
    }
    return nil;
}

static void hideTabs(UIView *tabBar) {
    UIView *bg = tabBar.subviews.firstObject;
    if (!bg) return;
    NSMutableArray *items = [NSMutableArray array];
    for (UIView *v in bg.subviews) {
        if (v.frame.size.width > 20 && v.frame.size.height > 20 && !v.hidden) {
            [items addObject:v];
        }
    }
    if (items.count < 4) return;
    
    UIView *first = items[0], *last = items[3];
    items[1].hidden = YES;
    items[1].alpha = 0;
    items[2].hidden = YES;
    items[2].alpha = 0;
    
    CGFloat w = bg.frame.size.width;
    CGPoint c1 = first.center; c1.x = w * 0.25; first.center = c1;
    CGPoint c2 = last.center; c2.x = w * 0.75; last.center = c2;
}

static void (*orig_root_appear)(id, SEL, BOOL);
static void hook_root_appear(id self, SEL _cmd, BOOL animated) {
    orig_root_appear(self, _cmd, animated);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIView *v = [(UIViewController *)self view];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *tb = findTabBarView(v);
            if (tb) hideTabs(tb);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIView *tb = findTabBarView(v);
            if (tb) hideTabs(tb);
        });
    });
}

__attribute__((constructor))
static void MKTabHider_init(void) {
    Class root = NSClassFromString(@"TelegramUI.TelegramRootController");
    if (root) {
        Method m = class_getInstanceMethod(root, @selector(viewDidAppear:));
        if (m) {
            orig_root_appear = (void *)method_getImplementation(m);
            method_setImplementation(m, (IMP)hook_root_appear);
        }
    }
}
