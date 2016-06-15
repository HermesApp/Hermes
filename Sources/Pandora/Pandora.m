/**
 * @file Models/Pandora.m
 * @brief Implementation of the API with Pandora
 *
 * Currently this is an implementation of the JSON protocol version 5, as
 * documented here: http://6xq.net/playground/pandora-apidoc/json/
 */

#include <string.h>

#import "FMEngine/NSString+FMEngine.h"
#import "HermesAppDelegate.h"
#import "Pandora.h"
#import "Pandora/Crypt.h"
#import "Pandora/Song.h"
#import "Pandora/Station.h"
#import "PreferencesController.h"
#import "URLConnection.h"
#import "Notifications.h"
#import "PandoraDevice.h"

#pragma mark Error Codes

static NSString *lowerrs[] = {
  [0] = @"Internal Pandora error",
  [1] = @"Pandora is in Maintenance Mode",
  [2] = @"URL is missing method parameter",
  [3] = @"URL is missing auth token",
  [4] = @"URL is missing partner ID",
  [5] = @"URL is missing user ID",
  [6] = @"A secure protocol is required for this request",
  [7] = @"A certificate is required for the request",
  [8] = @"Paramter type mismatch",
  [9] = @"Parameter is missing",
  [10] = @"Parameter value is invalid",
  [11] = @"API version is not supported",
  [12] = @"Pandora is not available in this country",
  [13] = @"Bad sync time",
  [14] = @"Unknown method name",
  [15] = @"Wrong protocol used"
};

static NSString *hierrs[] = {
  [0] = @"Read only mode",
  [1] = @"Invalid authentication token",
  [2] = @"Wrong user credentials",
  [3] = @"Listener not authorized",
  [4] = @"User not authorized",
  [5] = @"Station limit reached",
  [6] = @"Station does not exist",
  [7] = @"Complimentary period already in use",
  [8] = @"Call not allowed",
  [9] = @"Device not found",
  [10] = @"Partner not authorized",
  [11] = @"Invalid username",
  [12] = @"Invalid password",
  [13] = @"Username already exists",
  [14] = @"Device already associated to account",
  [15] = @"Upgrade, device model is invalid",
  [18] = @"Explicit PIN incorrect",
  [20] = @"Explicit PIN malformed",
  [23] = @"Device model invalid",
  [24] = @"ZIP code invalid",
  [25] = @"Birth year invalid",
  [26] = @"Birth year too young",
  [27] = @"Invalid country code",
  [28] = @"Invalid gender",
  [32] = @"Cannot remove all seeds",
  [34] = @"Device disabled",
  [35] = @"Daily trial limit reached",
  [36] = @"Invalid sponsor",
  [37] = @"User already used trial"
};

#pragma mark - PandoraSearchResult

@implementation PandoraSearchResult

@end

#pragma mark - PandoraRequest

@implementation PandoraRequest

- (id) init {
  if (!(self = [super init])) { return nil; }
  self.authToken = self.partnerId = self.userId = @"";
  self.response = [[NSMutableData alloc] init];
  self.tls = self.encrypted = TRUE;
  return self;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p %@>", NSStringFromClass(self.class), self, self.method];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
  PandoraRequest *newRequest = [[PandoraRequest alloc] init];
  
  if (newRequest) {
    newRequest.method = self.method;
    newRequest.authToken = self.authToken;
    newRequest.partnerId = self.partnerId;
    newRequest.userId = self.userId;
    
    newRequest.request = self.request;
    newRequest.response = self.response;
    
    newRequest.callback = self.callback;
    newRequest.tls = self.tls;
    newRequest.encrypted = self.encrypted;
  }
  return newRequest;
}

@end

#pragma mark - Pandora

@interface Pandora ()

// Convenience methods to post notifications.
- (void)postNotification:(NSString *)notificationName;
- (void)postNotification:(NSString *)notificationName request:(id)request;
- (void)postNotification:(NSString *)notificationName result:(NSDictionary *)result;
- (void)postNotification:(NSString *)notificationName request:(id)request result:(NSDictionary *)result;

/**
 * @brief Parse the dictionary provided to create a station
 *
 * @param s the dictionary describing the station
 * @return the station object
 */
- (Station*) parseStationFromDictionary: (NSDictionary*) s;

/**
 * @brief Create the default request, with appropriate fields set based on the
 *        current state of authentication
 *
 * @param method the method name for the request to be for
 * @return the PandoraRequest object to further add callbacks to
 */
- (PandoraRequest*) defaultRequestWithMethod: (NSString*) method;

/**
 * @brief Creates a dictionary which contains the default keys necessary for
 *        most requests
 *
 * Currently fills in the "userAuthToken" and "syncTime" fields
 */
- (NSMutableDictionary*) defaultRequestDictionary;

/**
 * Gets the current UNIX time
 */
- (int64_t) time;

@end

@implementation Pandora

@synthesize stations;

- (id) init {
  if ((self = [super init])) {
    stations = [[NSMutableArray alloc] init];
    retries  = 0;
    self.device = [PandoraDevice android];
  }
  return self;
}

- (void)postNotification:(NSString *)notificationName {
  [self postNotification:notificationName request:nil result:nil];
}

- (void)postNotification:(NSString *)notificationName request:(id)request {
  [self postNotification:notificationName request:request result:nil];
}

- (void)postNotification:(NSString *)notificationName result:(NSDictionary *)result {
  [self postNotification:notificationName request:nil result:result];
}

- (void)postNotification:(NSString *)notificationName request:(id)request result:(NSDictionary *)result {
  [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                      object:request
                                                    userInfo:result];
}

#pragma mark - Error handling

+ (NSString*) stringForErrorCode: (int) code {
  if (code < 16) {
    return lowerrs[code];
  } else if (code >= 1000 && code <= 1037) {
    return hierrs[code - 1000];
  }
  return nil;
}

#pragma mark - Crypto

- (NSData *)encryptData:(NSData *)data {
  return PandoraEncryptData(data, self.device[kPandoraDeviceEncrypt]);
}

- (NSData *)decryptString:(NSString *)string {
  return PandoraDecryptString(string, self.device[kPandoraDeviceDecrypt]);
}

#pragma mark - Authentication

- (BOOL) authenticate:(NSString*)user
             password:(NSString*)pass
              request:(PandoraRequest*)req {
  return [self doUserLogin:user password:pass callback:^(NSDictionary *dict) {
    // Only send the PandoraDidAuthenticateNotification if there is no request to retry.
    if (req == nil) {
      [self postNotification:PandoraDidAuthenticateNotification];
    } else {
      NSLogd(@"Retrying request...");
      PandoraRequest *newreq = [req copy];
      
      // Update the request dictionary with new User Auth Token & Sync Time
      NSMutableDictionary *updatedRequest = [newreq.request mutableCopy];
      updatedRequest[@"userAuthToken"] = user_auth_token;
      updatedRequest[@"syncTime"] = [self syncTimeNum];
      newreq.request = updatedRequest;

      // Also update the properties on the request used to build the request URL
      newreq.userId = user_id;
      newreq.authToken = user_auth_token;
      newreq.partnerId = partner_id;

      [self sendRequest:newreq];
    }
  }];
}

- (BOOL)doUserLogin:(NSString *)username password:(NSString *)password callback:(PandoraCallback)callback {
  if (partner_id == nil) {
    // Get partner ID then reinvoke this method.
    return [self doPartnerLogin:^() {
      [self doUserLogin:username password:password callback:callback];
    }];
  }
  PandoraRequest *loginRequest = [[PandoraRequest alloc] init];
  loginRequest.request   = @{
                             @"loginType":        @"user",
                             @"username":         username,
                             @"password":         password,
                             @"partnerAuthToken": partner_auth_token,
                             @"syncTime":         [self syncTimeNum]
                             };
  loginRequest.method    = @"auth.userLogin";
  loginRequest.partnerId = partner_id;
  loginRequest.authToken = partner_auth_token;
  
  PandoraCallback loginCallback = ^(NSDictionary *respDict) {
    NSDictionary *result = respDict[@"result"];
    user_auth_token = result[@"userAuthToken"];
    user_id = result[@"userId"];
    if (self.cachedSubscriberStatus == nil) {
      // Get subscriber status then reinvoke this method
      [self checkSubscriberStatus:^(NSDictionary *respDict) {
        [self doUserLogin:username password:password callback:callback];
      }];
      return;
    } else if (self.cachedSubscriberStatus.boolValue &&
               ![self.device[kPandoraDeviceUsername] isEqualToString:@"pandora one"]) {
      // Change our device to the desktop client, logout, then reinvoke this method
      NSLogd(@"Subscriber detected, re-logging-in...");
      self.device = [PandoraDevice desktop];
      [self logoutNoNotify];
      [self doUserLogin:username password:password callback:callback];
      return;
    }
    NSLogd(@"Logged in as %@.", username);
    callback(respDict);
  };
  
  [loginRequest setCallback:loginCallback];
  return [self sendRequest:loginRequest];
}

- (BOOL) doPartnerLogin: (SyncCallback) callback {
  NSLogd(@"Getting partner ID...");
  start_time = [self time];
  
  PandoraRequest *request = [[PandoraRequest alloc] init];
  request.request   = @{
                        @"username":    self.device[kPandoraDeviceUsername],
                        @"password":    self.device[kPandoraDevicePassword],
                        @"deviceModel": self.device[kPandoraDeviceDeviceID],
                        @"version":     PANDORA_API_VERSION,
                        @"includeUrls": [NSNumber numberWithBool:TRUE]
                        };
  request.method    = @"auth.partnerLogin";
  request.encrypted = FALSE;
  request.callback  = ^(NSDictionary* dict) {
    NSDictionary *result = dict[@"result"];
    partner_auth_token = result[@"partnerAuthToken"];
    partner_id = result[@"partnerId"];
    NSData *sync = [self decryptString:result[@"syncTime"]];
    const char *bytes = [sync bytes];
    sync_time = strtoul(bytes + 4, NULL, 10);
    callback();
  };
  return [self sendRequest:request];
}

- (BOOL)checkSubscriberStatus:(PandoraCallback)callback {
  assert(user_id != nil);

  PandoraRequest *request = [self defaultRequestWithMethod:@"user.canSubscribe"];
  request.callback = ^(NSDictionary *respDict) {
    NSNumber *subscriberStatus = respDict[@"result"][@"isSubscriber"];
    if (subscriberStatus == nil) {
      NSLogd(@"Warning: no key isSubscriber, assuming non-subscriber.");
      self.cachedSubscriberStatus = [NSNumber numberWithBool:NO];
    } else {
      self.cachedSubscriberStatus = subscriberStatus;
    }
    NSLogd(@"Subscriber status: %@", self.cachedSubscriberStatus);
    callback(respDict);
  };
  request.request = [self defaultRequestDictionary];
  return [self sendRequest:request];
}

- (void) logout {
  [self logoutNoNotify];
  for (Station *s in stations)
    [Station removeStation:s];
  [stations removeAllObjects];
  [self postNotification:PandoraDidLogOutNotification];
  // Always assume non-subscriber until API says otherwise.
  self.cachedSubscriberStatus = nil;
  self.device = [PandoraDevice android];
}

- (void) logoutNoNotify {
  user_auth_token = nil;
  partner_auth_token = nil;
  partner_id = nil;
  user_id = nil;
  sync_time = start_time = 0;
}

- (BOOL) isAuthenticated {
  return user_auth_token != nil && self.cachedSubscriberStatus;
}

#pragma mark - Station Manipulation

- (BOOL) createStation: (NSString*)musicId {
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"musicToken"] = musicId;
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.createStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSDictionary *result = d[@"result"];
    Station *s = [self parseStationFromDictionary:result];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"station"] = s;
    [stations addObject:s];
    [Station addStation:s];
    [self postNotification:PandoraDidCreateStationNotification result:dict];
  }];
  return [self sendAuthenticatedRequest:req];
}

- (BOOL) removeStation: (NSString*)stationToken {
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"stationToken"] = stationToken;
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.deleteStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    unsigned int i;
    
    /* Remove the station internally */
    for (i = 0; i < [stations count]; i++) {
      if ([[stations[i] token] isEqual:stationToken]) {
        break;
      }
    }

    if ([stations count] == i) {
      NSLogd(@"Deleted unknown station?!");
    } else {
      Station *stationToRemove = stations[i];
      [Station removeStation:stationToRemove];
      [stations removeObjectAtIndex:i];
      [self postNotification:PandoraDidDeleteStationNotification request:stationToRemove];
    }
    
  }];
  return [self sendAuthenticatedRequest:req];
}

- (BOOL) renameStation: (NSString*)stationToken to:(NSString*)name {
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"stationToken"] = stationToken;
  d[@"stationName"] = name;
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.renameStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self postNotification:PandoraDidRenameStationNotification];
  }];
  return [self sendAuthenticatedRequest:req];
}

#pragma mark Fetch & parse station information from API

- (BOOL) fetchStations {
  NSLogd(@"Fetching stations...");
  
  NSMutableDictionary *d = [self defaultRequestDictionary];
  
  PandoraRequest *r = [self defaultRequestWithMethod:@"user.getStationList"];
  [r setRequest:d];
  [r setTls:FALSE];
  [r setCallback: ^(NSDictionary* dict) {
    NSDictionary *result = dict[@"result"];
    for (NSDictionary *s in result[@"stations"]) {
      Station *station = [self parseStationFromDictionary:s];
      if (![stations containsObject:station]) {
        [stations addObject:station];
        [Station addStation:station];
      }
    };
    
    [self postNotification:PandoraDidLoadStationsNotification];
  }];
  
  return [self sendAuthenticatedRequest:r];
}

- (Station*) parseStationFromDictionary: (NSDictionary*) s {
  Station *station = [[Station alloc] init];
  
  [station setName:           s[@"stationName"]];
  [station setStationId:      s[@"stationId"]];
  [station setToken:          s[@"stationToken"]];
  [station setShared:        [s[@"isShared"] boolValue]];
  [station setAllowAddMusic: [s[@"allowAddMusic"] boolValue]];
  [station setAllowRename:   [s[@"allowRename"] boolValue]];
  [station setCreated:       [s[@"dateCreated"][@"time"] unsignedLongLongValue]];
  [station setRadio:self];
  
  if ([s[@"isQuickMix"] boolValue]) {
    station.name = @"\U0001F500 Shuffle";
    station.isQuickMix = YES;
  }
  return station;
}

// FIXME: Should post a standard notification, not per-invocation choice.
- (BOOL) fetchPlaylistForStation: (Station*) station {
  NSLogd(@"Getting fragment for %@...", [station name]);
  
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"stationToken"] = station.token;
  d[@"additionalAudioUrl"] = @"HTTP_32_AACPLUS_ADTS,HTTP_64_AACPLUS_ADTS,HTTP_128_MP3";
  
  PandoraRequest *r = [self defaultRequestWithMethod:@"station.getPlaylist"];
  r.request = d;
  r.callback = ^(NSDictionary* dict) {
    NSDictionary *result = dict[@"result"];
    NSMutableArray *songs = [NSMutableArray array];
    
    for (NSDictionary *s in result[@"items"]) {
      if (s[@"adToken"] != nil) continue; // Skip if this is an adToken
      
      Song *song = [[Song alloc] init];
      
      song.artist = s[@"artistName"];
      song.title = s[@"songName"];
      song.album = s[@"albumName"];
      song.art = s[@"albumArtUrl"];
      song.stationId = s[@"stationId"];
      song.token = s[@"trackToken"];
      song.nrating = s[@"songRating"];
      song.albumUrl = s[@"albumDetailUrl"];
      song.artistUrl = s[@"artistDetailUrl"];
      song.titleUrl = s[@"songDetailUrl"];

      id urls = s[@"additionalAudioUrl"];
      if ([urls isKindOfClass:[NSArray class]]) {
        NSArray *urlArray = urls;
        if (urlArray.count < 3) {
          NSLog(@"Fewer than 3 (expected) items for additionalAudioUrl: %@", urlArray);
        }
        switch (urlArray.count) {
          case 3: song.highUrl = urlArray[2];
          case 2: song.medUrl = urlArray[1];
          case 1: song.lowUrl = urlArray[0];
            break;
          default:
            NSLog(@"Unexpected number of items (not 1-3) for additionalAudioUrl: %@", urlArray);
        }
      } else {
        NSLog(@"Unexpected format for additionalAudioUrl: %@", urls);
      }

      id audioUrlMap = s[@"audioUrlMap"];
      if ([audioUrlMap isKindOfClass:[NSDictionary class]]) {
        id qualityMap = audioUrlMap[@"highQuality"];
        if ([qualityMap isKindOfClass:[NSDictionary class]]) {
          NSLogd(@"High quality audio from audioUrlMap is %@ Kbps %@", qualityMap[@"bitrate"], qualityMap[@"encoding"]);
          if (!song.highUrl || [qualityMap[@"bitrate"] integerValue] > 128)
            song.highUrl = qualityMap[@"audioUrl"]; // 192 Kbps MP3 with Pandora One; 64 Kbps AAC+ without
        }
        qualityMap = audioUrlMap[@"mediumQuality"];
        if ([qualityMap isKindOfClass:[NSDictionary class]]) {
          NSLogd(@"Medium quality audio from audioUrlMap is %@ Kbps %@", qualityMap[@"bitrate"], qualityMap[@"encoding"]);
          if (!song.medUrl || [qualityMap[@"bitrate"] integerValue] > 64)
            song.medUrl = qualityMap[@"audioUrl"]; // 64 Kbps AAC+
        }
        qualityMap = audioUrlMap[@"lowQuality"];
        if ([qualityMap isKindOfClass:[NSDictionary class]]) {
          NSLogd(@"Low quality audio from audioUrlMap is %@ Kbps %@", qualityMap[@"bitrate"], qualityMap[@"encoding"]);
          if (!song.lowUrl || [qualityMap[@"bitrate"] integerValue] > 32)
            song.lowUrl = qualityMap[@"audioUrl"]; // 32 Kbps AAC+ (not provided with Pandora One)
        }
      }

      if (!song.medUrl) song.medUrl = song.lowUrl;
      if (!song.highUrl) song.highUrl = song.medUrl;

      [songs addObject: song];
    };
    
    NSString *name = [NSString stringWithFormat:@"hermes.fragment-fetched.%@",
                      station.token];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"songs"] = songs;
    [self postNotification:name result:d];
  };
  
  return [self sendAuthenticatedRequest:r];
}

- (BOOL) fetchGenreStations {
  NSMutableDictionary *d = [self defaultRequestDictionary];
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.getGenreStations"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self postNotification:PandoraDidLoadGenreStationsNotification result:d[@"result"]];
  }];
  return [self sendAuthenticatedRequest:req];
}

- (BOOL) fetchStationInfo:(Station *)station {
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"stationToken"] = [station token];
  d[@"includeExtendedAttributes"] = [NSNumber numberWithBool:TRUE];
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.getStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    NSDictionary *result = d[@"result"];
    
    /* General metadata */
    info[@"name"] = result[@"stationName"];
    NSDictionary *dateCreated = result[@"dateCreated"];
    NSDateComponents *created = [[NSDateComponents alloc] init];
    created.year = 2000 + [dateCreated[@"year"] integerValue];
    created.month = 1 + [dateCreated[@"month"] integerValue];
    created.day = [dateCreated[@"date"] integerValue];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    info[@"created"] = [gregorian dateFromComponents:created];
    NSString *art = result[@"artUrl"];
    if (art != nil) { info[@"art"] = art; }
    info[@"genres"] = result[@"genre"];
    info[@"url"] = result[@"stationDetailUrl"];
    
    /* Seeds - note that mutability is assumed by StationController */
    NSMutableDictionary *seeds = [NSMutableDictionary dictionary];
    NSDictionary *music = result[@"music"];
    for (NSString *kind in @[@"songs", @"artists"]) {
      NSArray *seedsOfKind = music[kind];
      if ([seedsOfKind count] > 0)
        seeds[kind] = [seedsOfKind mutableCopy];
    }
    info[@"seeds"] = seeds;
    
    /* Feedback */
    NSDictionary *feedback = result[@"feedback"];
    info[@"likes"] = feedback[@"thumbsUp"];
    info[@"dislikes"] = feedback[@"thumbsDown"];
    
    [self postNotification:PandoraDidLoadStationInfoNotification result:info];
  }];
  return [self sendAuthenticatedRequest:req];
}

#pragma mark Seed & Feedback Management (see also Song Manipulation)

- (BOOL) deleteFeedback: (NSString*)feedbackId {
  NSLogd(@"deleting feedback: '%@'", feedbackId);
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"feedbackId"] = feedbackId;
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.deleteFeedback"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self postNotification:PandoraDidDeleteFeedbackNotification request:feedbackId];
  }];
  return [self sendAuthenticatedRequest:req];
}

- (BOOL) addSeed: (NSString*)token toStation:(Station*)station {
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"musicToken"] = token;
  d[@"stationToken"] = [station token];
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.addMusic"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self postNotification:PandoraDidAddSeedNotification result:d[@"result"]];
  }];
  return [self sendAuthenticatedRequest:req];
}

- (BOOL) removeSeed: (NSString*)seedId {
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"seedId"] = seedId;
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.deleteMusic"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    [self postNotification:PandoraDidDeleteSeedNotification];
  }];
  return [self sendAuthenticatedRequest:req];
}

#pragma mark Sort stations in UI

- (void) sortStations:(int)sort {
  [stations sortUsingComparator:
   ^NSComparisonResult (Station *s1, Station *s2) {
     // keep Shuffle/QuickMix at the top of the list
     if ([s1 isQuickMix]) return NSOrderedAscending;
     if ([s2 isQuickMix]) return NSOrderedDescending;

     NSInteger factor = (sort == SORT_NAME_DSC || sort == SORT_DATE_DSC) ? -1 : 1;
     if (sort == SORT_NAME_ASC || sort == SORT_NAME_DSC)
       return factor * [[s1 name] caseInsensitiveCompare:[s2 name]];
     
     if ([s1 created] < [s2 created]) {
       return factor * NSOrderedAscending;
     } else if ([s1 created] > [s2 created]) {
       return factor * NSOrderedDescending;
     }
     return NSOrderedSame;
   }];
}

#pragma mark - Song Manipulation

- (BOOL) rateSong:(Song*) song as:(BOOL) liked {
  NSLogd(@"Rating song '%@' as %d...", [song title], liked);
  
  if (liked == TRUE) {
    [song setNrating:@1];
  } else {
    [song setNrating:@-1];
  }
  
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"trackToken"] = [song token];
  d[@"isPositive"] = @(liked);
  d[@"stationToken"] = [[song station] token];
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.addFeedback"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* _) {
    [self postNotification:PandoraDidRateSongNotification request:song];
  }];
  return [self sendAuthenticatedRequest:req];
}

- (BOOL) deleteRating:(Song*)song {
  NSLogd(@"Removing rating on '%@'", [song title]);
  [song setNrating:@0];
  
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"stationToken"] = [[song station] token];
  d[@"includeExtendedAttributes"] = [NSNumber numberWithBool:TRUE];
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"station.getStation"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    for (NSString *thumb in @[@"thumbsUp", @"thumbsDown"]) {
      for (NSDictionary* feed in d[@"result"][@"feedback"][thumb]) {
        if ([feed[@"songName"] isEqualToString:[song title]]) {
          [self deleteFeedback:feed[@"feedbackId"]];
          break;
        }
      }
    }
  }];
  return [self sendAuthenticatedRequest:req];
}

- (BOOL) tiredOfSong: (Song*) song {
  NSLogd(@"Getting tired of %@...", [song title]);
  
  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"trackToken"] = [song token];
  
  PandoraRequest *req = [self defaultRequestWithMethod:@"user.sleepSong"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* _) {
    [self postNotification:PandoraDidTireSongNotification request:song];
  }];
  
  return [self sendAuthenticatedRequest:req];
}

#pragma mark - syncTime

- (NSNumber*) syncTimeNum {
  return [NSNumber numberWithLongLong: sync_time + ([self time] - start_time)];
}

- (int64_t) time {
  return [[NSDate date] timeIntervalSince1970];
}

#pragma mark - Search for music

- (BOOL) search: (NSString*) search {
  NSLogd(@"Searching for %@...", search);

  search = [search stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([search length] == 0) {
    [self postNotification:PandoraDidLoadSearchResultsNotification request:search result:@{}];
    return YES;
  }

  NSMutableDictionary *d = [self defaultRequestDictionary];
  d[@"searchText"] = search;

  PandoraRequest *req = [self defaultRequestWithMethod:@"music.search"];
  [req setRequest:d];
  [req setTls:FALSE];
  [req setCallback:^(NSDictionary* d) {
    NSDictionary *result = d[@"result"];
    NSLogd(@"%@", result);

    NSMutableArray *search_songs, *search_artists;
    search_songs    = [NSMutableArray array];
    search_artists  = [NSMutableArray array];

    for (NSDictionary *s in result[@"songs"]) {
      PandoraSearchResult *r = [[PandoraSearchResult alloc] init];
      NSString *name = [NSString stringWithFormat:@"%@ - %@",
                          s[@"songName"],
                          s[@"artistName"]];
      [r setName:name];
      [r setValue:s[@"musicToken"]];
      [search_songs addObject:r];
    }

    for (NSDictionary *a in result[@"artists"]) {
      PandoraSearchResult *r = [[PandoraSearchResult alloc] init];
      [r setValue:a[@"musicToken"]];
      [r setName:a[@"artistName"]];
      [search_artists addObject:r];
    }

    NSDictionary *searchResults = @{@"Songs": search_songs,
                                    @"Artists": search_artists};

    [self postNotification:PandoraDidLoadSearchResultsNotification request:search result:searchResults];
  }];

  return [self sendAuthenticatedRequest:req];
}

#pragma mark - Prepare and Send Requests

- (NSMutableDictionary*) defaultRequestDictionary {
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  if (user_auth_token != nil) {
    d[@"userAuthToken"] = user_auth_token;
  }
  d[@"syncTime"] = [self syncTimeNum];
  return d;
}

- (PandoraRequest*) defaultRequestWithMethod: (NSString*) method {
  PandoraRequest *req = [[PandoraRequest alloc] init];
  [req setUserId:user_id];
  [req setAuthToken:user_auth_token];
  [req setMethod:method];
  [req setPartnerId:partner_id];
  return req;
}

- (BOOL) sendAuthenticatedRequest: (PandoraRequest*) req {
  if ([self isAuthenticated]) {
    return [self sendRequest:req];
  }
  NSString *user = [[NSApp delegate] getSavedUsername];
  NSString *pass = [[NSApp delegate] getSavedPassword];
  return [self authenticate:user password:pass request:req];
}


- (BOOL) sendRequest: (PandoraRequest*) request {
  NSString *url  = [NSString stringWithFormat:
                    @"http%s://%@" PANDORA_API_PATH
                    @"?method=%@&partner_id=%@&auth_token=%@&user_id=%@",
                    [request tls] ? "s" : "",
                    self.device[kPandoraDeviceAPIHost],
                    [request method],
                    [request partnerId],
                    [[request authToken] urlEncoded],
                    [request userId]];
  NSLogd(@"%@", url);
  
  /* Prepare the request */
  NSURL *nsurl = [NSURL URLWithString:url];
  NSMutableURLRequest *nsrequest = [NSMutableURLRequest requestWithURL:nsurl];
  [nsrequest setHTTPMethod: @"POST"];
  [nsrequest addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  
  /* Create the body */
  NSData *data = [NSJSONSerialization dataWithJSONObject:request.request options:nil error:nil];
  if ([request encrypted]) { data = [self encryptData:data]; }
  [nsrequest setHTTPBody: data];
  
  /* Create the connection with necessary callback for when done */
  URLConnection *c =
  [URLConnection connectionForRequest:nsrequest
                    completionHandler:^(NSData *d, NSError *e) {
                      /* Parse the JSON if we don't have an error */
                      NSDictionary *dict = nil;
                      if (e == nil) {
                        dict = [NSJSONSerialization JSONObjectWithData:d options:nil error:&e];
                      }
                      /* If we still don't have an error, look at the JSON for an error */
                      NSString *err = e == nil ? nil : [e localizedDescription];
                      if (dict != nil && err == nil) {
                        NSString *stat = dict[@"stat"];
                        if ([stat isEqualToString:@"fail"]) {
                          err = dict[@"message"];
                        }
                      }
                      
                      /* If we don't have an error, then all we need to do is invoked the
                       specified callback, otherwise build the error dictionary. */
                      if (err == nil) {
                        assert(dict != nil);
                        [request callback](dict);
                        return;
                      }
                      
                      NSMutableDictionary *info = [NSMutableDictionary dictionary];
                      
                      [info setValue:request forKey:@"request"];
                      [info setValue:err     forKey:@"error"];
                      if (dict != nil) {
                        [info setValue:dict[@"code"] forKey:@"code"];
                      }
                      [[NSNotificationCenter defaultCenter] postNotificationName:PandoraDidErrorNotification
                                                                          object:self
                                                                        userInfo:info];
                    }];
  [c start];
  return TRUE;
}

@end

