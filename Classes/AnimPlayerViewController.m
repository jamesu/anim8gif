//
//  AnimPlayerViewController.m
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
//

#import "AnimPlayerViewController.h"
#import "webplayAppDelegate.h"
#import "Video.h"
#import "GifVideo.h"
#import "CDAnimInfo.h"
#import "PlayerView.h"
#import "SlavePlayerView.h"
#import "RootPlayerView.h"
#import "AnimGifActivity.h"

#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/MobileCoreServices.h>

// HACK - Fix linkage
UIKIT_EXTERN NSString *const UIScreenDidConnectNotification         __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_2); // userInfo contains object with annotation property list
UIKIT_EXTERN NSString *const UIScreenDidDisconnectNotification         __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_2); // userInfo contains object with annotation property list


@implementation AnimPlayerViewController

@synthesize plBar;
@synthesize plTools;
@synthesize plView;
@synthesize outWindow;
@synthesize outPlView;

@synthesize animationInterval;
@synthesize animationTimer;
@synthesize isPaused;

@synthesize barButtonItemPopover;

// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
        plBar = nil;
        plTools = nil;
        controls = nil;
        controlTimer = nil;
        aspectScaleSet = NO;
        isPaused = NO;
        outWindow = nil;
        outPlView = nil;
        barButtonItemPopover = nil;
       
        sheetMode = 0;
       
        [[NSNotificationCenter defaultCenter] 
         addObserver:self
         selector:@selector(screenDidChange:)
         name:UIScreenDidConnectNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] 
         addObserver:self
         selector:@selector(screenDidChange:)
         name:UIScreenDidDisconnectNotification object:nil];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        // Custom initialization
        plBar = nil;
        plTools = nil;
        controls = nil;
        controlTimer = nil;
        aspectScaleSet = NO;
        isPaused = NO;
        outWindow = nil;
        outPlView = nil;
        barButtonItemPopover = nil;
       
        sheetMode = 0;
       
        [[NSNotificationCenter defaultCenter]
             addObserver:self
             selector:@selector(screenDidChange:)
             name:UIScreenDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter]
             addObserver:self
             selector:@selector(screenDidChange:)
             name:UIScreenDidDisconnectNotification object:nil];
    }
    return self;
}

- (void)loadView
{
   PlayerView *view = [[PlayerView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
   
   UIView *rootView = [[RootPlayerView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
   
   
   [rootView addSubview:view];
   self.view = rootView;
   self.plView = view;
   [view release];
   [rootView release];
}

- (void)screenDidChange:(NSNotification*)notification
{
    //UIScreen* externalScreen = [notification object];
    //L0Log(@"Screen %@ has changed", externalScreen);
    
    if([[UIScreen screens]count] > 1) //if there are more than 1 screens connected to the device
    {
        CGSize max = CGSizeMake(0,0);
        UIScreenMode *maxScreenMode;
        for(int i = 0; i < [[[[UIScreen screens] objectAtIndex:1] availableModes]count]; i++)
        {
            UIScreenMode *current = [[[[UIScreen screens]objectAtIndex:1]availableModes]objectAtIndex:i];
            if(current.size.width > max.width)
            {
                max = current.size;
                maxScreenMode = current;
            }
        }
        
        //Now we have the highest mode. Turn the external display to use that mode.
        UIScreen *theScreen = [[UIScreen screens] objectAtIndex:1];
        if (outWindow && outWindow.screen == theScreen && (theScreen && theScreen.currentMode == maxScreenMode))
            return;
        [self setViewOnScreen:theScreen withMode:maxScreenMode];
    } else {
        [self setViewOnScreen:nil withMode:nil];
    }
}

- (void)setTVOutEnabled:(BOOL)isEnabled
{
    if (isEnabled) {
        [self screenDidChange:nil];
    } else {
        [self setViewOnScreen:nil withMode:nil];
    }
}

- (void)setViewOnScreen:(UIScreen*)theScreen withMode:(UIScreenMode*)theMode
{
    if (theMode != nil) {
        theScreen.currentMode = theMode;
        if (outPlView)
            [outPlView removeFromSuperview];
        
        UIWindow *newOutWindow = [[UIWindow alloc] initWithFrame:theScreen.applicationFrame];
        SlavePlayerView *newOutPlView = [[SlavePlayerView alloc] initWithFrame:theScreen.applicationFrame inShareGroup:plView.context.sharegroup];
        
        self.outWindow = newOutWindow;
        self.outPlView = newOutPlView;
        
        [newOutWindow release];
        [newOutPlView release];
        
        outPlView.isSlave = true;
        outPlView.video = plView.video;
        
        outPlView.backgroundColor = [UIColor blueColor];
        [outWindow addSubview:outPlView];
        outWindow.screen = theScreen;
        [outWindow makeKeyAndVisible];
        [outPlView release];
        [outWindow release];
    } else {
        if (outPlView)
            [outPlView removeFromSuperview];
        self.outWindow = nil;
        self.outPlView = nil;
    }
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    self.wantsFullScreenLayout = YES;
    [super viewDidLoad];
    
    animationInterval = 1.0 / 60.0;
    isPaused = NO;
    
    CGRect screenFrame, appFrame;
   
    [(webplayAppDelegate*)[[UIApplication sharedApplication] delegate] fixFrameScreen:&screenFrame withStatus:&appFrame];
   
   CGRect origFrame = [[UIScreen mainScreen] applicationFrame];
    self.view.frame = screenFrame;
    self.view.backgroundColor = [UIColor blackColor];//[UIColor greenColor];
    
    controls = [[UIControl alloc] initWithFrame:self.view.frame];
    controls.backgroundColor = [UIColor clearColor];
    controls.opaque = NO;
    controls.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    
    [controls addTarget:self action:@selector(videoTouched:) forControlEvents:UIControlEventTouchDown];
    [plView addTarget:self action:@selector(videoTouched:) forControlEvents:UIControlEventTouchDown];
    
    // Set up the navigation bar
    UINavigationBar *aNavigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(appFrame.origin.x, appFrame.origin.y, appFrame.size.width, 44.0)];
    aNavigationBar.barStyle = UIBarStyleBlackTranslucent;
    aNavigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
   
   //[aNavigationBar setTitleVerticalPositionAdjustment:appFrame.origin.y forBarMetrics:UIBarMetricsDefault];
   
    aNavigationBar.delegate = self;
    self.plBar = aNavigationBar;
    [aNavigationBar release];
    
    // Navigation bar buttons
    UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(cancel:)];
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:@"Animation"];
    navigationItem.leftBarButtonItem = buttonItem;
    [buttonItem release];
    buttonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"expand.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(toggleExpand:)];
    navigationItem.rightBarButtonItem = buttonItem;
    [buttonItem release];
    [plBar pushNavigationItem:navigationItem animated:NO];
    [navigationItem release];
    
    {
        // The bottom toolbar
        appFrame.origin.y = appFrame.size.height + appFrame.origin.y - 44.0;
        appFrame.size.height = 44.0;
        UIToolbar *aToolbar = [[UIToolbar alloc] initWithFrame:appFrame];
        aToolbar.barStyle = UIBarStyleBlackTranslucent;
        aToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        self.plTools = aToolbar;
        [aToolbar release];
        
        [controls addSubview:plTools];
    }
    
    [controls addSubview:plBar];
    [self.view addSubview:controls];
   
    plView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
}

- (UIBarPosition)positionForBar:(id<UIBarPositioning>)bar
{
   return UIBarPositionTopAttached;
}

- (void)showControls:(bool)animated {
   UIApplication *app = [UIApplication sharedApplication];
   //[app setStatusBarStyle:UIStatusBarStyleDefault];
   [app setStatusBarHidden:NO withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    if (animated) {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.25];
    }
    controls.alpha = 1.0;
    if (animated)
        [UIView commitAnimations];
    
    if (controlTimer)
        [controlTimer invalidate];
    controlTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self  selector:@selector(hideControls:) userInfo:nil repeats:NO];
}

- (void)hideControls:(NSTimer*)sender {
    UIApplication *app = [UIApplication sharedApplication];
    [app setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    controls.alpha = 0.0;
    [UIView commitAnimations];
    
    controlTimer = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    
    plView.zoomAspect = false;
   
    // Make the bottom toolbar
    PlaylistItem *currentInfo = del.current_item;
    if (plTools && currentInfo && currentInfo.didBookmark) {
      UIBarButtonItem *rightFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
      
      UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc]
                                     initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteFromBookmarks:)];
      
      UIBarButtonItem *actionButton = [[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(performAction:)];
        [plTools setItems:[NSArray arrayWithObjects:
                           actionButton,
                           rightFlex,
                           buttonItem,
                           nil] animated:NO];
        
        
        [actionButton release];
        [buttonItem release];
        [rightFlex release];
    } else if (plTools) {
        UIBarButtonItem *leftFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *rightFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
       
        UIBarButtonItem *actionButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(performAction:)];
       
        [plTools setItems:[NSArray arrayWithObjects:
                           leftFlex,
                           actionButton,
                           rightFlex,
                           nil] animated:NO];
        
        
       [actionButton release];
        [leftFlex release];
        [rightFlex release];
    }
    
    // This is not called automatically in 3.1...
    [self willAnimateRotationToInterfaceOrientation:self.interfaceOrientation duration:0.0];
    
    [self showControls:NO];
    
    if (del.current_item) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
        [[plBar.items objectAtIndex:0] setTitle:del.current_item.title];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[UIApplication sharedApplication]setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
    
    [super viewWillDisappear:animated];
    
    if (controlTimer)
        [controlTimer invalidate];
    controlTimer = nil;
}

#define DEG_TO_RAD 0.01745329238

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
    
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    
    Video *vid = plView.video;
    if (del.startedGIF && vid && del.loader) {
        // Abandon download
        // jamesu - no longer needed
        //L0Log(@"Abandoning download, run out of memory!");
        //[del cancelConnection];
    }
}

- (DynamicCache*)loadedData
{
    Video *vid = plView.video;
    if (vid && vid.src->type == VIDEOSOURCE_DYNAMICCACHE)
        return (DynamicCache*)vid.src->ptr;
    
    return NULL;
}

- (void)viewDidUnload {
    if (outPlView)
        [outPlView removeFromSuperview];
    self.outWindow = nil;
    self.outPlView = nil;
    self.plTools = nil;
    
    self.plView = nil;
    self.plBar = nil;
    
    self.barButtonItemPopover = nil;
    
    [controls release];
    controls = nil;
    
    [super viewDidUnload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (controlTimer)
        [controlTimer invalidate];
    
    if (worker) {
        [worker stop];
        [worker release];
        plView.worker = nil;
    }
    
    [self setTVOutEnabled:NO];
    [plView release];
    [controls release];
    [plBar release];
    
    if (plTools)
        [plTools release];
    
    [super dealloc];
}
    
- (IBAction)videoTouched:(id)sender
{
    [self showControls:YES];
}

- (IBAction)toggleExpand:(id)sender
{
    plView.zoomAspect = !plView.zoomAspect;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (sheetMode == 2) {
        if (buttonIndex == 0) {
            // Bookmark delete action
            webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
            PlaylistItem *cur = del.current_item;
            
            if (cur.didBookmark) {
                cur.storedData.didBookmark = false;
                [cur.storedData ensureErased];
                [self cancel:self];
                // Note: callback will tell bookmarks to reload
                [del saveContext];
            }
        }
    }
}

- (void)bookmarkCurrentVideo
{
    // Bookmark action
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    PlaylistItem *cur = del.current_item;
    
    if (!cur.didBookmark && cur.storedData) {
        // NOTE: We're assuming here we have a valid CoreData object
        cur.storedData.didBookmark = [NSNumber numberWithBool:true];
        
        DynamicCache *theData = [del.animController loadedData];
        if (theData) {
            Video *video = del.animController.plView.video;
            [cur.storedData ensureStored:theData withType:video.videoType];
        }
        
        [del saveContext];
        [self viewWillAppear:YES];
    }
}

- (IBAction)deleteFromBookmarks:(id)sender
{
    sheetMode = 2;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel")
                                         destructiveButtonTitle:NSLocalizedString(@"del_bk", @"Remove Bookmark")
                                              otherButtonTitles:nil, nil];
    
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    UIActionSheet *current = del.currentSheet;
    if (current) {
        [current dismissWithClickedButtonIndex:-1 animated:NO];
    }
    del.currentSheet = sheet;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet showFromBarButtonItem:sender animated:YES];
    } else {
        [sheet showFromToolbar:plTools];
    }
    
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [sheet release];
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController;
{
    self.barButtonItemPopover = nil;
}

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    return;
}

- (IBAction)performAction:(id)sender
{
   if (self.barButtonItemPopover)
       return;
   
   webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
   NSString *type = NULL;
   NSData *dat = [del dataForVideoWithType:&type];
   NSURL *shareUrl = del.currentURL;
   NSString *shareString = [shareUrl absoluteString];
   AnimGifActivity *ca = [[AnimGifActivity alloc] init];
   NSArray *appList = [NSArray arrayWithObjects:ca, nil];
   NSArray *activityItems = [NSArray arrayWithObjects:shareString, dat, shareUrl, nil];
    
   [ca release];

   UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:appList];
    activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        self.barButtonItemPopover = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
        self.barButtonItemPopover.delegate = self;
        
        CGRect contentFrame = self.view.frame;
        float swap;
        
        if (plView.targetOrient == UIInterfaceOrientationLandscapeRight) {
            swap = contentFrame.size.width;
            contentFrame.size.width = contentFrame.size.height;
            contentFrame.size.height = swap;
        } else if (plView.targetOrient == UIInterfaceOrientationLandscapeLeft) {
            swap = contentFrame.size.width;
            contentFrame.size.width = contentFrame.size.height;
            contentFrame.size.height = swap;
        }
        
        [self.barButtonItemPopover
         presentPopoverFromRect:contentFrame inView:self.view
         permittedArrowDirections:0
         animated:YES];
    }
    else
    {
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
    
    [activityViewController release];
}

- (IBAction)toggleFuzz:(id)sender
{
    //
    VideoTexture_filter(GL_NEAREST);
}

- (bool)startVideo:(DynamicCache*)data ofType:(int)videoType
{
    // Load src + video
    VideoSource *src = VideoSource_init(data, VIDEOSOURCE_DYNAMICCACHE);
    Video *vid = [Video videoByType:videoType withSource:src inContext:plView.context];
    VideoSource_release(src);
    
    // Start if loaded
    if (vid && self.view) {
        plView.video = vid;
        if (outPlView) {
            outPlView.video = plView.video;
        }
        
        [plView clearView];
        [self play];
    } else {
        [plView clearView];
        return false;
    }
    
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    [del recordRecentInfo];
    
    return true;
}

- (bool)startVideoFromLocation:(NSString*)location
{
    // Check type
    const char *ext = strrchr([location UTF8String], '.');
    if (!ext)
       return false;
   
    int videoType = VIDEO_NONE;
    
    if (strcasecmp(ext, ".GIF") == 0) {
       videoType = VIDEO_GIF;
    } else if (strcasecmp(ext, ".PNG") == 0) {
       videoType = VIDEO_PNG;
    } else {
       return false;
    }
   
   
    // Video + src
    FILE *fp = fopen([location UTF8String], "rb");
    if (!fp)
       return false;
   
    VideoSource *src = VideoSource_init(fp, VIDEOSOURCE_FILE);
    VideoSource_finishedBytes(src);
    
    Video *vid = [Video videoByType:videoType withSource:src inContext:plView.context];
    VideoSource_release(src);
    
    // Start if loaded
    if (vid && self.view) {
        plView.video = vid;
        if (outPlView) {
            outPlView.video = plView.video;
        }
        [self play];
        return true;
    }
    
    fclose(fp);
    return false;
}

- (void)setNoMoreData:(BOOL)withSuccess
{
    if (plView.video)
        VideoSource_finishedBytes(plView.video.src);
    
    [(webplayAppDelegate*)[[UIApplication sharedApplication] delegate] animLoadedWithSuccess:withSuccess];
}

- (BOOL)noMoreData
{
    if (plView.video)
        return !plView.video.src->writeable;
    
    return true;
}

- (void)playLoadingAnim
{
    [self startVideoFromLocation:[[NSBundle mainBundle] pathForResource:@"loading.gif" ofType:nil]];
}

- (void)playErrorAnim
{
    [self startVideoFromLocation:[[NSBundle mainBundle] pathForResource:@"error.gif" ofType:nil]];
}

CADisplayLink *displayLink;

- (void)play {
   //if (plView)
   //   [plView clearView];
   
    Video *vid = plView.video;
    if (vid && !isPaused) {
        [vid play:YES];
        
        if (worker != nil) {
            [worker stop];
            [worker release];
            worker = nil;
            plView.worker = nil;
        }
    }
    
    if (!isPaused)
        [self setTVOutEnabled:YES];
    
    // Start the frame grabber
    if (!worker) {
        worker = [[VideoWorker alloc] initWithVideo:vid andTarget:vid];
        [worker start];
        plView.worker = worker;
    } else if (isPaused) {
        isPaused = false;
        [worker start];
    }
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
   
    if (!animationTimer) {
      self.animationTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateViews)];
      [animationTimer setFrameInterval:1.0];
      [animationTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
       animationTimer.paused = NO;
    }
}

- (void)updateViews {
    float dt = animationTimer.duration;
    if (plView)
        [plView drawView:dt];
    if (outPlView) {
        outPlView.gotVideoFrame = plView.gotVideoFrame;
        [outPlView drawView:dt];
    }
}

- (void)pause {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    isPaused = true;
    self.animationTimer.paused = YES;
    [worker stop];
}

- (void)stop {
    Video *vid = plView.video;
    if (vid)
        [vid stop];
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    if (animationTimer) {
       [animationTimer invalidate];
       [animationTimer release];
       animationTimer = nil;
    }
    [self setTVOutEnabled:NO];
    
    if (worker) {
        [worker stop];
        [worker release]; // << NOTE: primary cause of memory leaks
        worker = nil;
        plView.worker = nil;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    CGRect contentFrame = [self.view frame];
    CGSize size = contentFrame.size;
    float swap;
    float sz_long, sz_short;
    if (size.width > size.height)
    {
        sz_long = size.width;
        sz_short = size.height;
    }
    else
    {
        sz_short = size.width;
        sz_long = size.height;
    }
    
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        plView.transform = CGAffineTransformMakeRotation(-1.57079633);
        plView.center = CGPointMake(sz_long/2, sz_short/2);
        swap = contentFrame.size.width;
        contentFrame.size.width = contentFrame.size.height;
        contentFrame.size.height = swap;
    } else if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
        plView.transform = CGAffineTransformMakeRotation(1.57079633);
        plView.center = CGPointMake(sz_long/2, sz_short/2);
        swap = contentFrame.size.width;
        contentFrame.size.width = contentFrame.size.height;
        contentFrame.size.height = swap;
    } else if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
        plView.transform = CGAffineTransformMakeRotation(0);
        plView.center = CGPointMake(sz_short/2, sz_long/2);
    } else if (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        plView.transform = CGAffineTransformMakeRotation(-1.57079633*2);
        plView.center = CGPointMake(sz_short/2, sz_long/2);
    }
    
    if (plView)
        plView.targetOrient = toInterfaceOrientation;
    
    if (self.barButtonItemPopover)
    {
        [barButtonItemPopover dismissPopoverAnimated:NO];
        [self.barButtonItemPopover
         presentPopoverFromRect:contentFrame inView:self.view
         permittedArrowDirections:0
         animated:YES];
    }
}


- (void)setAnimationInterval:(NSTimeInterval)interval {
    
    animationInterval = interval;
}



- (IBAction)cancel:(id)sender
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    
    Video *vid = plView.video;
    if (vid) {
        // cancel thumbnails
        vid.thumbDelegate = nil;
        vid.thumbObject = nil;
        vid.thumbTime = 0;
    }
    
    [self stop];
    plView.video = nil;
    if (outPlView) {
        outPlView.video = nil;
    }
    [del cancelConnection];
    del.current_item = nil;
    
    if (controlTimer) {
        [controlTimer invalidate];
        controlTimer = nil;
    }
    
    [del transitionOutAnimControllerAnimated:YES]; 
}


@end
