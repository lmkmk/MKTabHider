#import <UIKit/UIKit.h>

static NSMutableSet *logged;

static void log(NSString *msg) {
    NSLog(@"[MKTabHider] %@", msg);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count) {
        NSString *path = [paths[0] stringByAppendingPathComponent:@"MKTabHider.log"];
        NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], msg];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [line writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
        } else {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    }
}

%ctor {
    logged = [NSMutableSet set];
    log(@"dylib loaded");
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
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
    log([NSString stringWithFormat:@"VC: %@ | subs: %@", cls, [names componentsJoinedByString:@", "]]);
}
%end
