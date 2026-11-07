#import "MainMenu.h"

#if TARGET_OS_OSX
static NSMenuItem *menuItem(NSString *title, NSArray<NSMenuItem *> *items) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:title];
    for (NSMenuItem *item in items) {
        [menu addItem:item];
    }
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    menuItem.submenu = menu;
    return menuItem;
}

static NSMenuItem *item(NSString *title, SEL _Nullable action, NSString *keyEquivalent) {
    return [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent];
}

static NSMenuItem *appMenuItem(id settingsTarget, SEL settingsAction) {
    NSMenuItem *settings = item(@"Settings…", settingsAction, @",");
    settings.target = settingsTarget;

    NSMenuItem *hideOthers = item(@"Hide Others", @selector(hideOtherApplications:), @"h");
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;

    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    NSApp.servicesMenu = servicesMenu;
    NSMenuItem *services = item(@"Services", nil, @"");
    services.submenu = servicesMenu;

    return menuItem(@"MC Mus", @[
        item(@"About MC Mus", @selector(orderFrontStandardAboutPanel:), @""),
        [NSMenuItem separatorItem],
        settings,
        [NSMenuItem separatorItem],
        services,
        [NSMenuItem separatorItem],
        item(@"Hide MC Mus", @selector(hide:), @"h"),
        hideOthers,
        item(@"Show All", @selector(unhideAllApplications:), @""),
        [NSMenuItem separatorItem],
        item(@"Quit MC Mus", @selector(terminate:), @"q"),
    ]);
}

static NSMenuItem *fileMenuItem(void) {
    return menuItem(@"File", @[
        item(@"Close", @selector(performClose:), @"w"),
    ]);
}

static NSMenuItem *editMenuItem(void) {
    return menuItem(@"Edit", @[
        item(@"Undo", NSSelectorFromString(@"undo:"), @"z"),
        item(@"Redo", NSSelectorFromString(@"redo:"), @"Z"),
        [NSMenuItem separatorItem],
        item(@"Cut", @selector(cut:), @"x"),
        item(@"Copy", @selector(copy:), @"c"),
        item(@"Paste", @selector(paste:), @"v"),
        item(@"Delete", @selector(delete:), @""),
        item(@"Select All", @selector(selectAll:), @"a"),
    ]);
}

static NSMenuItem *windowMenuItem(void) {
    NSMenuItem *windowItem = menuItem(@"Window", @[
        item(@"Minimize", @selector(performMiniaturize:), @"m"),
        item(@"Zoom", @selector(performZoom:), @""),
        [NSMenuItem separatorItem],
        item(@"Bring All to Front", @selector(arrangeInFront:), @""),
    ]);
    NSApp.windowsMenu = windowItem.submenu;
    return windowItem;
}

NSMenu *makeMainMenu(id settingsTarget, SEL settingsAction) {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    [mainMenu addItem:appMenuItem(settingsTarget, settingsAction)];
    [mainMenu addItem:fileMenuItem()];
    [mainMenu addItem:editMenuItem()];
    [mainMenu addItem:windowMenuItem()];
    return mainMenu;
}
#endif
