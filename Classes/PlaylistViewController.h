//
//  PlaylistViewController.h
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

@class CDAnimInfo;
@class PlaylistItem;

@interface PlaylistViewController : UIViewController<UITableViewDelegate,UIActionSheetDelegate> {
    IBOutlet UITableView *plView;
    
    UINavigationController *nav;
    
    NSMutableArray *playlist;
    NSMutableArray *links;
    PlaylistItem *rootInfo;
    
    UIPopoverController *barButtonItemPopover;
    
    NSInteger pushIDX;
    
    bool showToolbar;
    bool showBookmarks;
}

@property(nonatomic, retain) UITableView *plView;
@property(nonatomic, retain) NSMutableArray *playlist;
@property(nonatomic, retain) NSMutableArray *links;
@property(nonatomic, assign) bool showToolbar;
@property(nonatomic, assign) bool showBookmarks;
@property(nonatomic, retain) UINavigationController *nav;
@property(nonatomic, retain) PlaylistItem *rootInfo;
@property(nonatomic, retain) UIPopoverController *barButtonItemPopover;

@property(nonatomic, assign) NSInteger pushIDX;

- (void)animListLoaded:(id)notification;
- (IBAction)addToBookmarks:(id)sender;
- (IBAction)editBookmarks:(id)sender;
- (void)waitForNotification;

- (void)reloadVisibleImage;

@end
