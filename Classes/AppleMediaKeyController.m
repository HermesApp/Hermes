//
//  AppleMediaKeyController.m
//
//  Modified by Gaurav Khanna on 8/17/10.
//  SOURCE: http://github.com/sweetfm/SweetFM/blob/master/Source/HMediaKeys.m
//  SOURCE: http://stackoverflow.com/questions/2969110/cgeventtapcreate-breaks-down-mysteriously-with-key-down-events
//
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without restriction,
//  including without limitation the rights to use, copy, modify,
//  merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
//  ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
//  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "AppleMediaKeyController.h"
#import "PreferencesController.h"

NSString * const MediaKeyPlayPauseNotification = @"MediaKeyPlayPauseNotification";
NSString * const MediaKeyNextNotification = @"MediaKeyNextNotification";
NSString * const MediaKeyPreviousNotification = @"MediaKeyPreviousNotification";

static AppleMediaKeyController *mediaKeyController = nil;

#define NX_KEYSTATE_UP      0x0A
#define NX_KEYSTATE_DOWN    0x0B

@implementation AppleMediaKeyController

@synthesize eventPort = _eventPort;

CGEventRef tapEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
  /* If we're not currently binding keys, don't do anything and let someone
     else take care of this event */
  if (mediaKeyController == nil || !mediaKeyController->listening) {
    return event;
  }
  if(type == kCGEventTapDisabledByTimeout)
    CGEventTapEnable([mediaKeyController eventPort], TRUE);

  if(type != NX_SYSDEFINED)
    return event;

  NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];

  if([nsEvent subtype] != 8)
    return event;

  int data = [nsEvent data1];
  int keyCode = (data & 0xFFFF0000) >> 16;
  int keyFlags = (data & 0xFFFF);
  int keyState = (keyFlags & 0xFF00) >> 8;
  BOOL keyIsRepeat = (keyFlags & 0x1) > 0;

  if(keyIsRepeat)
    return event;

  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  switch (keyCode) {
    case NX_KEYTYPE_PLAY:
      if(keyState == NX_KEYSTATE_DOWN)
        [center postNotificationName:MediaKeyPlayPauseNotification object:(__bridge AppleMediaKeyController *)refcon];
      if(keyState == NX_KEYSTATE_UP || keyState == NX_KEYSTATE_DOWN)
        return NULL;
      break;
    case NX_KEYTYPE_FAST:
      if(keyState == NX_KEYSTATE_DOWN)
        [center postNotificationName:MediaKeyNextNotification object:(__bridge AppleMediaKeyController *)refcon];
      if(keyState == NX_KEYSTATE_UP || keyState == NX_KEYSTATE_DOWN)
        return NULL;
      break;
    case NX_KEYTYPE_REWIND:
      if(keyState == NX_KEYSTATE_DOWN)
        [center postNotificationName:MediaKeyPreviousNotification object:(__bridge AppleMediaKeyController *)refcon];
      if(keyState == NX_KEYSTATE_UP || keyState == NX_KEYSTATE_DOWN)
        return NULL;
      break;
  }
  return event;
}

- (id) init {
  listening = FALSE;
  PREF_OBSERVE_VALUE(self, PLEASE_BIND_MEDIA);
  /* This should be a singleton class */
  assert(mediaKeyController == nil);
  mediaKeyController = self;
  return [super init];
}

- (void) listen {
  CFRunLoopRef runLoop;
  assert(!listening);
  listening = TRUE;

  _eventPort = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                CGEventMaskBit(NX_SYSDEFINED),
                                tapEventCallback,
                                (__bridge void*) self);
  assert(_eventPort != NULL);

  _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, _eventPort, 0);
  assert(_runLoopSource != NULL);
  runLoop = CFRunLoopGetCurrent();
  assert(runLoop != NULL);
  CFRunLoopAddSource(runLoop, _runLoopSource, kCFRunLoopCommonModes);
  NSLogd(@"Bound the media keys");
}

- (void) unlisten {
  assert(listening);
  listening = FALSE;
  CFRelease(_eventPort);
  CFRelease(_runLoopSource);
  NSLogd(@"Unbound the media keys");
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
      change:(NSDictionary *)change context:(void *)context {
  if (PREF_KEY_BOOL(PLEASE_BIND_MEDIA)) {
    if (!listening) [self listen];
  } else if (listening) {
    [self unlisten];
  }
}

- (void)dealloc {
  PREF_UNOBSERVE_VALUES(self, PLEASE_BIND_MEDIA);
  if (listening) {
    [self unlisten];
  }
}

@end
