# Wrappers for testing

Code that uses subsystems like the filesystem or network is difficult and slow
to test. This can also be true for code that uses complex libraries. Some
subsystems like the clock and the random number generator have global state that
is impractical or impossible to change in tests.

Make code more cohesive, less coupled and more testable by wrapping these
dependencies in high level interfaces.

For normal execution, these wrappers have the "real" implementation that call
the wrapped dependency. For testing, these wrappers have fake, mock or stub
implementations. Real and fake implementations should share the same base name,
adding a suffix like `Real` or `Fake`, so that these files naturally group
together.

For example, here is a `FileSystem` interface and the `FileSystemReal`
implementation:

    @protocol FileSystem <NSObject>

    - (BOOL)createDirectoryAt:(NSURL *)url error:(NSError **)error;

    @end

    @interface FileSystemReal : NSObject <FileSystem>
    @end

    @implementation FileSystemReal

    - (BOOL)createDirectoryAt:(NSURL *)url error:(NSError **)error {
        return [NSFileManager.defaultManager createDirectoryAtURL:url
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:error];
    }

    @end

Wrapper interfaces should provide methods and properties with high level names
that describe their purpose in the application domain rather than simply
mirroring the low level, often general purpose, name being wrapped.


## Simple wrappers

In the simple case, the real implementations of wrapper methods and properties
should keep their internal logic as minimal and close to direct delegation as
practical. Some duplication in wrapper methods and properties is reasonable
where it aids readability at the use site.

For example, the wrapper below provides `getMusicDirectoryURLAndReturnError:`
and `getMoviesDirectoryURLAndReturnError:` which make the same underlying
method call to `NSFileManager`.

    @protocol FileSystem <NSObject>

    - (nullable NSURL *)getMusicDirectoryURLAndReturnError:(NSError **)error;
    - (nullable NSURL *)getMoviesDirectoryURLAndReturnError:(NSError **)error;

    @end

    @implementation FileSystemReal

    - (nullable NSURL *)getMusicDirectoryURLAndReturnError:(NSError **)error {
        return [NSFileManager.defaultManager URLForDirectory:NSMusicDirectory
                                                    inDomain:NSUserDomainMask
                                           appropriateForURL:nil
                                                      create:YES
                                                       error:error];
    }

    - (nullable NSURL *)getMoviesDirectoryURLAndReturnError:(NSError **)error {
        return [NSFileManager.defaultManager URLForDirectory:NSMoviesDirectory
                                                    inDomain:NSUserDomainMask
                                           appropriateForURL:nil
                                                      create:YES
                                                       error:error];
    }

    @end


## Fasçade wrappers

A wrapper intended to simplify use of a complex library is a **fasçade
wrapper**. Unlike simple wrappers, the real implementation of a fasçade wrapper
is intended to hide the complexity of the underlying library, so it may contain
complex logic.

When creating a fasçade wrapper, aim to find a balance between exposing and
hiding the complexity of the wrapped library rather than trying to hide all
complexity behind a minimal but inconsistent interface.

Where the complexity is essential to the current use case, it is often better to
make this complexity explicit in the fasçade interface so that it is clear in
the application domain code rather than hidden in the wrapper.

Complex libraries often expose low level detail, which requires boilerplate code
that doesn't vary much for the current use case; wrap repeated formulaic
boilerplate behind fasçade methods.

Where the wrapped library exposes complex domain objects to the caller, consider
exposing wrapper classes or handles in the fasçade interface.


## Injecting wrappers

Create real wrappers at the top layers of the application and pass them down
explicitly to functions, methods and objects that need them. This enables the
sharing of real wrapper instances and makes data flow and dependencies clear.
