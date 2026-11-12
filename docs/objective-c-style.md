# Objective-C Style

This document describes where my preferred Objective-C style differs from the
commonly used Apple style.


# Code format

Use the `clang-format` command and the rules in
[`.clang-format`](../.clang-format) to format the source code. The make target
`check-format` will show needed format changes; the make target `format` will
update files to comply.


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


# Method parameter lists

Always put a semicolon at the end of the parameter list of a method on both the
declaration and the definition. The compiler allows this and this consistency,
combined with the method braces rule, makes it easy to copy method signature
edits from declaration to definition or vice versa. The `clang-format` tool
allows this but can't enforce it.

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
