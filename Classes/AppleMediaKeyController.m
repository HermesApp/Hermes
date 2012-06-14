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

#import <IOKit/hidsystem/ev_keymap.h>

#import "AppleMediaKeyController.h"
#import "PreferencesController.h"

#define NX_KEYSTATE_UP      0x0A
#define NX_KEYSTATE_DOWN    0x0B

@implementation AppleMediaKeyController

CGEventRef tapEventCallback(CGEventTapProxy proxy, CGEventType type,
                            CGEventRef event, void *refcon) {
  AppleMediaKeyController *m = (__bridge AppleMediaKeyController*) refcon;
  if (!PREF_KEY_BOOL(PLEASE_BIND_MEDIA)) return event;
  assert(m != nil);
  assert(m->_eventPort != nil);
  switch (type) {
    case kCGEventTapDisabledByTimeout:
      CGEventTapEnable(m->_eventPort, TRUE);
    default:
      return event;
    case NX_SYSDEFINED:
      break;
  }

  NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];

  if ([nsEvent subtype] != 8)
    return event;

  int data         = [nsEvent data1];
  int keyCode      = (data & 0xFFFF0000) >> 16;
  int keyFlags     = (data & 0xFFFF);
  int keyState     = (keyFlags & 0xFF00) >> 8;
  BOOL keyIsRepeat = (keyFlags & 0x1) > 0;

  if (keyIsRepeat)
    return event;

  NSString *name = nil;
  switch (keyCode) {
    case NX_KEYTYPE_PLAY:
      if (keyState == NX_KEYSTATE_DOWN)
        name = MediaKeyPlayPauseNotification;
      break;
    case NX_KEYTYPE_FAST:
      if (keyState == NX_KEYSTATE_DOWN)
        name = MediaKeyNextNotification;
      break;
    case NX_KEYTYPE_REWIND:
      if (keyState == NX_KEYSTATE_DOWN)
        name = MediaKeyPreviousNotification;
      break;
    default:
      return event;
  }
  if (name != nil) {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:name object:m];
  }
  return NULL;
}

- (id) init {
  return [super init];
}

- (void)dealloc {
}

@end
