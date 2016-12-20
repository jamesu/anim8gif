//
//  webplayAppDelegate.h
//  webplay
//
//  Created by James Urquhart on 15/02/2009.
//
// (C) James S Urquhart 2009 - 2016
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "OldCompat.h"

// Logging for debug builds only.

//#define DEBUG
//#define DB_TESTING

#ifdef __OBJC__

#ifdef DEBUG
#define L0Log(x, ...) NSLog(@"<DEBUG: %s>: " x, __func__, ## __VA_ARGS__)
#define L0LogIf(cond, x, ...) do { if (cond) NSLog(x, ## __VA_ARGS__); } while (0)
#else
#define L0Log(x, ...)
#define L0LogIf(cond, x, ...)
#endif // def DEBUG

#endif // def __OBJC__

#include "DebugSupport.h"

#import "AnimPlayerViewController.h"
#import "InstructionsViewController.h"
#import "PlaylistViewController.h"
#import "CDAnimInfo.h"
#import "DataLoader.h"
#import "PlaylistItem.h"

extern BOOL kDidInitBeacon;
@class PlaylistItem;

@interface webplayAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    
    AnimPlayerViewController *animController;
    
    IBOutlet UISearchBar *searchBar;
    IBOutlet InstructionsViewController *instructions;
    IBOutlet UINavigationController *navigation;
    
    PlaylistViewController *activePlaylistView;
    
    NSMutableArray *playlist;
    
    PlaylistItem *current_item;
    NSMutableArray *recent_playlist;
    int recent_playlist_capacity;
    
    UIActionSheet *currentSheet;
    
    bool migratingData;
    bool startedGIF;
    NSURL *currentURL;
    
    bool allowStorage;
    bool showingBookmarks;
    
    DataLoader *_loader;
    void *currentCache;
    
    CGSize orientFrame;
    
    NSUserDefaults *config;
    
    NSThread *backgroundTask;
   
    NSArray *_syncList;
    NSArray *_syncDeleteList;
    unsigned int _syncListIdx;
    unsigned int _syncDeleteListIdx;
   
@private
    NSManagedObjectContext *managedObjectContext_;
    NSManagedObjectModel *managedObjectModel_;
    NSPersistentStoreCoordinator *persistentStoreCoordinator_;
}


@property (nonatomic, retain) NSThread *backgroundTask;
@property (nonatomic, retain) NSUserDefaults *config;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigation;
@property (nonatomic, retain) IBOutlet AnimPlayerViewController *animController;
@property (nonatomic, retain) UIActionSheet *currentSheet;
@property (nonatomic, retain) PlaylistViewController *activePlaylistView;

@property (nonatomic, assign) CGSize orientFrame;

@property (retain) NSURL* currentURL;
@property (nonatomic, assign) bool startedGIF;

@property (retain) NSMutableArray *playlist;
@property (retain) NSMutableArray *recent_playlist;
@property (retain) PlaylistItem *current_item;

@property(nonatomic, assign) UISearchBar *searchBar;
@property(nonatomic, retain) InstructionsViewController *instructions;

@property (nonatomic, readonly) DataLoader *loader;

- (NSData*)dataForVideoWithType:(NSString**)typeName;
- (bool)isVideoLoaded;

- (void)fixFrameScreen:(CGRect*)screenRect withStatus:(CGRect*)statusRect;

- (void)transitionInAnimControllerAnimated:(bool)anim;
- (void)transitionOutAnimControllerAnimated:(bool)anim;

- (void)grabAnimsFromBookmarks;
- (void)grabAnimsFromURL;
- (void)playItem:(PlaylistItem*)item;
- (void)playFromSettings;
- (void)recordRecentInfo;
- (void)deleteInfo:(CDAnimInfo*)info;
- (void)restoreMigrationThread;
- (void)finishedMigrationThread;

- (void)animLoadedWithSuccess:(BOOL)success;

- (void)loadSearch;
- (void)loadRecentPlaylist;
- (void)reloadSearch;
- (void)cancelConnection;


- (NSString *)applicationDocumentsDirectory;
- (NSString *)applicationBundleDirectory;
- (NSString *)cacheFilename;

- (void)saveContext;
- (NSArray*)fetchRecordsWithOffset:(int)theOffset andLimit:(int)theLimit didBookmark:(NSNumber*)bookmarked didSync:(NSNumber*)synced ordered:(int)ordered;

- (void)showPlaylist:(bool)asBookmarks withRoot:(PlaylistItem*)root;

- (void)showPro;

@end
