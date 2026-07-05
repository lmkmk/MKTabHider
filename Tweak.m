#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *logPath(void) {
    static NSString *p;
    if (!p) {
        NSArray *arr = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        p = [[arr[0] stringByAppendingPathComponent:@"MKTabHider.log"] copy];
    }
    return p;
}

static void wlog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[MKTH] %@", msg);
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath()];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    } else {
        [line writeToFile:logPath() atomically:NO encoding:NSUTF8StringEncoding error:nil];
    }
}

static void dumpViews(UIView *v, int depth) {
    if (depth > 4) return;
    NSString *prefix = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
    NSString *cls = NSStringFromClass([v class]);
    wlog(@"%@↳ %@ frame=%@", prefix, cls, NSStringFromCGRect(v.frame));
    for (UIView *sub in v.subviews) {
        dumpViews(sub, depth + 1);
    }
}

static int hook_called_root_appear = 0;
static int hook_called_root_child = 0;

static void (*orig_root_appear)(id, SEL, BOOL);
static void hook_root_appear(id self, SEL _cmd, BOOL animated) {
    orig_root_appear(self, _cmd, animated);
    hook_called_root_appear++;
    if (hook_called_root_appear == 1) {
        wlog(@"root_appear called #1");
        NSArray *kids = [(UIViewController *)self childViewControllers];
        wlog(@"root childVCs count=%lu", (unsigned long)kids.count);
        for (UIViewController *vc in kids) {
            wlog(@"  child: %@", NSStringFromClass([vc class]));
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            wlog(@"view tree (depth 4):");
            dumpViews([(UIViewController *)self view], 0);
        });
    }
}

static void (*orig_root_addChild)(id, SEL, UIViewController *);
static void hook_root_addChild(id self, SEL _cmd, UIViewController *child) {
    NSString *c = NSStringFromClass([child class]);
    hook_called_root_child++;
    wlog(@"root_addChild: %@ (total: %d)", c, hook_called_root_child);
    orig_root_addChild(self, _cmd, child);
}

static void (*orig_contacts_appear)(id, SEL, BOOL);
static void hook_contacts_appear(id self, SEL _cmd, BOOL animated) {
    wlog(@"contacts_appear TRIGGERED");
    id nav = [self performSelector:@selector(navigationController)];
    wlog(@"  nav=%@ parent=%@", nav, [self performSelector:@selector(parentViewController)]);
}

static void (*orig_calls_appear)(id, SEL, BOOL);
static void hook_calls_appear(id self, SEL _cmd, BOOL animated) {
    wlog(@"calls_appear TRIGGERED");
    id nav = [self performSelector:@selector(navigationController)];
    wlog(@"  nav=%@ parent=%@", nav, [self performSelector:@selector(parentViewController)]);
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
    wlog(@"=== INIT ===");
    
    Class root = NSClassFromString(@"TelegramUI.TelegramRootController");
    wlog(@"root class = %@", root);
    if (root) {
        BOOL a = swizzle(root, @selector(viewDidAppear:), (IMP)hook_root_appear, &orig_root_appear);
        BOOL b = swizzle(root, @selector(addChildViewController:), (IMP)hook_root_addChild, &orig_root_addChild);
        wlog(@"root swizzle: appear=%d addChild=%d", a, b);
    }
    
    Class contacts = NSClassFromString(@"ContactListUI.ContactsController");
    wlog(@"contacts class = %@", contacts);
    if (contacts) {
        BOOL ok = swizzle(contacts, @selector(viewWillAppear:), (IMP)hook_contacts_appear, &orig_contacts_appear);
        wlog(@"contacts swizzle: %d", ok);
    }
    
    Class calls = NSClassFromString(@"CallListUI.CallListController");
    wlog(@"calls class = %@", calls);
    if (calls) {
        BOOL ok = swizzle(calls, @selector(viewWillAppear:), (IMP)hook_calls_appear, &orig_calls_appear);
        wlog(@"calls swizzle: %d", ok);
    }
    
    wlog(@"=== INIT DONE ===");
}
