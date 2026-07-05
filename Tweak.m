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

static void dumpTabSubviews(UIView *v, int depth) {
    if (depth > 6) return;
    NSString *pre = [@"" stringByPaddingToLength:depth*2 withString:@" " startingAtIndex:0];
    wlog(@"%@↳ %@ frame=%@ tag=%ld", pre, NSStringFromClass([v class]), NSStringFromCGRect(v.frame), (long)v.tag);
    for (UIView *sub in v.subviews) {
        dumpTabSubviews(sub, depth+1);
    }
}

static void (*orig_root_appear)(id, SEL, BOOL);
static void hook_root_appear(id self, SEL _cmd, BOOL animated) {
    orig_root_appear(self, _cmd, animated);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIView *view = [(UIViewController *)self view];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            wlog(@"=== VIEW TREE ===");
            dumpTabSubviews(view, 0);
            wlog(@"=== END TREE ===");
        });
    });
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
    if (root) {
        BOOL ok = swizzle(root, @selector(viewDidAppear:), (IMP)hook_root_appear, &orig_root_appear);
        wlog(@"root swizzle appear: %d", ok);
    }
}
