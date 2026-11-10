#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// Presentation-only suppression of the specifically requested recurring notice.
// Does not change activation state, license validation, purchases or entitlements.
static BOOL IsNotActivatedNotice(id title, id message) {
    for (id value in @[title ?: @"", message ?: @""]) {
        if ([value isKindOfClass:NSString.class] &&
            [value rangeOfString:@"Not activated" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}
static IMP originalAlert;
static id FilterNotice(id cls, SEL cmd, id title, id message, id cancel, id buttons, id completion) {
    if (IsNotActivatedNotice(title, message)) return nil;
    return ((id(*)(id,SEL,id,id,id,id,id))originalAlert)(cls,cmd,title,message,cancel,buttons,completion);
}
static IMP originalPresent;
static void FilterPresentation(id owner, SEL cmd, UIViewController *controller, BOOL animated, void (^completion)(void)) {
    if ([controller isKindOfClass:UIAlertController.class]) {
        UIAlertController *alert = (id)controller;
        if (IsNotActivatedNotice(alert.title, alert.message)) {
            if (completion) completion();
            return;
        }
    }
    ((void(*)(id,SEL,id,BOOL,id))originalPresent)(owner,cmd,controller,animated,completion);
}
static void InstallNoticeFilter(void) {
    static BOOL presentationInstalled = NO;
    static BOOL alertInstalled = NO;
    if (!presentationInstalled) {
        Method m = class_getInstanceMethod(UIViewController.class, @selector(presentViewController:animated:completion:));
        originalPresent = method_getImplementation(m);
        method_setImplementation(m, (IMP)FilterPresentation);
        presentationInstalled = YES;
    }
    Class cls = NSClassFromString(@"TGAlertController");
    SEL action = NSSelectorFromString(@"showAlertWithTitle:text:cancelButton:otherButtons:completion:");
    Method method = cls ? class_getClassMethod(cls, action) : NULL;
    if (!alertInstalled && method) {
        originalAlert = method_getImplementation(method);
        class_replaceMethod(object_getClass(cls), action, (IMP)FilterNotice, method_getTypeEncoding(method));
        alertInstalled = YES;
    }
}
__attribute__((constructor)) static void StartNoticeFilter(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        InstallNoticeFilter();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { InstallNoticeFilter(); }];
    });
}
