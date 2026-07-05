#import <UIKit/UIKit.h>

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
    log(@"dylib loaded");
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *cls = NSStringFromClass([self class]);
    NSArray *subs = [self.view subviews];
    NSMutableArray *subNames = [NSMutableArray array];
    for (UIView *v in subs) {
        [subNames addObject:NSStringFromClass([v class])];
    }
    log([NSString stringWithFormat:@"VC: %@ subviews: %@", cls, [subNames componentsJoinedByString:@", "]]);
}
%end
