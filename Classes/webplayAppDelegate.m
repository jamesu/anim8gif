//
//  webplayAppDelegate.m
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

#import "webplayAppDelegate.h"
#import "RegexKitLite.h"
#import "AnimInfo.h"
#import "CDAnimInfo.h"
#import "VideoSource.h"
#import "Video.h"
#import "GifVideo.h"
#import "PngVideo.h"
#import "ProcessPromptController.h"

#import "PlugProController.h"
#import <MobileCoreServices/MobileCoreServices.h>


@implementation webplayAppDelegate

@synthesize window;
@dynamic managedObjectContext;
@dynamic managedObjectModel;
@dynamic persistentStoreCoordinator;

@synthesize navigation;
@synthesize instructions;
@synthesize searchBar;
@synthesize animController;

@synthesize currentSheet;

@synthesize startedGIF;
@synthesize currentURL;

@synthesize orientFrame;

@synthesize playlist;
@synthesize recent_playlist;
@synthesize current_item;
@synthesize config;
@synthesize backgroundTask;
@synthesize activePlaylistView;

@synthesize loader = _loader;

static bool launchURL = NO;

// Bookmark migration

- (BOOL)hasOldBookmarks
{
    if ([config boolForKey:@"didCheckOldDB"])
        return false;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[self applicationDocumentsDirectory] stringByAppendingString:@"/anim8gif.sqlite3"]]) {
        return true;
    }
    return false;
}

- (void)finishedMigrationThread
{
    L0Log(@"finishedMigrationThread, nav == %@", navigation);
    
#ifndef DB_TESTING
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *docsDir = [self applicationDocumentsDirectory];
    [files moveItemAtPath:[docsDir stringByAppendingString:@"/anim8gif.sqlite3"]
                   toPath:[docsDir stringByAppendingString:@"/old-anim8gif.sqlite3"] error:nil];
    [files removeItemAtPath:[docsDir stringByAppendingString:@"/stored"] error:nil];
#endif
    [self.config setBool:YES forKey:@"didCheckOldDB"];
    
    
    [navigation popViewControllerAnimated:NO];
    [instructions viewWillAppear:NO];
    [instructions.view layoutSubviews];
    //[navigation.view removeFromSuperview];
    if (backgroundTask)
        self.backgroundTask = nil;
    [self performSelectorOnMainThread:@selector(postLaunch:) withObject:nil waitUntilDone:NO];
}

- (void)postMigrateBookmarksLaunch:(UIApplication*)application {
    // Pro prompt
    ProcessPromptController *pro;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        pro = [[ProcessPromptController alloc] initWithNibName:@"ProcessPrompt-iPad" bundle:nil];
    else
        pro = [[ProcessPromptController alloc] initWithNibName:@"ProcessPrompt" bundle:nil];
    [navigation pushViewController:pro animated:NO];
    
    // Thread...!
    [self restoreMigrationThread];
    [pro release];
}

- (void)taskConvertOldBookmarks
{
    NSString *docsDir = [self applicationDocumentsDirectory];
    NSString *path = [docsDir stringByAppendingString:@"/anim8gif.sqlite3"];
    
    [AnimInfo convertOldBookmarksFromLocation:path withDelegate:self];
    
    L0Log(@"convertOldBookmarks ended");
}

static NSTimeInterval sStartSyncTime=0;

- (void)startSyncBookmarks
{
   sStartSyncTime = [NSDate timeIntervalSinceReferenceDate];
   
   // Look through files, find ones which aren't indexed
   NSString *docsDir = [self applicationDocumentsDirectory];
   NSFileManager *manager = [NSFileManager defaultManager];
   
   _syncList = [manager contentsOfDirectoryAtPath:docsDir error:nil];
   _syncListIdx = 0;
   _syncDeleteListIdx = 0;
   
   if (_syncList) {
      [_syncList retain];
   }
   
   _syncDeleteList = [self fetchRecordsWithOffset:0 andLimit:-1 didBookmark:[NSNumber numberWithBool:YES] didSync:[NSNumber numberWithBool:YES] ordered:0];
   if (_syncDeleteList) {
      [_syncDeleteList retain];
   }
   
   [self syncNextBookmark];
}


- (void)syncNextBookmark
{
   if (_syncList == nil && _syncDeleteList == nil)
      return;
   
   if (_syncListIdx >= [_syncList count]) {
      [_syncList release];
      _syncList = nil;
   }
   
   if (_syncDeleteListIdx >= [_syncDeleteList count]) {
      [_syncDeleteList release];
      _syncDeleteList = nil;
      
   }
   
   
   if (_syncList == nil && _syncDeleteList == nil)
   {
      L0Log(@"Scanned %i files, deleted %i files in %f\n", _syncListIdx, _syncDeleteListIdx, [NSDate timeIntervalSinceReferenceDate] - sStartSyncTime);
      
      [self saveContext];
   }
   
   if (_syncList != nil)
   {
      
      NSString *path = [_syncList objectAtIndex:_syncListIdx++];
      NSEntityDescription *entity = [[self.managedObjectModel entitiesByName] objectForKey:@"AnimInfo"];
      
      NSString *ext = [[path componentsSeparatedByString:@"."] lastObject];
      if ([ext isEqualToString:@"gif"] || [ext isEqualToString:@"png"]) {
         NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
         [request setEntity:[NSEntityDescription
                             entityForName:@"AnimInfo" inManagedObjectContext:self.managedObjectContext]];
         
         NSPredicate *predicate = [NSPredicate predicateWithFormat:
                                   @"(storedID LIKE %@)", path];
         [request setPredicate:predicate];
         
         NSArray *results = [self.managedObjectContext executeFetchRequest:request error:nil];
         if ([results count] == 0 ) {
            L0Log(@"SCAN: Couldn't find file: %@ in index. Must be new...\n", path);
            
            
            CDAnimInfo *info = (CDAnimInfo*)[[NSManagedObject alloc] initWithEntity:entity
                                                     insertIntoManagedObjectContext:self.managedObjectContext];
            
            [info ensureClean];
            info.url = [[NSURL fileURLWithPath:path isDirectory:NO] absoluteString];
            info.storedID = path;
            info.dontShow = [NSNumber numberWithBool:NO];
            info.isLink = [NSNumber numberWithBool:NO];
            info.didBookmark = [NSNumber numberWithBool:YES];
            info.didSync = [NSNumber numberWithBool:YES];
            [info release];

         } else {
             L0Log(@"SCAN: Found: %@ in index.\n", path);
         }
         
      }
   }
   
   if (_syncDeleteList != nil)
   {
      CDAnimInfo *info = [_syncDeleteList objectAtIndex:_syncDeleteListIdx++];
      
      NSURL *host = info.parsedURL;
      
      if (info.storedFile == nil) {
         if (info.storedID)
            [info ensureErased];
         
         [self.managedObjectContext deleteObject:info];
      }
   }
   
   
   
   
   [self performSelector:@selector(syncNextBookmark) withObject:nil afterDelay:0];
}

- (void)restoreMigrationThread
{
    L0Log(@"restoreMigrationThread");
    // Thread...!
    migratingData = YES;
    
    NSThread *thread = [[[NSThread alloc] initWithTarget:self selector:@selector(taskConvertOldBookmarks) object:nil] autorelease];
    [thread start];
    self.backgroundTask = thread;
}

// Launch code

- (void)postLaunch:(UIApplication*)application {
    L0Log(@"postLaunch %i", launchURL);
    [CDAnimInfo ensureThumbDirectory];
    [self startSyncBookmarks];
    
    if (!launchURL) {
        currentURL = nil;
        _loader = nil;
        
        [self playFromSettings];
        
        if (!current_item) {
            // Display instructions
            [self reloadSearch];
        }
    }
}

- (void)loadSearch
{
    searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    searchBar.placeholder = NSLocalizedString(@"ent_u", @"ENTER URL HERE");
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sbar
{
    NSString *urlStr = sbar.text;
    NSURL *build;
    
    if ([urlStr isMatchedByRegex:@"^[a-zA-Z]*://"])
        build = [NSURL URLWithString:sbar.text];
    else
        build = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", sbar.text]];
    
    //sbar.text = nil;
    self.currentURL = build;
    [self grabAnimsFromURL];
}

- (void)searchBarBookmarkButtonClicked:(UISearchBar*)sbar
{
    [self grabAnimsFromBookmarks];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.config = [NSUserDefaults standardUserDefaults];
#ifndef DB_TESTING
    
    allowStorage = true;
    migratingData = false;
    
    playlist = nil;
    recent_playlist = nil;
    current_item = nil;
    orientFrame = [UIScreen mainScreen].bounds.size;
    activePlaylistView = nil;
    
    //[window addSubview:animController.view];
   
    window.rootViewController = animController;
   
   //window.backgroundColor = [UIColor redColor];
   //animController.view.backgroundColor = [UIColor blueColor];
   
    [self loadSearch];
    
    instructions.nav = navigation;
    [animController presentViewController:navigation animated:NO completion:nil];
    instructions.navigationItem.title = NSLocalizedString(@"search", @"Search");
    
    [window makeKeyAndVisible];
    currentCache = NULL;
    
    if ([self hasOldBookmarks]) {
        [self performSelector:@selector(postMigrateBookmarksLaunch:) withObject:application afterDelay:0.0];
    } else {
        [self performSelector:@selector(postLaunch:) withObject:application afterDelay:0.0];
    }
#endif
    
    return true;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
    //[DebugSupport waitForDebugger];
    
    if ([[url scheme] isEqualToString:@"animgif"]) {
        self.currentURL = nil;
        launchURL = YES;
        
        NSString *query = [url query];
        NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
        NSArray *queryPairs = [query componentsSeparatedByString:@"&"];
        NSString *queryPair;
        
        for (queryPair in queryPairs)
        {
            NSArray *kv = [queryPair componentsSeparatedByString:@"="];
            if ([kv count] > 1)
                [queryDict setObject:[[kv objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:[kv objectAtIndex:0]];
        }
        
        // current URL
        NSString *qvalue = [queryDict objectForKey:@"url"];
        if (qvalue) {
            if ([qvalue isMatchedByRegex:@"^[a-zA-Z]*://"])
                currentURL = [NSURL URLWithString:qvalue];
            else
                currentURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", qvalue]];
            
            [currentURL retain];
        } else
            launchURL = NO;
        
        if (launchURL)
            [self grabAnimsFromURL];
        return YES;
    } else if ([url isFileURL]) {
        // Load from local file!
        self.currentURL = url;
        launchURL = YES;
        
        [self grabAnimsFromURL];
    }
    return NO;
}


- (void)fixFrameScreen:(CGRect*)screenRect withStatus:(CGRect*)statusRect {
    CGRect fixedFrame = [[UIScreen mainScreen] applicationFrame];
    *statusRect = fixedFrame;
    fixedFrame.size.height += fixedFrame.origin.y;
    fixedFrame.origin.y = 0;
    *screenRect = fixedFrame;
}


- (void)transitionInAnimControllerAnimated:(bool)anim
{
    [animController dismissViewControllerAnimated:YES completion:nil];
}

- (void)transitionOutAnimControllerAnimated:(bool)anim
{
    // Instructions not loaded? (e.g. if opened from url)
    if (instructions == nil)
        [self loadSearch];
    
    if (recent_playlist == nil)
        [self reloadSearch];
    
    if (animController.presentedViewController != navigation)
        [animController presentViewController:navigation animated:anim completion:nil];
}

- (PlaylistItem*)findInRecent:(NSURL*)url
{
    NSString* recentURL = [url absoluteString];
    for (PlaylistItem *info in recent_playlist)
    {
        NSString *str = [info.itemURL absoluteString];
        
        if ([str isEqualToString:recentURL]) {
            return info;
        }
    }
    
    return nil;
}

- (void)recordRecentInfo {
    if (current_item) {
        if (recent_playlist == nil)
            [self reloadSearch];
        
        CDAnimInfo *current_info = current_item.storedData;
        
        if (current_info == nil)
        {
            NSEntityDescription *entity = [[self.managedObjectModel entitiesByName] objectForKey:@"AnimInfo"];
            current_item.storedData = current_info = (CDAnimInfo*)[[NSManagedObject alloc] initWithEntity:entity
                                                     insertIntoManagedObjectContext:self.managedObjectContext];
        }
        
        current_info.isLink = [NSNumber numberWithBool:current_item.isLink];
        current_info.url = [current_item.itemURL absoluteString];
        if (current_item.previewImage)
            [current_info setThumb:current_item.previewImage];
        current_info.lastPlay = [NSDate date];
        current_info.dontShow = [NSNumber numberWithBool:NO];
        
        [current_item updateFromCoreData];
        
        // Record to database
        [self saveContext];
    }
}

- (void)deleteInfo:(CDAnimInfo*)info {
    if (info.storedID)
        [info ensureErased];
    
    [self.managedObjectContext deleteObject:info];
    [self saveContext];
}

- (void)startNetRequest:(NSURL*)url {
    if (_loader) {
        [_loader cancel];
        if (_loader) { // may be reset in onLoaderCancel
            [_loader release];
            _loader = nil;
        }
    }
    
    // Clear retained caches
    if (currentCache) {
        DynamicCache_release(currentCache);
        currentCache = NULL;
    }
    
    self.currentURL = url;
    startedGIF = NO;
    _loader = [[DataLoader initWithURL:url delegate:self] retain];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)grabAnimsFromURL {
    self.playlist = [NSMutableArray array];
    if (currentURL) {
        if (current_item)
            [current_item release];
        
        // See if its the first in the recent list...
        current_item = [self findInRecent:currentURL];
        
        // If all else fails, make a new one
        if (current_item == nil) {
            current_item = [[PlaylistItem alloc] initWithURL:currentURL isLink:true];
        } else {
            [current_item retain];
        }
        
        // Request time!
        if (![currentURL isFileURL]) {
            [self startNetRequest:currentURL];
        } else {
            // Try loading from saved file
            NSString *fname = [currentURL path];
            if (fname && [animController startVideoFromLocation:fname]) {
                [self recordRecentInfo];
                
                if (current_item.didBookmark && current_item.previewImage == nil) {
                    // Generate thumb!
                    [self postLoadThumb:current_item];
                }
                
                [self transitionInAnimControllerAnimated:YES];
                
                return;
            }            
        }
    }
}

- (void)playItem:(PlaylistItem*)item
{
    self.playlist = [NSMutableArray array];
    self.current_item = nil;
    
    // See if its the first in the recent list...
    PlaylistItem *cmp = [self findInRecent:item.itemURL];
    if (cmp && cmp != item) {
        [recent_playlist removeObject:cmp];
        if (!cmp.didBookmark) {
            [cmp deleteStorage];
        }
    }
    
    self.current_item = item;
    self.currentURL = current_item.itemURL;
    
    if (!current_item.isLink) {
        // Try loading from saved file
        NSString *fname = current_item.storedData ? current_item.storedData.storedFile : nil;
        if (fname && [animController startVideoFromLocation:fname]) {
            [self recordRecentInfo];
            [self transitionInAnimControllerAnimated:YES];
            
            if (current_item.didBookmark && current_item.previewImage == nil) {
                // Generate thumb!
                [self postLoadThumb:current_item];
            }
            
            return;
        }
    }
    
    // If all else fails, use regular URL loading
    [self startNetRequest:currentURL];
}

- (NSArray*)fetchRecordsWithOffset:(int)theOffset andLimit:(int)theLimit didBookmark:(NSNumber*)bookmarked didSync:(NSNumber*)synced ordered:(int)ordered
{
    NSManagedObjectContext *ctx = self.managedObjectContext;
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"AnimInfo" inManagedObjectContext:ctx];
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity:entityDescription];
    if (theLimit > 0)
        [request setFetchLimit:theLimit];
    [request setFetchOffset:theOffset];
    
    // Set example predicate and sort orderings...
    NSPredicate *predicate;
    NSMutableArray *conditions = [NSMutableArray array];
    
    if (synced) {
        if ([synced boolValue] == false)
        {
            [conditions addObject:[NSPredicate predicateWithFormat:@"didSync == %@ OR didSync == NULL",
                                   synced]];
        }
        else
        {
            [conditions addObject:[NSPredicate predicateWithFormat:@"didSync == %@",
                                   synced]];
        }
    }
    
    if (bookmarked) {
        if ([bookmarked boolValue] == false)
        {
            [conditions addObject:[NSPredicate predicateWithFormat:@"didBookmark == %@ OR didBookmark == NULL",
                                   bookmarked]];
        }
        else
        {
            [conditions addObject:[NSPredicate predicateWithFormat:@"didBookmark == %@",
                                   bookmarked]];
            
        }
    }
    
    if ([conditions count] == 0) {
        predicate = [NSPredicate predicateWithFormat:@"(dontShow != %@)", [NSNumber numberWithBool:YES]];
    } else {
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:conditions];
    }
    
    [request setPredicate:predicate];
    
    if (ordered == 1)
    {
        // ascending
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc]
                                            initWithKey:@"lastPlay" ascending:YES];
        [request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        [sortDescriptor release];
    }
    else if (ordered == 2)
    {
        // descending
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc]
                                            initWithKey:@"lastPlay" ascending:NO];
        [request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        [sortDescriptor release];
    }
    
    NSError *error = nil;
    NSArray *ret = [ctx executeFetchRequest:request error:&error];
    
    return ret;
}

- (void)loadRecentPlaylist
{
    self.recent_playlist = [NSMutableArray arrayWithCapacity:recent_playlist_capacity];
    recent_playlist_capacity = 25;
    
    CDAnimInfo *info;
    
    // First prune non-bookmarked, non-sync'd items
    NSArray *results = [self fetchRecordsWithOffset:0 andLimit:0 didBookmark:[NSNumber numberWithBool:NO] didSync:[NSNumber numberWithBool:NO] ordered:2];
    int count = [results count];
    if (count > recent_playlist_capacity)
    {
        // Remove any bad items
        for (int i=recent_playlist_capacity; i<count; i++)
        {
            [self.managedObjectContext deleteObject:[results objectAtIndex:i]];
        }
    }
    [self saveContext];
    
    // Grab recent playlist items
    
    // First prune non-bookmarked, non-sync'd items
    results = [self fetchRecordsWithOffset:0 andLimit:recent_playlist_capacity didBookmark:nil didSync:nil ordered:2];
    for (info in results) {
        [recent_playlist addObject:[PlaylistItem wrapAnimInfo:info]];
    }
}

- (void)reloadSearch
{
    if (recent_playlist == nil) {
        [self loadRecentPlaylist];
    }
    
    // Reload instructions in search
    [instructions viewWillAppear:YES];
}

- (void)showPlaylist:(bool)asBookmarks withRoot:(PlaylistItem*)root
{
    //[DebugSupport waitForDebugger];
    
    NSInteger lastIDX = 0;
    PlaylistViewController *last_pl = (PlaylistViewController*)navigation.visibleViewController;
    
    if ([last_pl isMemberOfClass:[PlaylistViewController class]])
        lastIDX = last_pl.pushIDX;
    
    PlaylistViewController *pl;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        pl = [[PlaylistViewController alloc] initWithNibName:@"PlaylistView-iPad" bundle:nil];
    else
        pl = [[PlaylistViewController alloc] initWithNibName:@"PlaylistView" bundle:nil];
    
    pl.nav = navigation;
    pl.rootInfo = root;
    pl.showBookmarks = asBookmarks;
    pl.showToolbar = YES;
    pl.pushIDX = lastIDX+1;
    
    [navigation pushViewController:pl animated:YES];
    
    if (root && !asBookmarks)
        pl.navigationItem.title = root.title;
    
    [pl release];
}

- (void)grabAnimsFromBookmarks
{
    self.playlist = [self getBookmarks];
    self.currentURL = nil;
    
    // Show playlist
    [self showPlaylist:YES withRoot:current_item];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AnimListLoaded" object:nil userInfo:nil];
    self.playlist = nil;
}

- (NSMutableArray*)getBookmarks
{
    NSArray *results = [self fetchRecordsWithOffset:0 andLimit:-1 didBookmark:[NSNumber numberWithBool:YES] didSync:nil ordered:0];
    NSMutableArray *outList = [NSMutableArray arrayWithCapacity:[results count]];
    for (CDAnimInfo *info in results) {
        [outList addObject:[PlaylistItem wrapAnimInfo:info]];
    }
    return outList;
}


- (void)findURLUsingRegexp:(NSString*)regexp inString:(NSString*)search exclusionList:(NSMutableDictionary*)exclusionList gifList:(NSMutableArray*)gifList pngList:(NSMutableArray*)pngList linkList:(NSMutableArray*)linkList
{
    int cur = 0;
    int len = [search length];
    int end = len;
    NSRange foundRange;
    NSMutableArray *found = [NSMutableArray array];
    NSEntityDescription *entity = [[self.managedObjectModel entitiesByName] objectForKey:@"AnimInfo"];
    
    do {
        foundRange = [search rangeOfRegex:regexp inRange:NSMakeRange(cur, end)];
        if (foundRange.location != NSNotFound) {
            // Extract string from found
            NSString *match = [search stringByMatching:regexp options:RKLNoOptions inRange:foundRange capture:1 error:nil];
            if (match) {
                // Categorize URL
                NSURL *build;
                
                // Check for mailto: or javascript:
                bool banned = false;
                if ([match isMatchedByRegex:@"(mailto)|(javascript):"])
                    banned = true;
               
                NSMutableArray *targetList = NULL;
                
                // Check by extension
                if (!banned)
                {
                    build = [NSURL URLWithString:match relativeToURL:currentURL]; // Relative path
                    
                    NSString *extension = [[build.path lowercaseString] stringByMatching:@"\\.[a-z]{2,4}$"];
                   
                   if (extension) {
                      banned = [extension isEqualToString:@".jpg"];
                      banned = banned || [extension isEqualToString:@".css"];
                      banned = banned || [extension isEqualToString:@".js"];
                      
                      if (!banned) {
                         // Check for gif/png
                         if ([extension isEqualToString:@".gif"])
                         {
                            targetList = gifList;
                         }
                         else if ([extension isEqualToString:@".png"])
                         {
                            targetList = pngList;
                         }
                         else
                         {
                            targetList = linkList;
                         }
                      }
                    }
                   
                   if (targetList == NULL) {
                      // Add link
                      targetList = linkList;
                   }
                }
                
                if (!banned && targetList) {
                   NSString *buildrep = [[build.absoluteString componentsSeparatedByString:@"#"] objectAtIndex:0];
                   //NSLog(@"Found URL: %@", buildrep);
                    if (buildrep != nil && [exclusionList objectForKey:buildrep] == nil) {
                        
                        //NSLog(@"\tOK");
                        
                        PlaylistItem *info = [[PlaylistItem alloc] initWithURL:[NSURL URLWithString:buildrep] isLink:(targetList == linkList)];
                        
                        [exclusionList setObject:info forKey:buildrep];
                        
                        //NSLog(@"%@!!", [info class]);
                        //NSLog(@"TEST:%@", info.url);
                        //NSLog(@"++%@", info.parsedURL);
                        
                        [targetList addObject:info];
                        [info release];
                    }
                }
                
            }
            cur = foundRange.location + foundRange.length;
            end = len - cur;
        }
        else
            end = 0;
    } while (end > 0);
    
    //return found;
}


- (void)cancelConnection
{
	if (_loader) {
        [_loader cancel];
        if (_loader) { // may be reset in onLoaderCancel
            [_loader release];
            _loader = nil;
        }
    }
}

- (void)onLoaderCancel:(DataLoader*)loader
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [animController setNoMoreData:NO];
    
    if (_loader) {
        [_loader release];
        _loader = nil;
    }
}

- (void)onLoaderFailed:(DataLoader*)loader withError:(NSError*)error
{
    if (!loader.videoType > 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"err_url", @"Cannot Open URL") 
                                                        message:NSLocalizedString(@"err_urld", @"anim8gif cannot open the URL.") 
                                                       delegate:nil 
                                              cancelButtonTitle:NSLocalizedString(@"ok", @"Ok") 
                                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

// Takes thumbnails of playing gifs
- (void)postLoadThumb:(id)info
{
    if (current_item && current_item == info && current_item.previewImage == nil) {
        PlayerView *plView = animController.plView;
        if (!plView)
            return;
        
        Video *vid = plView.video;
        if (vid) {
            vid.thumbTime = [NSDate timeIntervalSinceReferenceDate] + 0.2;
            vid.thumbObject = current_item;
            vid.thumbDelegate = self;
        }
    }
}

- (void)videoDumpedFrame:(UIImage*)frame withObject:(id)object
{
    if (object != current_item)
        return;
    
    // Draw in scaled image
    UIGraphicsBeginImageContext(CGSizeMake(64,64));
    
    CGSize sz = frame.size;
    
    float src_ratio = sz.height / sz.width; // height / width == widths to height
    float dest_ratio = 1.0; // height / width == widths to height
    
    float t_sx = 1.0;
    float t_sy = 1.0;
    
    if (src_ratio > dest_ratio) {
        // src is longer than dest, so shrink x and y accordingly
        
        float dest_height = t_sx * src_ratio;
        if (dest_height > t_sy) {
            // shrink t_sx by diff
            t_sx -= (dest_height - t_sy) / src_ratio;
        }
        
        t_sy = t_sx * src_ratio;
    } else {
        // src is shorter than dest, so grow x and y accordingly
        
        float dest_width = t_sy / src_ratio;
        if (dest_width > t_sx) {
            // shrink t_sy by diff
            t_sy -= (dest_width - t_sx) * src_ratio;
        }
        
        t_sx = t_sy / src_ratio;
    }
    
    [frame drawInRect:CGRectMake((64 - (64 * t_sx)) * 0.5,
                                 (64 - (64 * t_sy)) * 0.5,
                                 64 * t_sx,64 * t_sy)];
    UIImage *ret = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self performSelectorOnMainThread:@selector(storeCurrentInfoThumb:) withObject:ret waitUntilDone:NO];
}

// Finished loading
- (void)onLoaderData:(DataLoader*)loader
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    //_loader = nil;
    
    NSData *data = loader.receivedData;
    if (data == nil && loader.needData) {
        self.playlist = nil;
        return;
    }
    
    if (loader.videoType > VIDEO_NONE)
    {
        //L0Log(@"Is GIF");
        
        // Signal player it is ok to play!
        if (!startedGIF) {
            currentCache = DynamicCache_initWithData(data, [[self cacheFilename] UTF8String]);
            if (currentCache) {
               startedGIF = [animController startVideo:currentCache ofType:loader.videoType];
            } else {
                startedGIF = NO;
            }
            
            if (!startedGIF)
            {
                // cleanup
                DynamicCache_release(currentCache);
                currentCache = NULL;
                
                // Show error image
                [animController playErrorAnim];
            }
        }
        
        startedGIF = YES;
        [animController setNoMoreData:YES];
        
        // Invoke post-load thumbnail
        [self postLoadThumb:current_item];
    }
    else
    {
        // TODO: ???
        //if (searchController == nil)
            [self transitionOutAnimControllerAnimated:YES];
        
        // HTML? Search for gif links
        NSString *search = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (search == nil) {
            // Whoops, bad data!
            search = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        }
        
        //L0Log(@"Finding URL's...");
       
       
        NSMutableDictionary *exclusionList = [NSMutableDictionary dictionaryWithCapacity:100];
        NSMutableArray *gifList = [NSMutableArray arrayWithCapacity:15];
        NSMutableArray *pngList = [NSMutableArray arrayWithCapacity:15];
        NSMutableArray *linkList = [NSMutableArray arrayWithCapacity:15];
       
       [self findURLUsingRegexp:@"src=['\"]([^'\" >]+)" inString:search exclusionList:exclusionList gifList:gifList pngList:pngList linkList:linkList];
        [self findURLUsingRegexp:@"href=['\"]([^'\" >]+)" inString:search exclusionList:exclusionList gifList:gifList pngList:pngList linkList:linkList];
       
        [gifList sortUsingSelector:@selector(alphabeticalPathSort:)];
        [pngList sortUsingSelector:@selector(alphabeticalPathSort:)];
        [linkList sortUsingSelector:@selector(alphabeticalPathSort:)];
        
        [playlist addObjectsFromArray:gifList];
        [playlist addObjectsFromArray:pngList];
        [playlist addObjectsFromArray:linkList];
        
        [search release];
    }
    
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AnimListLoaded" object:nil userInfo:nil];
    self.playlist = nil;
}

// Currently loading
- (void)onLoaderReceivedData:(DataLoader*)loader withData:(NSData*)data
{
    NSMutableData *receivedData = loader.receivedData;
    
    if (loader.videoType > VIDEO_NONE && !startedGIF && [receivedData length] > (1024*128)) {
        // Make data
        currentCache = DynamicCache_initWithData(receivedData, [[self cacheFilename] UTF8String]);
        if (currentCache) {
            startedGIF = [animController startVideo:currentCache ofType:loader.videoType];
        } else {
            startedGIF = NO;
        }
        
        if (startedGIF)
            [loader ignoreData];
        else if (currentCache) {
            DynamicCache_release(currentCache);
            currentCache = NULL;
        }
    }
    
    Video *vid = animController.plView.video;
    if (vid && vid.src && vid.src->ptr == currentCache) {
        // Append to current video's source
        VideoSource_appendData(vid.src, data);
    } else
        [receivedData appendData:data];
}

// Detected GIF / Document
- (void)onLoaderDetectedDocument:(DataLoader*)loader typeName:(NSString*)aTypeName
{
    // Search should be reset!
    searchBar.text = nil;
    
    if (loader.videoType == VIDEO_GIF) {
        // GIF, open up the anim window in preperation!
        [animController playLoadingAnim];
        [self transitionInAnimControllerAnimated:YES];
        current_item.isLink = false;
    } else if (loader.videoType == VIDEO_PNG) {
       [animController playLoadingAnim];
       [self transitionInAnimControllerAnimated:YES];
       current_item.isLink = false;
    } else {
        // Show playlist
        // TODO: ???
        //if (searchController == nil)
            [self transitionOutAnimControllerAnimated:YES];
        [self showPlaylist:NO withRoot:current_item];
    }
}

- (void)animLoadedWithSuccess:(BOOL)success
{
    // Store to file?
    if (success && allowStorage) {
        if (current_item.didBookmark) {
            DynamicCache *theData = [animController loadedData];
            if (theData) {
                [current_item.storedData ensureStored:theData withType:_loader.videoType];
                [self saveContext];
            }
        }
    }
    
    //[animController.plView pause];
}

- (void)showPro
{
    PlugProController *pl;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        pl = [[PlugProController alloc] initWithNibName:@"PlugPro-iPad" bundle:nil];
    else
        pl = [[PlugProController alloc] initWithNibName:@"PlugPro" bundle:nil];
    pl.nav = navigation;
    [navigation pushViewController:pl animated:YES];
    
    pl.navigationItem.title = NSLocalizedString(@"about_inf", @"About");
    
    [pl release];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if (_loader) {
        [_loader cancel];
        if (_loader) { // may be reset in onLoaderCancel
            [_loader release];
            _loader = nil;
        }
    }
    
    [animController stop];
    [animController release];
    
    [self saveContext];
    self.config = nil;
    
    [managedObjectContext_ release];
    [managedObjectModel_ release];
    [persistentStoreCoordinator_ release];
    
    [searchBar release];
    [instructions release];
    
    [recent_playlist release];
    [playlist release];
    [current_item release];
    [currentURL release];
    self.navigation = nil;
    [navigation release];
    
    [window release];
}

- (void)playFromSettings
{
    NSURL *lastURL = [config URLForKey:@"currentURL"];
    if (lastURL) {
        [config removeObjectForKey:@"currentURL"]; // in case there is a problem...
        
        if (current_item)
            return;
        
        self.currentURL = lastURL;
        launchURL = YES;
        [self grabAnimsFromURL];
    }
    
    lastURL = [config URLForKey:@"currentCDInfo"];
    if (lastURL) {
        [config removeObjectForKey:@"currentCDInfo"];
        
        if (current_item)
            return;
        
        NSManagedObjectID *oid = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:lastURL];
        NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
        [request setEntity:[oid entity]];
        
        NSPredicate *predicate = [NSComparisonPredicate predicateWithLeftExpression: [NSExpression expressionForEvaluatedObject] rightExpression:[NSExpression expressionForConstantValue:oid] modifier:NSDirectPredicateModifier type:NSEqualToPredicateOperatorType options:0];
        [request setPredicate:predicate];
        
        NSArray *results = [self.managedObjectContext executeFetchRequest:request error:nil];
        if ([results count] > 0 )
        {
            [self playItem:[PlaylistItem wrapAnimInfo:(CDAnimInfo*)[results objectAtIndex:0]]];
        }
    }
}

// Multitasking
- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (animController.isPaused)
        [animController play];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    PlayerView *plView = animController.plView;
    if (plView && plView.video)
        [animController pause];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    PlayerView *plView = animController.plView;
    if (plView && plView.video) {
        [animController setTVOutEnabled:NO];
        [animController pause];
    }
    
    if (currentSheet) {
        [currentSheet dismissWithClickedButtonIndex:-1 animated:NO];
        self.currentSheet = nil;
    }
    
    [self cancelConnection];
    if (backgroundTask) {
        [backgroundTask cancel];
        self.backgroundTask = nil;
    }
    
    [config removeObjectForKey:@"currentURL"];
    [config removeObjectForKey:@"currentCDInfo"];
    
    if (current_item) {
        if (current_item.didBookmark) {
            [config setURL:[current_item.storedData.objectID URIRepresentation] forKey:@"currentCDInfo"];
        } else
            [config setURL:current_item.itemURL forKey:@"currentURL"];
    }
    
    [self saveContext];
    [config synchronize];
    self.config = nil;
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if (animController.isPaused) {
        [animController setTVOutEnabled:YES];
        [animController play];
    }
    
    self.config = [NSUserDefaults standardUserDefaults];
    if (migratingData)
        [self restoreMigrationThread];
    else
        [self playFromSettings];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
}

- (NSString *)applicationDocumentsDirectory {
    NSArray* ret = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [ret lastObject];
}

- (NSString *)applicationBundleDirectory {
    NSBundle *theBundle = [NSBundle mainBundle];
    return [theBundle bundlePath];
}

- (NSString *)applicationTempDirectory {
    return NSTemporaryDirectory();
}


- (NSString *)cacheFilename {
    return [[NSTemporaryDirectory() stringByStandardizingPath] stringByAppendingString:@"/gifcache.dat"];
}

- (void)saveContext {
    NSError *error = nil;
    if (managedObjectContext_ != nil) {
        if ([managedObjectContext_ hasChanges] && ![managedObjectContext_ save:&error]) {
            L0Log(@"Unresolved error %@, %@", error, [error userInfo]);
        } 
    }
}    

- (NSManagedObjectContext *)managedObjectContext {
    
    if (managedObjectContext_ != nil) {
        return managedObjectContext_;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext_ = [[NSManagedObjectContext alloc] init];
        [managedObjectContext_ setPersistentStoreCoordinator:coordinator];
    }
    return managedObjectContext_;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (managedObjectModel_ != nil) {
        return managedObjectModel_;
    }
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"Webplay" ofType:@"momd"];
    NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
    managedObjectModel_ = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return managedObjectModel_;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (persistentStoreCoordinator_ != nil) {
        return persistentStoreCoordinator_;
    }
    
    NSURL *storeURL = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @".data_store.sqlite"]];
    
    NSError *error = nil;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
   
    persistentStoreCoordinator_ = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![persistentStoreCoordinator_ addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
       NSLog(@"Failed to open damnit");
    }    
    
    return persistentStoreCoordinator_;
}

- (void)storeCurrentInfoThumb:(UIImage*)thumb
{
    if (!current_item)
        return;
    [current_item setThumb:thumb];
    
    // Finally, save!
    if (current_item.didBookmark) {
        [current_item saveThumb];
        [self saveContext];
    }
}

// NOTE: checkFiles only used when getting bookmarks
#if 0
- (void)checkFiles {
    NSFileManager *files = [NSFileManager defaultManager];
    
    NSManagedObjectContext *ctx = self.managedObjectContext;
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"AnimInfo" inManagedObjectContext:ctx];
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity:entityDescription];
    [request setFetchLimit:1];
    [request setFetchOffset:0];
    [request setPredicate:predicate];
    
    NSError *error = nil;
    NSDirectoryEnumerator *dirEnum =
    [files enumeratorAtPath:[self applicationDocumentsDirectory]];
    NSString *file;
    while (file = [dirEnum nextObject]) {
        [file skipDescendents];
        if ([[file pathExtension] isEqualToString: @"gif"]) {
            // check if we need to index this
            NSPredicate *predicate = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForEvaluatedObject]
                                                                        rightExpression:[NSExpression expressionForConstantValue:file]
                                                                               modifier:NSDirectPredicateModifier
                                                                                   type:NSEqualToPredicateOperatorType options:0];
            [request setPredicate:predicate];
            
            
            NSArray *ret = [ctx executeFetchRequest:request error:&error];
            if ([ret count] > 0) {
                CDAnimInfo *found = [ret objectAtIndex:0];
            } else {
                
            }
        }
    }
}
#endif


- (NSData*)dataForVideoWithType:(NSString**)typeName
{
   AnimPlayerViewController *anim = self.animController;
   
   if (!anim)
      return NULL;
   
   PlayerView *player = anim.plView;
   
   if (!player)
      return NULL;
   
   Video *video = player.video;
   
   if (!video)
      return NULL;
   
   VideoSource *src = video.src;
   
   if (!src || src->size <= 0)
      return NULL;
   
   if (!src->writeable)
   {
      NSMutableData *dat = [NSMutableData dataWithCapacity:src->size];
      [dat setLength:src->size];
      
      // Read video data into dat
      int oldPos = src->pos;
      VideoSource_seek(src, 0);
      VideoSource_read(src, dat.mutableBytes, src->size);
      VideoSource_seek(src, oldPos);
      
      *typeName = (NSString*)kUTTypeGIF;
      if ([video isMemberOfClass:[PngVideo class]])
      {
         *typeName = (NSString*)kUTTypePNG;
      }
      
      return dat;
   }
   
   return NULL;
}

- (bool)isVideoLoaded
{
   AnimPlayerViewController *anim = self.animController;
   
   if (!anim)
      return false;
   
   PlayerView *player = anim.plView;
   
   if (!player)
      return false;
   
   Video *video = player.video;
   
   if (!video)
      return false;
   
   VideoSource *src = video.src;
   
   if (!src || src->size <= 0)
      return false;
   
   return !src->writeable;
}

@end

