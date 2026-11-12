#import <Foundation/Foundation.h>

typedef struct {
    CGFloat album;
    CGFloat artist;
} LowerLineWidths;

// Splits a queued track row's lower line between the album and artist names.
// While both fit, each gets the width it needs. While they do not, the album
// with its trailing padding gets up to a fixed fraction of the line, or more
// when the artist name leaves it, and the artist name gets the rest.
LowerLineWidths LowerLineWidthsSplit(
    CGFloat available, CGFloat albumIdeal, CGFloat artistIdeal);
