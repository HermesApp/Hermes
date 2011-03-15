//
//  AuthController.h
//  Hermes
//
//  Created by Alex Crichton on 3/13/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AuthController : NSObject {
  IBOutlet NSButton *login;
  IBOutlet NSButton *cancel;
  IBOutlet NSProgressIndicator *spinner;
  IBOutlet NSImageView *error;

  IBOutlet NSTextField *username;
  IBOutlet NSSecureTextField *password;
}

- (IBAction)cancel: (id)sender;
- (IBAction)authenticate: (id)sender;

@end
