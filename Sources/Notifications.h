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

extern NSString * const PandoraDidErrorNotification;
extern NSString * const PandoraDidAuthenticateNotification;
extern NSString * const PandoraDidLogOutNotification;
extern NSString * const PandoraDidRateSongNotification;
extern NSString * const PandoraDidTireSongNotification;
extern NSString * const PandoraDidLoadStationsNotification;
extern NSString * const PandoraDidCreateStationNotification;
extern NSString * const PandoraDidDeleteStationNotification;
extern NSString * const PandoraDidRenameStationNotification;
extern NSString * const PandoraDidLoadStationInfoNotification;
extern NSString * const PandoraDidAddSeedNotification;
extern NSString * const PandoraDidDeleteSeedNotification;
extern NSString * const PandoraDidDeleteFeedbackNotification;
extern NSString * const PandoraDidLoadSearchResultsNotification;
extern NSString * const PandoraDidLoadGenreStationsNotification;

extern NSString * const StationDidPlaySongNotification;

#endif
