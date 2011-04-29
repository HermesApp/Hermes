//
//  PreferencesController.h
//  Hermes
//
//  Created by Alex Crichton on 4/29/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define PLEASE_BIND_MEDIA @"hermes.please-bind-media"
#define PLEASE_SCROBBLE @"hermes.please-scrobble"

@interface PreferencesController : NSObject
#ifdef MAC_OS_X_VERSION_10_6
<NSWindowDelegate>
#endif
{
  NSButton *scrobble;
  NSButton *bindMedia;
}

@property (nonatomic, retain) IBOutlet NSButton *scrobble;
@property (nonatomic, retain) IBOutlet NSButton *bindMedia;

- (IBAction) changeScrobbleTo: (id) sender;
- (IBAction) changeBindMediaTo: (id) sender;

@end
