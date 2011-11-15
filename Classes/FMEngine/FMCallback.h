//
//  FMCallback.h
//  FMEngine
//
//  Created by Nicolas Haunold on 5/2/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMCallback : NSObject {
  id _target;
  SEL _selector;
  id _userInfo;
  id _identifier;
}

@property (nonatomic, retain) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, retain) id userInfo;
@property (nonatomic, retain) id identifier;

+ (id)callbackWithTarget:(id)target action:(SEL)action userInfo:(id)userInfo;
+ (id)callbackWithTarget:(id)target action:(SEL)action userInfo:(id)userInfo object:(id)identifier;
- (id)initWithTarget:(id)target action:(SEL)action userInfo:(id)userInfo;
- (id)initWithTarget:(id)target action:(SEL)action userInfo:(id)userInfo object:(id)identifier;
- (void)fire;

@end
