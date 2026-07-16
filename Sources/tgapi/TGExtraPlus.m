#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ============================================================
// TGExtra+ — Pure Objective-C runtime hooks
// No Logos dependency, compiles with standard Clang
// ============================================================

#pragma mark - User Defaults Keys

static NSString *const kTGEnableAntiRevoke       = @"TGEnableAntiRevoke";
static NSString *const kTGEnableViewOncePhoto     = @"TGEnableViewOncePhoto";
static NSString *const kTGEnableViewOnceVideo     = @"TGEnableViewOnceVideo";
static NSString *const kTGEnableForwardBypass     = @"TGEnableForwardBypass";

#pragma mark - Logging

static void TGLog(NSString *fmt, ...) {
    va_list args; va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[TGExtra+] %@", msg);
}

static BOOL TGEnabled(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

#pragma mark - Anti-Revoke

static void (*orig_TGUpdateMessageService_processDeleteUpdates)(id, SEL, id);
static void hook_TGUpdateMessageService_processDeleteUpdates(id self, SEL _cmd, id updates) {
    if (TGEnabled(kTGEnableAntiRevoke)) {
        TGLog(@"ANTI-REVOKE: blocked message deletion");
        return;
    }
    orig_TGUpdateMessageService_processDeleteUpdates(self, _cmd, updates);
}

// Additional hook for MessagesController-style deletion
static void (*orig_MessagesController_deleteMessages)(id, SEL, id, id);
static void hook_MessagesController_deleteMessages(id self, SEL _cmd, id ids, id dialogId) {
    if (TGEnabled(kTGEnableAntiRevoke)) {
        TGLog(@"ANTI-REVOKE: blocked deleteMessages");
        return;
    }
    orig_MessagesController_deleteMessages(self, _cmd, ids, dialogId);
}

#pragma mark - View-Once Bypass

static id (*orig_isViewOnce)(id, SEL);
static id hook_isViewOnce(id self, SEL _cmd) {
    if (TGEnabled(kTGEnableViewOncePhoto) || TGEnabled(kTGEnableViewOnceVideo)) {
        TGLog(@"VIEW-ONCE BYPASS: forced isViewOnce to NO");
        return nil;
    }
    return orig_isViewOnce(self, _cmd);
}

static BOOL (*orig_isSecretMessage)(id, SEL);
static BOOL hook_isSecretMessage(id self, SEL _cmd) {
    if (TGEnabled(kTGEnableViewOncePhoto) || TGEnabled(kTGEnableViewOnceVideo)) {
        return NO;
    }
    return orig_isSecretMessage(self, _cmd);
}

static BOOL (*orig_requiresBlur)(id, SEL);
static BOOL hook_requiresBlur(id self, SEL _cmd) {
    if (TGEnabled(kTGEnableViewOncePhoto) || TGEnabled(kTGEnableViewOnceVideo)) {
        return NO;
    }
    return orig_requiresBlur(self, _cmd);
}

static BOOL (*orig_shouldAutomaticallyDelete)(id, SEL);
static BOOL hook_shouldAutomaticallyDelete(id self, SEL _cmd) {
    if (TGEnabled(kTGEnableViewOncePhoto) || TGEnabled(kTGEnableViewOnceVideo)) {
        return NO;
    }
    return orig_shouldAutomaticallyDelete(self, _cmd);
}

#pragma mark - Forward Bypass

static BOOL (*orig_canForward)(id, SEL);
static BOOL hook_canForward(id self, SEL _cmd) {
    if (TGEnabled(kTGEnableForwardBypass)) {
        return YES;
    }
    return orig_canForward(self, _cmd);
}

static BOOL (*orig_canSaveToGallery)(id, SEL);
static BOOL hook_canSaveToGallery(id self, SEL _cmd) {
    if (TGEnabled(kTGEnableForwardBypass)) {
        return YES;
    }
    return orig_canSaveToGallery(self, _cmd);
}

#pragma mark - Hook Installation

static void swizzleMethod(Class cls, SEL origSel, SEL newSel, IMP newImpl, IMP *origImpl) {
    Method m = class_getInstanceMethod(cls, origSel);
    if (!m) {
        TGLog(@"HOOK FAIL: %@ doesn't have %@", NSStringFromClass(cls), NSStringFromSelector(origSel));
        return;
    }
    *origImpl = method_getImplementation(m);
    if (class_addMethod(cls, newSel, newImpl, method_getTypeEncoding(m))) {
        method_exchangeImplementations(class_getInstanceMethod(cls, origSel),
                                       class_getInstanceMethod(cls, newSel));
        TGLog(@"HOOK OK: %@ %@", NSStringFromClass(cls), NSStringFromSelector(origSel));
    }
}

static void hookMethod(Class cls, SEL sel, IMP newImpl, IMP *origImpl) {
    if (!cls) { TGLog(@"HOOK FAIL: class is nil for %@", NSStringFromSelector(sel)); return; }
    swizzleMethod(cls, sel, sel, newImpl, origImpl);
}

#pragma mark - Settings UI

@interface TGExtraSettingsController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation TGExtraSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TGExtra+";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kTGEnableAntiRevoke: @NO, kTGEnableViewOncePhoto: @NO,
        kTGEnableViewOnceVideo: @NO, kTGEnableForwardBypass: @NO,
    }];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                        style:UIBarButtonItemStyleDone target:self action:@selector(dismissSelf)];
    self.navigationItem.rightBarButtonItem = closeBtn;
}

- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 4 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return section == 0 ? @"Anti-Revoke: Keep deleted messages.\nView-Once: Save self-destructing media.\nForward Bypass: Save protected content." : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    if (indexPath.section == 0) {
        NSArray *items = @[
            @{@"key": kTGEnableAntiRevoke, @"title": @"Anti-Revoke", @"sub": @"Keep deleted messages"},
            @{@"key": kTGEnableViewOncePhoto, @"title": @"View-Once Photo", @"sub": @"Save self-destructing photos"},
            @{@"key": kTGEnableViewOnceVideo, @"title": @"View-Once Video", @"sub": @"Save self-destructing videos"},
            @{@"key": kTGEnableForwardBypass, @"title": @"Forward Bypass", @"sub": @"Save/copy protected content"},
        ];
        NSDictionary *item = items[indexPath.row];
        cell.textLabel.text = item[@"title"];
        cell.detailTextLabel.text = item[@"sub"];
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:item[@"key"]];
        objc_setAssociatedObject(toggle, "key", item[@"key"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else {
        cell.textLabel.text = @"TGExtra+ v1.0";
        cell.detailTextLabel.text = @"Enhanced Telegram for iOS";
        cell.accessoryView = nil;
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    if (key) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        TGLog(@"Setting %@ = %d", key, sender.on);
    }
}
@end

@interface TGExtraGestureHandler : NSObject @end
@implementation TGExtraGestureHandler
- (void)handleThreeFingerLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
        if (!rootVC) return;
        TGExtraSettingsController *vc = [[TGExtraSettingsController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [rootVC presentViewController:nav animated:YES completion:nil];
    }
}
@end

#pragma mark - Constructor

__attribute__((constructor))
static void TGExtraInit() {
    TGLog(@"Loading TGExtra+...");
    dispatch_async(dispatch_get_main_queue(), ^{
        // Install 3-finger gesture
        UIWindow *window = UIApplication.sharedApplication.keyWindow;
        if (window) {
            TGExtraGestureHandler *handler = [[TGExtraGestureHandler alloc] init];
            UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
                initWithTarget:handler action:@selector(handleThreeFingerLongPress:)];
            gesture.numberOfTouchesRequired = 3;
            gesture.minimumPressDuration = 0.5;
            [window addGestureRecognizer:gesture];
            objc_setAssociatedObject(window, "TGExtraHandler", handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            kTGEnableAntiRevoke: @NO, kTGEnableViewOncePhoto: @NO,
            kTGEnableViewOnceVideo: @NO, kTGEnableForwardBypass: @NO,
        }];

        // Try multiple class name patterns across Telegram versions
        NSDictionary *hooks = @{
            @"TGUpdateMessageService": @[
                @"processDeleteUpdates:",
                @"processDeleteMessages:",
                @"deleteMessages:"
            ],
            @"TGConversationController": @[
                @"deleteMessages:inConversation:",
                @"messageDeletedInConversation:messageIds:"
            ],
            @"TGModernConversationController": @[
                @"deleteMessages:",
                @"updateConversationWithDeletedMessages:"
            ],
            @"TGMessage": @[
                @"isViewOnce",
                @"isSecretMessage",
                @"isSecret",
                @"requiresBlur",
                @"isEncrypted"
            ],
            @"TGModernConversationItem": @[
                @"isViewOnce",
                @"isSecret"
            ],
            @"TGChatMessage": @[
                @"isViewOnce",
                @"isSecret",
                @"requiresBlur"
            ],
            @"TGConversationTableViewCell": @[
                @"canForward",
                @"canSaveToGallery",
                @"canSave"
            ],
            @"TGViewController": @[
                @"canForwardMessage:"
            ]
        };

        IMP antiRevokeDelete = (IMP)hook_TGUpdateMessageService_processDeleteUpdates;
        IMP imp_isViewOnce = (IMP)hook_isViewOnce;
        IMP imp_requiresBlur = (IMP)hook_requiresBlur;
        IMP imp_canForward = (IMP)hook_canForward;
        IMP imp_canSave = (IMP)hook_canSaveToGallery;
        IMP imp_deleteMsg = (IMP)hook_MessagesController_deleteMessages;
        IMP imp_isSecret = (IMP)hook_isSecretMessage;
        IMP imp_autoDelete = (IMP)hook_shouldAutomaticallyDelete;

        for (NSString *clsName in hooks.allKeys) {
            Class cls = objc_getClass(clsName.UTF8String);
            if (!cls) { TGLog(@"Class %@ not found, skipping", clsName); continue; }

            for (NSString *selName in hooks[clsName]) {
                SEL sel = NSSelectorFromString(selName);
                IMP imp = nil;
                if ([selName containsString:@"Delete"] || [selName containsString:@"delete"]) {
                    imp = antiRevokeDelete;
                } else if ([selName isEqualToString:@"isViewOnce"]) {
                    imp = imp_isViewOnce;
                } else if ([selName containsString:@"requiresBlur"] || [selName containsString:@"RequiresBlur"]) {
                    imp = imp_requiresBlur;
                } else if ([selName isEqualToString:@"canForward"] || [selName containsString:@"canForward"]) {
                    imp = imp_canForward;
                } else if ([selName containsString:@"canSave"]) {
                    imp = imp_canSave;
                } else if ([selName containsString:@"isSecret"] || [selName containsString:@"isSecretMessage"]) {
                    imp = imp_isSecret;
                } else if ([selName containsString:@"autoDelete"] || [selName containsString:@"shouldAutomaticallyDelete"]) {
                    imp = imp_autoDelete;
                } else {
                    imp = antiRevokeDelete;
                }
                hookMethod(cls, sel, imp,
                    [selName containsString:@"Delete"] || [selName containsString:@"delete"] ?
                    (IMP *)&orig_TGUpdateMessageService_processDeleteUpdates :
                    [selName containsString:@"isViewOnce"] ? (IMP *)&orig_isViewOnce :
                    [selName containsString:@"requiresBlur"] ? (IMP *)&orig_requiresBlur :
                    [selName containsString:@"canForward"] ? (IMP *)&orig_canForward :
                    [selName containsString:@"canSave"] ? (IMP *)&orig_canSaveToGallery :
                    [selName containsString:@"isSecret"] ? (IMP *)&orig_isSecretMessage :
                    (IMP *)&orig_shouldAutomaticallyDelete);
            }
        }

        TGLog(@"TGExtra+ hooks installed");
    });
}
