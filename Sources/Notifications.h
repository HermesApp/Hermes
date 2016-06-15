//
//  Notifications.h
//  Hermes
//
//  Created by Winston Weinert on 4/15/14.
//
//

#ifndef Hermes_Notifications_h
#define Hermes_Notifications_h

#pragma mark Distributed Notifications

extern NSString * const HistoryControllerDidPlaySongDistributedNotification;

extern NSString * const AppleScreensaverDidStartDistributedNotification;
extern NSString * const AppleScreensaverDidStopDistributedNotification;
extern NSString * const AppleScreenIsLockedDistributedNotification;
extern NSString * const AppleScreenIsUnlockedDistributedNotification;

#pragma mark Internal Notifications

extern NSString * const PandoraDidErrorNotification; // userInfo: error
extern NSString * const PandoraDidAuthenticateNotification;
extern NSString * const PandoraDidLogOutNotification;
extern NSString * const PandoraDidRateSongNotification; // object: song
extern NSString * const PandoraDidTireSongNotification; // object: song
extern NSString * const PandoraDidLoadStationsNotification;
extern NSString * const PandoraDidCreateStationNotification; // userInfo: result
extern NSString * const PandoraDidDeleteStationNotification; // object: Station
extern NSString * const PandoraDidRenameStationNotification;
extern NSString * const PandoraDidLoadStationInfoNotification; // userInfo: info
extern NSString * const PandoraDidAddSeedNotification; // userInfo: result
extern NSString * const PandoraDidDeleteSeedNotification;
extern NSString * const PandoraDidDeleteFeedbackNotification; // object: feedbackId string
extern NSString * const PandoraDidLoadSearchResultsNotification; // object: search string; userInfo: result
extern NSString * const PandoraDidLoadGenreStationsNotification; // userInfo: result

extern NSString * const StationDidPlaySongNotification;

#endif
