// A small Cocoa backend for the subset of rawdraw used by cnping.
// Drawing coordinates and mouse positions are in top-left-origin logical points.
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../rawdraw/CNFG.h"
#include "CNFGMac.h"

static NSWindow *window;
static CGContextRef canvas;
static CGImageRef displayedFrame;
static int canvasWidth;
static int canvasHeight;
static CGFloat canvasScale;

@interface CNPingView : NSView
@end

@interface CNPingWindowDelegate : NSObject <NSWindowDelegate>
@end

static CNPingView *view;
static CNPingWindowDelegate *windowDelegate;

static void InitializeApplication(void)
{
    static int initialized;
    if (initialized) return;
    initialized = 1;

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    NSMenu *menuBar = [[NSMenu alloc] init];
    NSMenuItem *applicationItem = [[NSMenuItem alloc] init];
    [menuBar addItem:applicationItem];
    NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@"CNPing"];
    [applicationMenu addItemWithTitle:@"Quit CNPing"
                              action:@selector(terminate:)
                       keyEquivalent:@"q"];
    [applicationItem setSubmenu:applicationMenu];

    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    [menuBar addItem:fileItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Close Window"
                        action:@selector(performClose:)
                 keyEquivalent:@"w"];
    [fileItem setSubmenu:fileMenu];
    [NSApp setMainMenu:menuBar];

    [fileMenu release];
    [fileItem release];
    [applicationMenu release];
    [applicationItem release];
    [menuBar release];
    [NSApp finishLaunching];
}

int MacIsAppBundle(void)
{
    @autoreleasepool {
        return [[[[NSBundle mainBundle] bundlePath] pathExtension]
                caseInsensitiveCompare:@"app"] == NSOrderedSame;
    }
}

char *MacPromptForHost(void)
{
    @autoreleasepool {
        InitializeApplication();
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Choose a host to ping"];
        [alert setInformativeText:@"Enter a hostname, IP address, or HTTP URL."];
        [alert addButtonWithTitle:@"Start"];
        [alert addButtonWithTitle:@"Cancel"];

        NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
        [input setStringValue:@"1.1.1.1"];
        [input setPlaceholderString:@"Hostname, IP address, or http:// URL"];
        [alert setAccessoryView:input];
        [[alert window] setInitialFirstResponder:input];
        [NSApp activateIgnoringOtherApps:YES];

        char *result = NULL;
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            NSString *value = [[input stringValue] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([value length] != 0) result = strdup([value UTF8String]);
        }
        [input release];
        [alert release];
        return result;
    }
}

@implementation CNPingView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)isOpaque { return YES; }

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    if (displayedFrame) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, 0, NSHeight([self bounds]));
        CGContextScaleCTM(context, 1, -1);
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextDrawImage(context, NSRectToCGRect([self bounds]), displayedFrame);
        CGContextRestoreGState(context);
    } else {
        [[NSColor blackColor] setFill];
        NSRectFill([self bounds]);
    }
}

- (void)keyDown:(NSEvent *)event
{
    if ([event isARepeat]) return;
    if ([event modifierFlags] & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) {
        [super keyDown:event];
        return;
    }
    NSString *characters = [[event charactersIgnoringModifiers] lowercaseString];
    if ([characters length]) HandleKey((int)[characters characterAtIndex:0], 1);
}

- (NSPoint)pointForEvent:(NSEvent *)event
{
    return [self convertPoint:[event locationInWindow] fromView:nil];
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint point = [self pointForEvent:event];
    HandleButton((int)point.x, (int)point.y, 1, 1);
}

- (void)mouseDragged:(NSEvent *)event
{
    NSPoint point = [self pointForEvent:event];
    HandleMotion((int)point.x, (int)point.y, 1);
}

- (void)mouseUp:(NSEvent *)event
{
    NSPoint point = [self pointForEvent:event];
    HandleButton((int)point.x, (int)point.y, 1, 0);
}
@end

@implementation CNPingWindowDelegate
- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    HandleDestroy();
}
@end

int CNFGSetup(const char *title, int width, int height)
{
    @autoreleasepool {
        InitializeApplication();
        width = width < 640 ? 640 : width;
        height = height < 200 ? 200 : height;
        NSRect rect = NSMakeRect(0, 0, width, height);
        NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                  NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
        window = [[NSWindow alloc] initWithContentRect:rect styleMask:style
                                              backing:NSBackingStoreBuffered defer:NO];
        if (!window) {
            fprintf(stderr, "Could not create the macOS window.\n");
            return -1;
        }
        view = [[CNPingView alloc] initWithFrame:rect];
        windowDelegate = [[CNPingWindowDelegate alloc] init];
        [window setDelegate:windowDelegate];
        [window setReleasedWhenClosed:NO];
        [window setContentView:view];
        [window setContentMinSize:NSMakeSize(320, 155)];
        NSString *windowTitle = [NSString stringWithUTF8String:title];
        [window setTitle:windowTitle ? windowTitle : @"CNPing"];
        [window center];
        [window makeKeyAndOrderFront:nil];
        [window makeFirstResponder:view];
        [NSApp activateIgnoringOtherApps:YES];
        return 0;
    }
}

int CNFGSetupWMClass(const char *title, int width, int height, char *name, char *className)
{
    (void)name;
    (void)className;
    return CNFGSetup(title, width, height);
}

void CNFGHandleInput(void)
{
    @autoreleasepool {
        NSEvent *event;
        while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                          untilDate:[NSDate distantPast]
                                             inMode:NSDefaultRunLoopMode
                                            dequeue:YES])) {
            [NSApp sendEvent:event];
        }
        [NSApp updateWindows];
    }
}

void CNFGGetDimensions(short *width, short *height)
{
    NSSize size = [view bounds].size;
    *width = (short)fmin(SHRT_MAX, fmax(1, floor(size.width)));
    *height = (short)fmin(SHRT_MAX, fmax(1, floor(size.height)));
}

static void SetColor(uint32_t rgba)
{
    CGFloat red = ((rgba >> 24) & 0xff) / 255.0;
    CGFloat green = ((rgba >> 16) & 0xff) / 255.0;
    CGFloat blue = ((rgba >> 8) & 0xff) / 255.0;
    CGFloat alpha = (rgba & 0xff) / 255.0;
    CGContextSetRGBFillColor(canvas, red, green, blue, alpha);
    CGContextSetRGBStrokeColor(canvas, red, green, blue, alpha);
}

void CNFGClearFrame(void)
{
    short width, height;
    CNFGGetDimensions(&width, &height);
    CGFloat scale = [window backingScaleFactor];
    if (scale < 1) scale = 1;
    if (!canvas || width != canvasWidth || height != canvasHeight || scale != canvasScale) {
        if (canvas) CGContextRelease(canvas);
        canvasWidth = width;
        canvasHeight = height;
        canvasScale = scale;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        canvas = CGBitmapContextCreate(NULL, (size_t)ceil(width * scale),
                                       (size_t)ceil(height * scale), 8, 0, colorSpace,
                                       kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(colorSpace);
        if (!canvas) {
            fprintf(stderr, "Could not allocate the macOS drawing buffer.\n");
            exit(1);
        }
        CGContextScaleCTM(canvas, scale, scale);
        CGContextTranslateCTM(canvas, 0, height);
        CGContextScaleCTM(canvas, 1, -1);
        CGContextSetShouldAntialias(canvas, false);
        CGContextSetLineWidth(canvas, 1);
        CGContextSetLineCap(canvas, kCGLineCapButt);
    }
    SetColor(CNFGBGColor);
    CGContextFillRect(canvas, CGRectMake(0, 0, width, height));
}

uint32_t CNFGColor(uint32_t color)
{
    CNFGLastColor = color;
    SetColor(color);
    return color;
}

void CNFGTackPixel(short x, short y)
{
    CGContextFillRect(canvas, CGRectMake(x, y, 1, 1));
}

void CNFGTackSegment(short x1, short y1, short x2, short y2)
{
    if (x1 == x2 && y1 == y2) {
        CNFGTackPixel(x1, y1);
        return;
    }
    CGContextBeginPath(canvas);
    CGContextMoveToPoint(canvas, x1 + 0.5, y1 + 0.5);
    CGContextAddLineToPoint(canvas, x2 + 0.5, y2 + 0.5);
    CGContextStrokePath(canvas);
}

void CNFGTackRectangle(short x1, short y1, short x2, short y2)
{
    if (x2 > x1 && y2 > y1)
        CGContextFillRect(canvas, CGRectMake(x1, y1, x2 - x1, y2 - y1));
}

void CNFGSwapBuffers(void)
{
    @autoreleasepool {
        CGImageRef frame = CGBitmapContextCreateImage(canvas);
        if (!frame) return;
        if (displayedFrame) CGImageRelease(displayedFrame);
        displayedFrame = frame;
        [view setNeedsDisplay:YES];
        [view displayIfNeeded];
    }
}
