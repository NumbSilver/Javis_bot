#import <Cocoa/Cocoa.h>

@interface InstallerController : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTextView *logView;
@property(nonatomic, strong) NSTextField *openIDField;
@property(nonatomic, strong) NSTextField *profileField;
@property(nonatomic, strong) NSTextField *gitAuthorField;
@property(nonatomic, strong) NSSecureTextField *appSecretField;
@property(nonatomic, strong) NSProgressIndicator *progress;
@property(nonatomic, assign) BOOL running;
@end

@implementation InstallerController

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 1180, 780)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable |
                            NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"Jarvis 安装向导";
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    self.window.minSize = NSMakeSize(1080, 720);
    [self.window center];

    NSSplitView *split = [[NSSplitView alloc] initWithFrame:self.window.contentView.bounds];
    split.vertical = YES;
    split.dividerStyle = NSSplitViewDividerStyleThin;
    split.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    NSVisualEffectView *stepsPanel = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 700, 780)];
    stepsPanel.material = NSVisualEffectMaterialWindowBackground;
    stepsPanel.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    stepsPanel.state = NSVisualEffectStateActive;

    NSStackView *steps = [[NSStackView alloc] initWithFrame:NSZeroRect];
    steps.orientation = NSUserInterfaceLayoutOrientationVertical;
    steps.alignment = NSLayoutAttributeLeading;
    steps.distribution = NSStackViewDistributionFill;
    steps.spacing = 10;
    steps.translatesAutoresizingMaskIntoConstraints = NO;
    [stepsPanel addSubview:steps];
    [NSLayoutConstraint activateConstraints:@[
        [steps.leadingAnchor constraintEqualToAnchor:stepsPanel.leadingAnchor constant:28],
        [steps.trailingAnchor constraintEqualToAnchor:stepsPanel.trailingAnchor constant:-28],
        [steps.topAnchor constraintEqualToAnchor:stepsPanel.topAnchor constant:48],
        [steps.bottomAnchor constraintLessThanOrEqualToAnchor:stepsPanel.bottomAnchor constant:-24]
    ]];

    NSStackView *brand = [[NSStackView alloc] initWithFrame:NSZeroRect];
    brand.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    brand.alignment = NSLayoutAttributeCenterY;
    brand.spacing = 12;
    NSTextField *brandMark = [NSTextField labelWithString:@"J"];
    brandMark.alignment = NSTextAlignmentCenter;
    brandMark.font = [NSFont boldSystemFontOfSize:18];
    brandMark.textColor = NSColor.whiteColor;
    brandMark.wantsLayer = YES;
    brandMark.layer.backgroundColor = NSColor.controlAccentColor.CGColor;
    brandMark.layer.cornerRadius = 10;
    [brandMark.widthAnchor constraintEqualToConstant:40].active = YES;
    [brandMark.heightAnchor constraintEqualToConstant:40].active = YES;
    NSStackView *brandText = [[NSStackView alloc] initWithFrame:NSZeroRect];
    brandText.orientation = NSUserInterfaceLayoutOrientationVertical;
    brandText.alignment = NSLayoutAttributeLeading;
    brandText.spacing = 1;
    NSTextField *title = [NSTextField labelWithString:@"Jarvis"];
    title.font = [NSFont boldSystemFontOfSize:25];
    NSTextField *subtitle = [NSTextField labelWithString:@"个人智能助理 · 首次安装"];
    subtitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    subtitle.textColor = NSColor.secondaryLabelColor;
    [brandText addArrangedSubview:title];
    [brandText addArrangedSubview:subtitle];
    [brand addArrangedSubview:brandMark];
    [brand addArrangedSubview:brandText];
    [steps addArrangedSubview:brand];
    [steps setCustomSpacing:18 afterView:brand];

    NSView *step1 = [self step:1 title:@"准备运行环境"
                                  detail:@"复制预构建运行时到 Application Support；保留已有数据库和运行配置。"
                                 content:[self buttonRow:@[
                                     [self button:@"准备运行环境" action:@selector(prepare:)],
                                     [self button:@"检查本机状态" action:@selector(doctor:)]
                                 ]]];
    [steps addArrangedSubview:step1];

    NSView *step2 = [self step:2 title:@"安装运行依赖"
                                  detail:@"复用现有原子动作安装官方 lark-cli、Agent Skills 和 TRAE CLI。"
                                 content:[self buttonRow:@[
                                     [self button:@"安装 lark-cli" action:@selector(installLark:)],
                                     [self button:@"安装 TRAE" action:@selector(installTrae:)],
                                     [self button:@"登录 TRAE" action:@selector(loginTrae:)],
                                     [self button:@"检查登录" action:@selector(checkTrae:)]
                                 ]]];
    [steps addArrangedSubview:step2];

    self.openIDField = [self input:@"ou_..."];
    self.profileField = [self input:@"cli_..."];
    self.gitAuthorField = [self input:@"姓名 <email@example.com>"];
    self.appSecretField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 360, 24)];
    self.appSecretField.placeholderString = @"飞书应用 App Secret";
    NSStackView *form = [NSStackView stackViewWithViews:@[
        [self formRow:@"飞书 open_id" field:self.openIDField],
        [self formRow:@"lark-cli profile" field:self.profileField],
        [self formRow:@"Git author" field:self.gitAuthorField],
        [self formRow:@"飞书 App Secret" field:self.appSecretField],
        [self button:@"配置身份并绑定 Bot" action:@selector(configure:)]
    ]];
    form.orientation = NSUserInterfaceLayoutOrientationVertical;
    form.alignment = NSLayoutAttributeLeading;
    form.spacing = 7;
    NSView *step3 = [self step:3 title:@"配置身份"
                                  detail:@"使用同一个飞书 App/Profile 绑定 Jarvis 与 CC Connect；密钥仅从标准输入传递。"
                                 content:form];
    [steps addArrangedSubview:step3];

    NSView *step4 = [self step:4 title:@"安装后台服务"
                                  detail:@"安装 Qdrant，注册签名 Jarvis 服务；终端用户无需编译 Go 或前端。"
                                 content:[self button:@"安装并启动服务" action:@selector(installServices:)]];
    [steps addArrangedSubview:step4];

    NSView *step5 = [self step:5 title:@"验收与世界模型初始化"
                                  detail:@"系统验收后，由 bootstrap-jarvis-world-model 生成近 7 天世界模型草案，确认后才写入。"
                                 content:[self buttonRow:@[
                                     [self button:@"运行系统验收" action:@selector(validate:)],
                                     [self button:@"打开初始化 Agent" action:@selector(openInitialization:)],
                                     [self button:@"打开 Jarvis" action:@selector(openJarvis:)]
                                 ]]];
    [steps addArrangedSubview:step5];
    for (NSView *card in @[step1, step2, step3, step4, step5]) {
        [card.widthAnchor constraintEqualToAnchor:steps.widthAnchor].active = YES;
    }

    NSVisualEffectView *logPanel = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 480, 780)];
    logPanel.material = NSVisualEffectMaterialSidebar;
    logPanel.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    logPanel.state = NSVisualEffectStateActive;
    NSStackView *logLayout = [[NSStackView alloc] initWithFrame:NSZeroRect];
    logLayout.orientation = NSUserInterfaceLayoutOrientationVertical;
    logLayout.spacing = 12;
    logLayout.translatesAutoresizingMaskIntoConstraints = NO;
    [logPanel addSubview:logLayout];
    [NSLayoutConstraint activateConstraints:@[
        [logLayout.leadingAnchor constraintEqualToAnchor:logPanel.leadingAnchor constant:20],
        [logLayout.trailingAnchor constraintEqualToAnchor:logPanel.trailingAnchor constant:-20],
        [logLayout.topAnchor constraintEqualToAnchor:logPanel.topAnchor constant:52],
        [logLayout.bottomAnchor constraintEqualToAnchor:logPanel.bottomAnchor constant:-20]
    ]];
    NSStackView *logHeader = [[NSStackView alloc] initWithFrame:NSZeroRect];
    logHeader.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    logHeader.alignment = NSLayoutAttributeCenterY;
    NSTextField *logTitle = [NSTextField labelWithString:@"安装日志"];
    logTitle.font = [NSFont boldSystemFontOfSize:16];
    NSTextField *logHint = [NSTextField labelWithString:@"原始输出"];
    logHint.font = [NSFont systemFontOfSize:11];
    logHint.textColor = NSColor.tertiaryLabelColor;
    [logHeader addArrangedSubview:logTitle];
    [logHeader addArrangedSubview:logHint];
    [logHeader addArrangedSubview:[[NSView alloc] initWithFrame:NSZeroRect]];
    self.progress = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.progress.style = NSProgressIndicatorStyleSpinning;
    self.progress.controlSize = NSControlSizeSmall;
    self.progress.displayedWhenStopped = NO;
    [logHeader addArrangedSubview:self.progress];
    [logLayout addArrangedSubview:logHeader];

    NSScrollView *logScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    logScroll.hasVerticalScroller = YES;
    logScroll.drawsBackground = YES;
    logScroll.backgroundColor = NSColor.textBackgroundColor;
    logScroll.borderType = NSNoBorder;
    logScroll.wantsLayer = YES;
    logScroll.layer.cornerRadius = 10;
    self.logView = [[NSTextView alloc] initWithFrame:logScroll.bounds];
    self.logView.editable = NO;
    self.logView.selectable = YES;
    self.logView.drawsBackground = NO;
    self.logView.textContainerInset = NSMakeSize(12, 12);
    self.logView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.logView.string = @"欢迎使用 Jarvis。请按顺序完成左侧步骤。\n";
    logScroll.documentView = self.logView;
    [logLayout addArrangedSubview:logScroll];
    [logScroll.widthAnchor constraintEqualToAnchor:logLayout.widthAnchor].active = YES;

    [split addSubview:stepsPanel];
    [split addSubview:logPanel];
    [split setPosition:700 ofDividerAtIndex:0];
    self.window.contentView = split;
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (NSButton *)button:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.controlSize = NSControlSizeRegular;
    button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    return button;
}

- (NSTextField *)input:(NSString *)placeholder {
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 360, 24)];
    field.placeholderString = placeholder;
    return field;
}

- (NSStackView *)buttonRow:(NSArray<NSButton *> *)buttons {
    NSStackView *row = [NSStackView stackViewWithViews:buttons];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.spacing = 8;
    return row;
}

- (NSStackView *)formRow:(NSString *)label field:(NSView *)field {
    NSTextField *labelView = [NSTextField labelWithString:label];
    labelView.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [labelView.widthAnchor constraintEqualToConstant:112].active = YES;
    NSStackView *row = [NSStackView stackViewWithViews:@[labelView, field]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 10;
    return row;
}

- (NSView *)step:(NSInteger)number title:(NSString *)title detail:(NSString *)detail content:(NSView *)content {
    NSView *card = [[NSView alloc] initWithFrame:NSZeroRect];
    card.wantsLayer = YES;
    card.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.72].CGColor;
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = NSColor.separatorColor.CGColor;
    NSTextField *badge = [NSTextField labelWithString:[NSString stringWithFormat:@"%ld", (long)number]];
    badge.alignment = NSTextAlignmentCenter;
    badge.font = [NSFont boldSystemFontOfSize:12];
    badge.textColor = NSColor.controlAccentColor;
    badge.wantsLayer = YES;
    badge.layer.backgroundColor = [NSColor.controlAccentColor colorWithAlphaComponent:0.12].CGColor;
    badge.layer.cornerRadius = 8;
    [badge.widthAnchor constraintEqualToConstant:26].active = YES;
    [badge.heightAnchor constraintEqualToConstant:26].active = YES;
    NSTextField *titleView = [NSTextField labelWithString:title];
    titleView.font = [NSFont boldSystemFontOfSize:14];
    NSStackView *header = [NSStackView stackViewWithViews:@[badge, titleView]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;
    header.spacing = 9;
    NSTextField *detailView = [NSTextField wrappingLabelWithString:detail];
    detailView.font = [NSFont systemFontOfSize:11.5];
    detailView.textColor = NSColor.secondaryLabelColor;
    NSStackView *body = [NSStackView stackViewWithViews:@[header, detailView, content]];
    body.orientation = NSUserInterfaceLayoutOrientationVertical;
    body.alignment = NSLayoutAttributeLeading;
    body.spacing = 7;
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [body.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [body.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [body.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [body.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
        [detailView.widthAnchor constraintEqualToAnchor:body.widthAnchor]
    ]];
    return card;
}

- (NSURL *)helperURL {
    return [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"jarvis-mvp"];
}

- (void)appendLog:(NSString *)text {
    self.logView.string = [self.logView.string stringByAppendingString:text];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.string.length, 0)];
}

- (void)run:(NSArray<NSString *> *)arguments input:(NSString *)input {
    if (self.running) return;
    self.running = YES;
    [self.progress startAnimation:nil];
    [self appendLog:[NSString stringWithFormat:@"\n$ jarvis-mvp %@\n", [arguments componentsJoinedByString:@" "]]];

    NSURL *helper = self.helperURL;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        NSPipe *output = [NSPipe pipe];
        NSPipe *standardInput = [NSPipe pipe];
        task.executableURL = helper;
        task.arguments = arguments;
        task.standardOutput = output;
        task.standardError = output;
        if (input != nil) task.standardInput = standardInput;
        NSError *error = nil;
        BOOL launched = [task launchAndReturnError:&error];
        if (launched && input != nil) {
            [standardInput.fileHandleForWriting writeData:[input dataUsingEncoding:NSUTF8StringEncoding]];
            [standardInput.fileHandleForWriting closeFile];
        }
        NSData *data = [NSData data];
        if (launched) {
            // Drain output while the task runs so a full pipe cannot block it.
            data = [output.fileHandleForReading readDataToEndOfFile];
            [task waitUntilExit];
        }
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        int status = launched ? task.terminationStatus : 127;
        if (!launched) text = error.localizedDescription ?: @"无法启动安装器";
        dispatch_async(dispatch_get_main_queue(), ^{
            [self appendLog:text];
            if (![text hasSuffix:@"\n"]) [self appendLog:@"\n"];
            [self appendLog:status == 0 ? @"完成。\n" :
                [NSString stringWithFormat:@"失败（退出码 %d）。请按原始错误处理后重试。\n", status]];
            self.running = NO;
            [self.progress stopAnimation:nil];
        });
    });
}

- (void)prepare:(id)sender { (void)sender; [self run:@[@"prepare"] input:nil]; }
- (void)doctor:(id)sender { (void)sender; [self run:@[@"doctor"] input:nil]; }
- (void)installLark:(id)sender { (void)sender; [self run:@[@"install-lark-cli"] input:nil]; }
- (void)installTrae:(id)sender { (void)sender; [self run:@[@"install-traex"] input:nil]; }
- (void)checkTrae:(id)sender { (void)sender; [self run:@[@"traex-status"] input:nil]; }
- (void)installServices:(id)sender { (void)sender; [self run:@[@"install-services"] input:nil]; }
- (void)validate:(id)sender { (void)sender; [self run:@[@"validate"] input:nil]; }

- (void)configure:(id)sender {
    (void)sender;
    if (self.openIDField.stringValue.length == 0 ||
        self.profileField.stringValue.length == 0 ||
        self.gitAuthorField.stringValue.length == 0 ||
        self.appSecretField.stringValue.length == 0) {
        [self appendLog:@"\n请先填写全部身份和飞书应用配置字段。\n"];
        return;
    }
    [self run:@[@"configure", self.openIDField.stringValue,
                self.profileField.stringValue, self.gitAuthorField.stringValue]
         input:self.appSecretField.stringValue];
}

- (void)loginTrae:(id)sender {
    (void)sender;
    [self openTerminal:@"export PATH=\"$HOME/Library/Application Support/Jarvis/runtime/toolchain/node/bin:$HOME/Library/Application Support/Jarvis/runtime/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin\"; traex login --sso-device"];
}

- (void)openInitialization:(id)sender {
    (void)sender;
    [self openTerminal:@"cd \"$HOME/Library/Application Support/Jarvis/runtime\" && export PATH=\"$PWD/toolchain/node/bin:$PWD/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin\"; traex '使用 $bootstrap-jarvis-world-model 完成首次世界模型初始化，先生成草案让我审阅'"];
}

- (void)openJarvis:(id)sender {
    (void)sender;
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"http://127.0.0.1:18800/"]];
}

- (void)openTerminal:(NSString *)command {
    NSString *escaped = [[command stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
        stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    NSString *source = [NSString stringWithFormat:
        @"tell application \"Terminal\"\nactivate\ndo script \"%@\"\nend tell", escaped];
    NSDictionary *error = nil;
    [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
    if (error != nil) {
        [self appendLog:[NSString stringWithFormat:@"\n无法打开 Terminal：%@\n", error]];
    }
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        InstallerController *controller = [[InstallerController alloc] init];
        application.delegate = controller;
        [application run];
    }
    return 0;
}
