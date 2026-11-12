# Objective-C Style

This document describes where my preferred Objective-C style differs from the
commonly used Apple style.


# Line width

Wrap code to 80 columns.


# Single-line `if` statements

When an `if` statement only has a single statement block and no corresponding
`else` block, write it on a single line when that line is less than 80 columns.


# Prefixes

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


# Curly braces

Always put the opening brace of a method definition on its own line. This is
sometimes called [Allman or BSD
style](https://en.wikipedia.org/wiki/Indentation_style#Allman_style).

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

    // ¡¡ incorrect !! - where does the method body start?
    - (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
        [_store loadInBackground];
        return YES;
    }

    // correct - parameter list and method body are easy to tell apart
    - (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions;
    {
        [_store loadInBackground];
        return YES;
    }

Braces for statements and other blocks should place the opening brace on the
same line, except when the statement needs to wrap across multiple lines.

    // correct
    if (is_foo) {
        // do something
    }
    
    // correct
    if (
        super_widget_happy_fun_count < max_super_widget_happy_fun_count
        && special_widget_view_state == special_widget_view_state_active
    ) {
        // do something
    }


# Method parameter lists

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


# Objective-C class initializers

Follow the pattern below for init method definitions when practical.

    - (instancetype)init;
    {
        self = [super init];
        if (!self) return nil;
        
        // initialize instance variables
        
        return self;
    }

By using a single-line `if` for early return at the top, the initialization no
longer needs to be indented.


# Prefer `+new` over `+alloc`/`-init`

When calling the no-argument initializer, use the `+new` class method: it's
easier to read than the equivalent nested `+alloc`/`-init` call. If the class
has a `+newX:` class method equivalent to an `-initX:` method, prefer that as
well.
