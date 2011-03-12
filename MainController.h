//
//  MainController.h
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//  Copyright 2011 Carnegie Mellon University. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Pandora.h"

@interface MainController : NSObject {
  IBOutlet NSButton *auth;
  IBOutlet NSTextField *username;
  IBOutlet NSSecureTextField *password;
  IBOutlet NSTextFieldCell *authTokenLabel;
  IBOutlet NSTextFieldCell *listenerIdLabel;
  IBOutlet NSTableView *stationsTable;

  Pandora *pandora;
}

- (IBAction)authenticate: (id)sender;
- (IBAction)tableViewSelected: (id)sender;

@end
