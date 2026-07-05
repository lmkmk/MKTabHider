#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_setControllers)(id, SEL, NSArray *, id);

static BOOL MKIsBlockedController(id controller) {
    NSString *className = NSStringFromClass([controller class]);
    return [className isEqualToString:@"ContactListUI.ContactsController"] ||
        [className isEqualToString:@"CallListUI.CallListController"];
}

static NSArray *MKFilteredControllers(NSArray *controllers, NSInteger *removedBeforeSelectedIndex, NSInteger selectedIndex) {
    NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:controllers.count];
    NSInteger removedBefore = 0;

    for (NSUInteger index = 0; index < controllers.count; index++) {
        id controller = [controllers objectAtIndex:index];
        if (MKIsBlockedController(controller)) {
            if ((NSInteger)index < selectedIndex) removedBefore++;
            continue;
        }
        [filtered addObject:controller];
    }

    if (removedBeforeSelectedIndex) *removedBeforeSelectedIndex = removedBefore;
    return filtered;
}

static id MKRemappedSelectedIndex(id selectedIndex, NSInteger removedBeforeSelectedIndex, NSUInteger filteredCount) {
    if (!selectedIndex || selectedIndex == [NSNull null]) return selectedIndex;
    if (![selectedIndex respondsToSelector:@selector(integerValue)]) return selectedIndex;
    if (filteredCount == 0) return selectedIndex;

    NSInteger value = [selectedIndex integerValue] - removedBeforeSelectedIndex;
    if (value < 0) value = 0;
    if (value >= (NSInteger)filteredCount) value = (NSInteger)filteredCount - 1;
    return @(value);
}

static void hook_setControllers(id self, SEL _cmd, NSArray *controllers, id selectedIndex) {
    if (![controllers isKindOfClass:[NSArray class]]) {
        orig_setControllers(self, _cmd, controllers, selectedIndex);
        return;
    }

    NSInteger originalSelectedIndex = 0;
    if (selectedIndex && selectedIndex != [NSNull null] && [selectedIndex respondsToSelector:@selector(integerValue)]) {
        originalSelectedIndex = [selectedIndex integerValue];
    }

    NSInteger removedBeforeSelectedIndex = 0;
    NSArray *filteredControllers = MKFilteredControllers(controllers, &removedBeforeSelectedIndex, originalSelectedIndex);
    id remappedSelectedIndex = MKRemappedSelectedIndex(selectedIndex, removedBeforeSelectedIndex, filteredControllers.count);

    orig_setControllers(self, _cmd, filteredControllers, remappedSelectedIndex);
}

static Method MKFindSetControllersMethod(Class cls, SEL *selector) {
    SEL preferred = NSSelectorFromString(@"setControllers:selectedIndex:");
    Method method = class_getInstanceMethod(cls, preferred);
    if (method) {
        if (selector) *selector = preferred;
        return method;
    }

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method found = NULL;
    SEL foundSelector = NULL;

    for (unsigned int index = 0; index < count; index++) {
        SEL candidate = method_getName(methods[index]);
        NSString *name = NSStringFromSelector(candidate);
        if ([name containsString:@"setControllers"] && [name containsString:@"selectedIndex"]) {
            found = methods[index];
            foundSelector = candidate;
            break;
        }
    }

    if (selector) *selector = foundSelector;
    if (methods) free(methods);
    return found;
}

__attribute__((constructor))
static void MKTabHider_init(void) {
    Class cls = NSClassFromString(@"TabBarUI.TabBarControllerImpl");
    if (!cls) return;

    SEL selector = NULL;
    Method method = MKFindSetControllersMethod(cls, &selector);
    if (!method || !selector) return;

    orig_setControllers = (void *)method_getImplementation(method);
    method_setImplementation(method, (IMP)hook_setControllers);
}
