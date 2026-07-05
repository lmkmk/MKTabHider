#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

static void (*root_viewDidAppear)(id, SEL, BOOL);
static void hook_root_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    root_viewDidAppear(self, _cmd, animated);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIView *v = [(UIViewController *)self view];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            hideTabsInView(v);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            hideTabsInView(v);
        });
    });
}

static void (*root_addChild)(id, SEL, UIViewController *);
static void hook_root_addChild(id self, SEL _cmd, UIViewController *child) {
    NSString *c = NSStringFromClass([child class]);
    if ([c containsString:@"Contacts"] || [c containsString:@"CallList"]) return;
    root_addChild(self, _cmd, child);
}

static void (*contacts_appear)(id, SEL, BOOL);
static void hook_contacts_appear(id self, SEL _cmd, BOOL animated) {
    id nav = [self performSelector:@selector(navigationController)];
    if (nav) [nav performSelector:@selector(popViewControllerAnimated:) withObject:@(NO)];
}

static void (*calls_appear)(id, SEL, BOOL);
static void hook_calls_appear(id self, SEL _cmd, BOOL animated) {
    id nav = [self performSelector:@selector(navigationController)];
    if (nav) [nav performSelector:@selector(popViewControllerAnimated:) withObject:@(NO)];
}

static void swizzle(Class cls, SEL sel, IMP hook, IMP *orig) {
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        *orig = method_getImplementation(m);
        method_setImplementation(m, hook);
    }
}

__attribute__((constructor))
static void MKTabHider_init(void) {
    Class root = NSClassFromString(@"TelegramUI.TelegramRootController");
    if (root) {
        swizzle(root, @selector(viewDidAppear:), (IMP)hook_root_viewDidAppear, &root_viewDidAppear);
        swizzle(root, @selector(addChildViewController:), (IMP)hook_root_addChild, &root_addChild);
    }
    Class contacts = NSClassFromString(@"ContactListUI.ContactsController");
    if (contacts) swizzle(contacts, @selector(viewWillAppear:), (IMP)hook_contacts_appear, &contacts_appear);
    Class calls = NSClassFromString(@"CallListUI.CallListController");
    if (calls) swizzle(calls, @selector(viewWillAppear:), (IMP)hook_calls_appear, &calls_appear);
}
