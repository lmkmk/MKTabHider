#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_root_addChild)(id, SEL, UIViewController *);
static void hook_root_addChild(id self, SEL _cmd, UIViewController *child) {
    NSString *c = NSStringFromClass([child class]);
    if ([c containsString:@"ContactsController"]) {
        UIViewController *chats = nil;
        for (UIViewController *vc in [(UIViewController *)self childViewControllers]) {
            if ([NSStringFromClass([vc class]) containsString:@"ChatList"]) {
                chats = vc; break;
            }
        }
        if (!chats) {
            chats = [(UIViewController *)self childViewControllers].firstObject;
        }
        if (chats) {
            orig_root_addChild(self, _cmd, chats);
            [chats didMoveToParentViewController:(UIViewController *)self];
        }
        return;
    }
    if ([c containsString:@"CallListController"]) {
        UIViewController *settings = nil;
        for (UIViewController *vc in [(UIViewController *)self childViewControllers]) {
            if ([NSStringFromClass([vc class]) containsString:@"PeerInfo"]) {
                settings = vc; break;
            }
        }
        if (!settings) {
            UIViewController *chats = nil;
            for (UIViewController *vc in [(UIViewController *)self childViewControllers]) {
                if ([NSStringFromClass([vc class]) containsString:@"ChatList"]) {
                    chats = vc; break;
                }
            }
            settings = chats;
        }
        if (settings) {
            orig_root_addChild(self, _cmd, settings);
            [settings didMoveToParentViewController:(UIViewController *)self];
        }
        return;
    }
    orig_root_addChild(self, _cmd, child);
}

static BOOL swizzle(Class cls, SEL sel, IMP hook, IMP *orig) {
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        *orig = method_getImplementation(m);
        method_setImplementation(m, hook);
        return YES;
    }
    return NO;
}

__attribute__((constructor))
static void MKTabHider_init(void) {
    Class root = NSClassFromString(@"TelegramUI.TelegramRootController");
    if (root) {
        swizzle(root, @selector(addChildViewController:), (IMP)hook_root_addChild, &orig_root_addChild);
    }
}
