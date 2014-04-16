//
//  Notifications.m
//  Hermes
//
//  Created by Winston Weinert on 4/15/14.
//
//

#import "Notifications.h"

#pragma mark - Distributed Notifications

NSString * const HistoryControllerDidPlaySongDistributedNotification = @"hermes.song";

NSString * const AppleScreensaverDidStartDistributedNotification     = @"com.apple.screensaver.didstart";
NSString * const AppleScreensaverDidStopDistributedNotification      = @"com.apple.screensaver.didstop";
NSString * const AppleScreenIsLockedDistributedNotification          = @"com.apple.screenIsLocked";
NSString * const AppleScreenIsUnlockedDistributedNotification        = @"com.apple.screenIsUnlocked";

#pragma mark - Internal Notifications

NSString * const PandoraDidErrorNotification                         = @"PandoraDidErrorNotification";
NSString * const PandoraDidAuthenticateNotification                  = @"PandoraDidAuthenticateNotification";
NSString * const PandoraDidLogOutNotification                        = @"PandoraDidLogOutNotification";
NSString * const PandoraDidRateSongNotification                      = @"PandoraDidRateSongNotification";
NSString * const PandoraDidTireSongNotification                      = @"PandoraDidTireSongNotification";
NSString * const PandoraDidLoadStationsNotification                  = @"PandoraDidLoadStationsNotification";
NSString * const PandoraDidCreateStationNotification                 = @"PandoraDidCreateStationNotification";
NSString * const PandoraDidRemoveStationNotification                 = @"PandoraDidRemoveStationNotification";
NSString * const PandoraDidRenameStationNotification                 = @"PandoraDidRenameStationNotification";
NSString * const PandoraDidLoadStationInfoNotification               = @"PandoraDidLoadStationInfoNotification";
NSString * const PandoraDidAddSeedNotification                       = @"PandoraDidAddSeedNotification";
NSString * const PandoraDidRemoveSeedNotification                    = @"PandoraDidRemoveSeedNotification";
NSString * const PandoraDidDeleteFeedbackNotification                = @"PandoraDidDeleteFeedbackNotification";
NSString * const PandoraDidLoadSearchResultsNotification             = @"PandoraDidLoadSearchResultsNotification";
NSString * const PandoraDidLoadGenreStationsNotification             = @"PandoraDidLoadGenreStationsNotification";

NSString * const StationDidPlaySongNotification                      = @"StationDidPlaySongNotification";
