//
//  AnimPlayerViewController.h
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

#import <UIKit/UIKit.h>

#import "PlayerView.h"
#import "SlavePlayerView.h"
#import "VideoWorker.h"

@interface AnimPlayerViewController : UIViewController<UIActionSheetDelegate> {
    UINavigationBar *plBar;
    UIToolbar *plTools;
    
    bool aspectScaleSet;
    bool isPaused;
    
    UIWindow *outWindow;
    SlavePlayerView *outPlView;
    
    IBOutlet PlayerView *plView;
    UIControl *controls;
    
    NSTimer *controlTimer;
    
    CADisplayLink *animationTimer;
    NSTimeInterval animationInterval;
    
    UIPopoverController *barButtonItemPopover;
   
    int sheetMode;
    
    VideoWorker *worker;
}

@property(nonatomic, retain) UIWindow *outWindow;
@property(nonatomic, retain) PlayerView *outPlView;
@property(nonatomic, readonly) bool isPaused;
@property(nonatomic, retain) CADisplayLink *animationTimer;
@property NSTimeInterval animationInterval;
@property(nonatomic, retain) UINavigationBar *plBar;
@property(nonatomic, retain) UIToolbar *plTools;
@property(nonatomic, retain) PlayerView *plView;
@property(nonatomic, retain) UIPopoverController *barButtonItemPopover;

- (bool)startVideo:(DynamicCache*)data ofType:(int)type;
- (bool)startVideoFromLocation:(NSString*)location;
- (void)playLoadingAnim;
- (void)playErrorAnim;

- (void)setViewOnScreen:(UIScreen*)theScreen withMode:(UIScreenMode*)theMode;
- (void)setNoMoreData:(BOOL)withSuccess;
- (BOOL)noMoreData;
- (DynamicCache*)loadedData;
- (void)setTVOutEnabled:(BOOL)isEnabled;

- (void)play;
- (void)pause;
- (void)stop;

- (void)updateViews;

- (void)bookmarkCurrentVideo;

- (IBAction)cancel:(id)sender;

@end
