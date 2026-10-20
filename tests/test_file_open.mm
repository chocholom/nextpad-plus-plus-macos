// Run the production main and AppDelegate through Launch Services while recording
// buffer hashes from inside a separate test application. No user settings or text
// contents are written to the report.
#import <CommonCrypto/CommonDigest.h>
#import "EditorView.h"
#import "TabManager.h"
#import "MainWindowController.h"
#import "ScintillaView.h"

#define main NppProductionMain
#include "../src/main.mm"
#undef main

static NSMutableArray<NSString *> *exceptions;

@interface FileOpenTestApplication : NppApplication
@end
@implementation FileOpenTestApplication
- (void)reportException:(NSException *)exception {
    [exceptions addObject:[NSString stringWithFormat:@"%@: %@", exception.name, exception.reason]];
    NSLog(@"File-open regression exception: %@", exception);
}
@end

static NSString *digest(NSData *data) {
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    NSMutableString *result = [NSMutableString new];
    for (unsigned char byte : bytes) [result appendFormat:@"%02x", byte];
    return result;
}

int main(int argc, const char *argv[]) { @autoreleasepool {
    exceptions = [NSMutableArray new];
    [FileOpenTestApplication sharedApplication];
    NSString *domain = NSBundle.mainBundle.bundleIdentifier;
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domain];
    NSURL *report = [[NSBundle.mainBundle.bundleURL URLByDeletingLastPathComponent]
                    URLByAppendingPathComponent:@"file-open-state.json"];
    [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        AppDelegate *delegate = (AppDelegate *)NSApp.delegate;
        NSMutableArray *editors = [NSMutableArray new];
        NSMutableArray *windows = [NSMutableArray new];
        for (MainWindowController *controller in delegate.windowControllers) {
            [windows addObject:@{@"title":controller.window.title ?: @"", @"visible":@(controller.window.visible)}];
            for (TabManager *manager in controller.sessionTabManagers) {
                for (EditorView *editor in manager.allEditors) {
                    NSData *data = [editor.scintillaView.string dataUsingEncoding:NSUTF8StringEncoding];
                    [editors addObject:@{@"path":editor.filePath ?: @"", @"bytes":@(data.length),
                                         @"sha256":digest(data ?: [NSData data])}];
                }
            }
        }
        NSDictionary *state = @{@"pid":@(getpid()), @"finishedLaunching":[delegate valueForKey:@"didFinishLaunching"] ?: @NO,
                                 @"exceptions":exceptions, @"editors":editors, @"windows":windows};
        NSData *data = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToURL:report options:NSDataWritingAtomic error:nil];
    }];
    return NppProductionMain(argc, argv);
} }
