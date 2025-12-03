// Minimal Cocoa implementation of retropad for macOS.
#import <Cocoa/Cocoa.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString *const kAppTitle = @"retropad";
static NSString *const kUntitledName = @"Untitled";

@interface RetroPadAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate>
@property (strong) NSWindow *window;
@property (strong) NSScrollView *scrollView;
@property (strong) NSTextView *textView;
@property (strong) NSTextField *statusLabel;
@property (strong) NSURL *currentURL;
@property NSStringEncoding currentEncoding;
@property BOOL wordWrap;
@property BOOL statusVisible;
@property BOOL hasUnsavedChanges;
@property (strong) NSLayoutConstraint *scrollBottomToStatus;
@property (strong) NSLayoutConstraint *scrollBottomToContent;
@end

@implementation RetroPadAppDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _wordWrap = YES;
        _statusVisible = YES;
        _currentEncoding = NSUTF8StringEncoding;
        _hasUnsavedChanges = NO;
    }
    return self;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    return [self maybeSaveChanges] ? NSTerminateNow : NSTerminateCancel;
}

- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    return [self maybeSaveChanges];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self buildMenuBar];
    [self createWindow];
}

- (NSMenuItem *)addMenuItemWithTitle:(NSString *)title
                              action:(SEL)action
                                 key:(NSString *)key
                            modifiers:(NSEventModifierFlags)mods
                               target:(id)target
                                menu:(NSMenu *)menu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                  action:action
                                           keyEquivalent:key ? key : @""];
    if (key && key.length > 0) {
        item.keyEquivalentModifierMask = (mods == 0) ? NSEventModifierFlagCommand : mods;
    }
    item.target = target;
    [menu addItem:item];
    return item;
}

- (void)buildMenuBar {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:kAppTitle];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"About %@", kAppTitle]
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    [mainMenu addItem:appItem];

    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [self addMenuItemWithTitle:@"New" action:@selector(newDocument:) key:@"n" modifiers:0 target:self menu:fileMenu];
    [self addMenuItemWithTitle:@"Open…" action:@selector(openDocument:) key:@"o" modifiers:0 target:self menu:fileMenu];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemWithTitle:@"Save" action:@selector(saveDocument:) key:@"s" modifiers:0 target:self menu:fileMenu];
    [self addMenuItemWithTitle:@"Save As…" action:@selector(saveDocumentAs:) key:@"S" modifiers:(NSEventModifierFlagShift | NSEventModifierFlagCommand) target:self menu:fileMenu];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemWithTitle:@"Close Window" action:@selector(performClose:) key:@"w" modifiers:0 target:self menu:fileMenu];
    fileItem.submenu = fileMenu;
    [mainMenu addItem:fileItem];

    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [self addMenuItemWithTitle:@"Undo" action:@selector(undo:) key:@"z" modifiers:0 target:nil menu:editMenu];
    [self addMenuItemWithTitle:@"Redo" action:@selector(redo:) key:@"Z" modifiers:NSEventModifierFlagShift | NSEventModifierFlagCommand target:nil menu:editMenu];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemWithTitle:@"Cut" action:@selector(cut:) key:@"x" modifiers:0 target:nil menu:editMenu];
    [self addMenuItemWithTitle:@"Copy" action:@selector(copy:) key:@"c" modifiers:0 target:nil menu:editMenu];
    [self addMenuItemWithTitle:@"Paste" action:@selector(paste:) key:@"v" modifiers:0 target:nil menu:editMenu];
    [self addMenuItemWithTitle:@"Select All" action:@selector(selectAll:) key:@"a" modifiers:0 target:nil menu:editMenu];
    [editMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *findItem = [self addMenuItemWithTitle:@"Find…" action:@selector(performFindPanelAction:) key:@"f" modifiers:0 target:nil menu:editMenu];
    findItem.tag = NSFindPanelActionShowFindPanel;
    NSMenuItem *findNextItem = [self addMenuItemWithTitle:@"Find Next" action:@selector(performFindPanelAction:) key:@"g" modifiers:0 target:nil menu:editMenu];
    findNextItem.tag = NSFindPanelActionNext;
    NSMenuItem *findPrevItem = [self addMenuItemWithTitle:@"Find Previous" action:@selector(performFindPanelAction:) key:@"G" modifiers:(NSEventModifierFlagShift | NSEventModifierFlagCommand) target:nil menu:editMenu];
    findPrevItem.tag = NSFindPanelActionPrevious;
    NSMenuItem *replaceItem = [self addMenuItemWithTitle:@"Replace…" action:@selector(performFindPanelAction:) key:@"f" modifiers:(NSEventModifierFlagCommand | NSEventModifierFlagOption) target:nil menu:editMenu];
    replaceItem.tag = NSFindPanelActionReplace;

    [editMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemWithTitle:@"Go To Line…" action:@selector(goToLine:) key:@"l" modifiers:0 target:self menu:editMenu];
    [self addMenuItemWithTitle:@"Insert Time/Date" action:@selector(insertTimeDate:) key:@"d" modifiers:0 target:self menu:editMenu];

    editItem.submenu = editMenu;
    [mainMenu addItem:editItem];

    NSMenuItem *formatItem = [[NSMenuItem alloc] init];
    NSMenu *formatMenu = [[NSMenu alloc] initWithTitle:@"Format"];
    [self addMenuItemWithTitle:@"Word Wrap" action:@selector(toggleWordWrap:) key:@"" modifiers:0 target:self menu:formatMenu];
    [self addMenuItemWithTitle:@"Show Status Bar" action:@selector(toggleStatusBar:) key:@"" modifiers:0 target:self menu:formatMenu];
    [formatMenu addItem:[NSMenuItem separatorItem]];
    [self addMenuItemWithTitle:@"Font…" action:@selector(orderFrontFontPanel:) key:@"t" modifiers:0 target:[NSFontManager sharedFontManager] menu:formatMenu];
    formatItem.submenu = formatMenu;
    [mainMenu addItem:formatItem];

    NSMenuItem *helpItem = [[NSMenuItem alloc] init];
    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    [helpMenu addItemWithTitle:@"About retropad" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    helpItem.submenu = helpMenu;
    [mainMenu addItem:helpItem];

    [NSApp setMainMenu:mainMenu];
}

- (void)createWindow {
    NSRect frame = NSMakeRect(0, 0, 720, 540);
    NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.delegate = self;
    self.window.title = kAppTitle;
    [self.window center];

    NSView *contentView = self.window.contentView;

    self.scrollView = [[NSScrollView alloc] initWithFrame:contentView.bounds];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.hasVerticalScroller = YES;

    self.textView = [[NSTextView alloc] initWithFrame:contentView.bounds];
    self.textView.richText = NO;
    self.textView.automaticQuoteSubstitutionEnabled = NO;
    self.textView.automaticDashSubstitutionEnabled = NO;
    self.textView.automaticTextReplacementEnabled = NO;
    self.textView.automaticSpellingCorrectionEnabled = NO;
    self.textView.automaticLinkDetectionEnabled = NO;
    self.textView.automaticDataDetectionEnabled = NO;
    self.textView.usesFontPanel = YES;
    self.textView.usesFindPanel = YES;
    self.textView.allowsUndo = YES;
    self.textView.delegate = self;
    self.textView.textContainerInset = NSMakeSize(6, 6);
    NSFont *mono = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    self.textView.font = mono ? mono : [NSFont userFixedPitchFontOfSize:13];
    [self applyWordWrap];

    self.scrollView.documentView = self.textView;

    self.statusLabel = [NSTextField labelWithString:@"Ln 1, Col 1    Lines: 1"];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;

    [contentView addSubview:self.scrollView];
    [contentView addSubview:self.statusLabel];

    self.scrollBottomToStatus = [self.scrollView.bottomAnchor constraintEqualToAnchor:self.statusLabel.topAnchor];
    self.scrollBottomToContent = [self.scrollView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:8],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-8],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-6],
    ]];

    [self.scrollBottomToStatus setActive:self.statusVisible];
    [self.scrollBottomToContent setActive:!self.statusVisible];

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self updateTitle];
    [self updateStatus];
}

- (void)applyWordWrap {
    self.textView.textContainer.widthTracksTextView = self.wordWrap;
    if (self.wordWrap) {
        self.textView.textContainer.containerSize = NSMakeSize(self.scrollView.contentSize.width, CGFLOAT_MAX);
        self.scrollView.hasHorizontalScroller = NO;
    } else {
        self.textView.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        self.scrollView.hasHorizontalScroller = YES;
    }
}

- (BOOL)maybeSaveChanges {
    if (!self.hasUnsavedChanges) return YES;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Do you want to save changes?";
    alert.informativeText = self.currentURL ? self.currentURL.lastPathComponent : kUntitledName;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Don't Save"];
    [alert addButtonWithTitle:@"Cancel"];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        return [self saveDocument:nil];
    } else if (response == NSAlertSecondButtonReturn) {
        return YES;
    }
    return NO;
}

- (void)markDirty:(BOOL)dirty {
    self.hasUnsavedChanges = dirty;
    [self.window setDocumentEdited:dirty];
    [self updateTitle];
}

- (void)updateTitle {
    NSString *name = self.currentURL ? self.currentURL.lastPathComponent : kUntitledName;
    NSString *star = self.hasUnsavedChanges ? @"*" : @"";
    self.window.title = [NSString stringWithFormat:@"%@%@ - %@", star, name, kAppTitle];
}

- (void)updateStatus {
    NSString *text = self.textView.string ?: @"";
    NSUInteger length = text.length;
    NSRange sel = self.textView.selectedRange;
    if (sel.location == NSNotFound) {
        sel.location = 0;
    }
    NSUInteger pos = MIN(sel.location, length);

    NSUInteger line = 1;
    NSUInteger col = 1;
    for (NSUInteger i = 0; i < pos; ++i) {
        unichar c = [text characterAtIndex:i];
        if (c == '\n') {
            line++;
            col = 1;
        } else {
            col++;
        }
    }

    NSUInteger lines = 1;
    for (NSUInteger i = 0; i < length; ++i) {
        if ([text characterAtIndex:i] == '\n') {
            lines++;
        }
    }

    self.statusLabel.stringValue = [NSString stringWithFormat:@"Ln %lu, Col %lu    Lines: %lu",
                                     (unsigned long)line, (unsigned long)col, (unsigned long)lines];
}

- (BOOL)loadFromURL:(NSURL *)url {
    if (!url) return NO;
    NSStringEncoding used = NSUTF8StringEncoding;
    NSError *err = nil;
    NSString *contents = [NSString stringWithContentsOfURL:url usedEncoding:&used error:&err];
    if (!contents) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Unable to open file.";
        alert.informativeText = err.localizedDescription ?: @"Unknown error.";
        [alert runModal];
        return NO;
    }

    self.currentURL = url;
    self.currentEncoding = used;
    self.textView.string = contents;
    [self markDirty:NO];
    [self updateStatus];
    return YES;
}

- (BOOL)saveToURL:(NSURL *)url {
    if (!url) return NO;
    NSError *err = nil;
    NSString *text = self.textView.string ?: @"";
    NSStringEncoding enc = self.currentEncoding ? self.currentEncoding : NSUTF8StringEncoding;
    BOOL ok = [text writeToURL:url atomically:YES encoding:enc error:&err];
    if (!ok) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Failed to save file.";
        alert.informativeText = err.localizedDescription ?: @"Unknown error.";
        [alert runModal];
        return NO;
    }

    self.currentURL = url;
    [self markDirty:NO];
    return YES;
}

- (BOOL)newDocument:(id)sender {
    (void)sender;
    if (![self maybeSaveChanges]) return NO;
    self.textView.string = @"";
    self.currentURL = nil;
    self.currentEncoding = NSUTF8StringEncoding;
    [self markDirty:NO];
    [self updateStatus];
    return YES;
}

- (BOOL)openDocument:(id)sender {
    (void)sender;
    if (![self maybeSaveChanges]) return NO;

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.allowedContentTypes = @[UTTypeText];
    if ([panel runModal] == NSModalResponseOK) {
        return [self loadFromURL:panel.URL];
    }
    return NO;
}

- (BOOL)saveDocument:(id)sender {
    (void)sender;
    if (!self.currentURL) {
        return [self saveDocumentAs:nil];
    }
    return [self saveToURL:self.currentURL];
}

- (BOOL)saveDocumentAs:(id)sender {
    (void)sender;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[UTTypePlainText];
    panel.nameFieldStringValue = self.currentURL ? self.currentURL.lastPathComponent : @"Untitled.txt";
    if ([panel runModal] == NSModalResponseOK) {
        self.currentEncoding = NSUTF8StringEncoding;
        return [self saveToURL:panel.URL];
    }
    return NO;
}

- (void)insertTimeDate:(id)sender {
    (void)sender;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateStyle = NSDateFormatterShortStyle;
    fmt.timeStyle = NSDateFormatterShortStyle;
    NSString *stamp = [fmt stringFromDate:[NSDate date]];
    [self.textView insertText:stamp replacementRange:self.textView.selectedRange];
    [self markDirty:YES];
}

- (void)toggleWordWrap:(id)sender {
    (void)sender;
    self.wordWrap = !self.wordWrap;
    [self applyWordWrap];
    [self updateStatus];
}

- (void)toggleStatusBar:(id)sender {
    (void)sender;
    self.statusVisible = !self.statusVisible;
    self.statusLabel.hidden = !self.statusVisible;
    [self.scrollBottomToStatus setActive:self.statusVisible];
    [self.scrollBottomToContent setActive:!self.statusVisible];
}

- (void)goToLine:(id)sender {
    (void)sender;
    if (self.wordWrap) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Go To is unavailable when Word Wrap is on.";
        [alert runModal];
        return;
    }

    NSAlert *prompt = [[NSAlert alloc] init];
    prompt.messageText = @"Go To Line";
    prompt.informativeText = @"Enter a line number:";
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    field.stringValue = @"1";
    prompt.accessoryView = field;
    [prompt addButtonWithTitle:@"Go"];
    [prompt addButtonWithTitle:@"Cancel"];

    NSModalResponse resp = [prompt runModal];
    if (resp != NSAlertFirstButtonReturn) return;

    NSInteger lineNumber = field.integerValue;
    if (lineNumber < 1) lineNumber = 1;

    NSString *text = self.textView.string ?: @"";
    NSUInteger length = text.length;
    NSUInteger currentLine = 1;
    NSUInteger idx = 0;
    while (idx < length && currentLine < (NSUInteger)lineNumber) {
        if ([text characterAtIndex:idx] == '\n') {
            currentLine++;
        }
        idx++;
    }
    NSRange target = NSMakeRange(idx, 0);
    self.textView.selectedRange = target;
    [self.textView scrollRangeToVisible:target];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;
    if (action == @selector(saveDocument:)) {
        return self.hasUnsavedChanges || self.currentURL != nil;
    }
    if (action == @selector(toggleWordWrap:)) {
        menuItem.state = self.wordWrap ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(toggleStatusBar:)) {
        menuItem.state = self.statusVisible ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    if (action == @selector(goToLine:)) {
        return !self.wordWrap;
    }
    return YES;
}

#pragma mark - NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification {
    (void)notification;
    [self markDirty:YES];
    [self updateStatus];
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    (void)notification;
    [self updateStatus];
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        RetroPadAppDelegate *delegate = [[RetroPadAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
