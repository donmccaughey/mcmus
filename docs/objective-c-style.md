# Objective-C Style

This document describes where my preferred Objective-C style differs from the
commonly used Apple style.

## Prefixes

Apple reserves all prefixes of two capital letters for their use (e.g. `NS`,
`UI`, `AV`, etc) and recommends that libraries use prefixes of three capital
letters. Many projects routinely apply such a prefix even to their own internal
code.

For purely internal code, both app code and internal library code, **do not**
use a prefix: the chances of name collision is low, is easily detected and
easily worked-around. Prefixes for internal code add visual noise for little
benefit.

For published library code, **do** use a three capital letter prefix. If the
library publishes extension methods, properties or instance variables for
Apple's or another vendor's code, also add a prefix to those names to avoid
future name collisions.

Do not add additional descriptors or qualifiers to class, struct or function
names when a simple or base name is clear in all the contexts where it is used.
For instance, the class name `AppDelegate` is clear throughout the app; there is
no need to further qualify it as `<AppName>AppDelegate`.


## Method braces

Always put the opening brace of a method definition on its own line.

    // ¡¡ incorrect !!
    + (AppDelegate *)shared {
        return (AppDelegate *)UIApplication.sharedApplication.delegate;
    }

    // correct
    + (AppDelegate *)shared;
    {
        return (AppDelegate *)UIApplication.sharedApplication.delegate;
    }

This creates wasted vertical space for short method parameter lists like the
above snippet but greatly increases readability when a method's parameter list
is long and needs to wrap across several lines.

    // ¡¡ incorrect - where does the method body start? !!
    - (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
        [_store loadInBackgroundIsDemo:[NSProcessInfo.processInfo.arguments containsObject:@"--demo"]];
        return YES;
    }

    // correct - parameter list and method body are easy to find
    - (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions;
    {
        [_store loadInBackgroundIsDemo:[NSProcessInfo.processInfo.arguments containsObject:@"--demo"]];
        return YES;
    }


## Method parameter lists

Always put a semicolon at the end of the parameter list of a method on both the
declaration and the definition. The compiler allows this and this consistency,
combined with the method braces rule, makes it easy to copy method signature
edits from declaration to definition or vice versa.

    // ¡¡ incorrect !!
    
    // declaration in "Queue.h"
    - (void)add:(id<FolderChild>)child;
    
    // definition in "Queue.m"
    - (void)add:(id<FolderChild>)child {
        [self addChildren:@[child]];
    }

    // correct
    
    // declaration in "Queue.h"
    - (void)add:(id<FolderChild>)child;
    
    // definition in "Queue.m"
    - (void)add:(id<FolderChild>)child;
    {
        [self addChildren:@[child]];
    }
