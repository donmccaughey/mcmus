# Background processing

macOS and iOS support multiple ways to perform work off of the application's
main thread. As a general principle, background processing works best when there
the interface between the main thread and the background work is well defined
and as small and simple as possible.


## Mechanisms


### Separate process and XPC

When working with untrusted data or when isolation from the main process
improves reliability, use a background process and [XPC][] for interprocess
communication.

[XPC]: https://developer.apple.com/documentation/xpc?language=objc

NB: The `file-sharing` library currently uses a background thread but I'm
planning to move the file sharing server to a background process for increased
security in a future change.


### Thread

When the background work is long-lived, such as a server component, or needs a
separate run loop or a custom event loop, use a background thread.


### Serial queue

For multi-step background operations where steps share state data, use one
serial queue with `dispatch_async()`: the operation runs in a linear fashion and
state data doesn't require synchronization. The completed operation calls
`dispatch_async()` on the main queue or the delegate queue to communicate its
results.


### Concurrent queue

For one-shot operations with clear data isolation like reading and parsing a
large file, use one of the global concurrent queues with `dispatch_async()`; the
completed operation uses `dispatch_async()` on the main queue to communicate its
results.


## Asynchronous interfaces


### Callbacks and context pointers

For standard C code, use a callback function with a `context` or `user_data`
pointer to state data. This interface style is well understood and reasonably
easy to reason about.


### Blocks

Apple's [blocks][] extension adds closures to C and Objective-C, which can take
the place of callbacks and context pointers. Use this interface style sparingly
and carefully since blocks interact with Objective-C's ARC memory management,
making it easy to create retain cycles that leak memory and resources.

[blocks]: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Blocks/Articles/00_Introduction.html

Where Apple's libraries offer both delegate interfaces and block interfaces,
prefer the delegate interface; choose the block interface only for the simplest
cases.


### Delegates

In Objective-C code, define a delegate protocol for callers to implement.
Delegates replace C callbacks and context pointers. Use a delegate for all but
the simplest cases.

When the asynchronous operation runs on a different thread or queue than the
caller, explicitly specify both the delegate and delegate queue; the
asynchronous operation then uses `dispatch_async()` to run delegate methods on
the delegate queue.
