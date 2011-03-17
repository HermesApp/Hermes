//
//  AuthController.h
//  Hermes
//
//  Created by Alex Crichton on 3/13/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AuthController : NSObject {
  // Fields of the AuthSheet
  IBOutlet NSButton *login;
  IBOutlet NSButton *cancel;
  IBOutlet NSProgressIndicator *spinner;
  IBOutlet NSImageView *error;
  IBOutlet NSTextField *username;
  IBOutlet NSSecureTextField *password;

  // Other fields on the main window
  IBOutlet NSButton *auth;
  IBOutlet NSProgressIndicator *bigSpinner;
}

- (IBAction)cancel: (id)sender;
- (IBAction)authenticate: (id)sender;
- (IBAction)showAuth: (id)sender;
- (IBAction)logout: (id)sender;

@end
