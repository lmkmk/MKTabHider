#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *logPath(void) {
    static NSString *path;
    if (!path) {
        NSArray *p = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        path = [[p[0] stringByAppendingPathComponent:@"MKTabHider.log"] copy];
    }
    return path;
}

static void logToFile(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    
    NSLog(@"[MKTabHider] %@", msg);
    
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

%ctor {
    logToFile(@"=== MKTabHider loaded ===");
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static NSMutableSet *seen;
    if (!seen) seen = [NSMutableSet set];
    NSString *cls = NSStringFromClass([self class]);
    if ([seen containsObject:cls]) return;
    [seen addObject:cls];
    
    NSMutableArray *names = [NSMutableArray array];
    int n = 0;
    for (UIView *v in self.view.subviews) {
        [names addObject:NSStringFromClass([v class])];
        if (++n >= 5) break;
    }
    logToFile(@"VC: %@ subviews[0-%d]: %@", cls, n, [names componentsJoinedByString:@", "]);
}
%end
