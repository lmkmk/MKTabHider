#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_tabbar_layout)(id, SEL);
static BOOL mk_is_applying = NO;

static NSInteger MKCompareViewsByMinX(id a, id b, void *context) {
    CGFloat ax = ((UIView *)a).frame.origin.x;
    CGFloat bx = ((UIView *)b).frame.origin.x;
    if (ax < bx) return NSOrderedAscending;
    if (ax > bx) return NSOrderedDescending;
    return NSOrderedSame;
}

static UIView *MKFindLiquidLensView(UIView *root) {
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:root];
    while (stack.count != 0) {
        UIView *view = [stack lastObject];
        [stack removeLastObject];

        if ([NSStringFromClass(view.class) isEqualToString:@"LiquidLens.LiquidLensView"]) {
            return view;
        }

        for (UIView *subview in view.subviews) {
            [stack addObject:subview];
        }
    }
    return nil;
}

static UIView *MKUIViewValueForKey(id object, NSString *key) {
    @try {
        id value = [object valueForKey:key];
        if ([value isKindOfClass:[UIView class]]) return value;
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

static NSMutableArray<UIView *> *MKTabItemViews(UIView *container) {
    NSMutableArray<UIView *> *items = [NSMutableArray array];

    for (UIView *view in container.subviews) {
        NSString *className = NSStringFromClass(view.class);
        if (![className containsString:@"ItemComponent"] || ![className containsString:@"View"]) continue;
        if (view.bounds.size.width <= 0.0 || view.bounds.size.height <= 0.0) continue;
        [items addObject:view];
    }

    [items sortUsingFunction:MKCompareViewsByMinX context:NULL];
    return items;
}

static void MKHideFirstTwoItemsInContainer(UIView *container) {
    NSMutableArray<UIView *> *items = MKTabItemViews(container);
    if (items.count < 4) return;

    for (NSUInteger index = 0; index < items.count; index++) {
        UIView *item = [items objectAtIndex:index];
        BOOL shouldHide = index < 2;
        item.hidden = shouldHide;
        item.alpha = shouldHide ? 0.0 : 1.0;
        item.userInteractionEnabled = !shouldHide;
    }
}

static void MKApplyTabHider(UIView *tabBarView) {
    if (mk_is_applying) return;
    mk_is_applying = YES;

    UIView *liquidLensView = MKFindLiquidLensView(tabBarView);
    if (liquidLensView) {
        UIView *contentView = MKUIViewValueForKey(liquidLensView, @"contentView");
        UIView *selectedContentView = MKUIViewValueForKey(liquidLensView, @"selectedContentView");

        if (contentView) MKHideFirstTwoItemsInContainer(contentView);
        if (selectedContentView) MKHideFirstTwoItemsInContainer(selectedContentView);
    }

    mk_is_applying = NO;
}

static void hook_tabbar_layout(id self, SEL _cmd) {
    if (orig_tabbar_layout) orig_tabbar_layout(self, _cmd);
    MKApplyTabHider((UIView *)self);
}

__attribute__((constructor))
static void MKTabHider_init(void) {
    Class cls = NSClassFromString(@"_TtCC15TabBarComponent15TabBarComponent4View");
    if (!cls) return;

    Method method = class_getInstanceMethod(cls, @selector(layoutSubviews));
    if (!method) return;

    orig_tabbar_layout = (void *)method_getImplementation(method);
    method_setImplementation(method, (IMP)hook_tabbar_layout);
}
