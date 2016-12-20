//
//  AnimGifActivity.m
//  webplay
//
//  Created by James Urquhart on 07/01/2014.
//
// (C) James S Urquhart 2014 - 2016
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

#import "AnimGifActivity.h"
#import "webplayAppDelegate.h"
#import "AnimPlayerViewController.h"

@implementation AnimGifActivity


- (NSString *)activityType
{
    return @"com.jamesu.Anim8gif";
}

- (NSString *)activityTitle
{
    return NSLocalizedString(@"bk", @"Bookmark");
}

- (UIImage *)activityImage
{
    // Note: These images need to have a transparent background and I recommend these sizes:
    // iPadShare@2x should be 126 px, iPadShare should be 53 px, iPhoneShare@2x should be 100
    // px, and iPhoneShare should be 50 px. I found these sizes to work for what I was making.
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        return [UIImage imageNamed:@"ActivityIcon.png"];
    }
    else
    {
        return [UIImage imageNamed:@"ActivityIcon.png"];
    }
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    AnimPlayerViewController *anim = del.animController;
    
    if (anim.plView.video == nil)
    {
        // Must be viewing playlist...
        PlaylistViewController *last_pl = (PlaylistViewController*)del.activePlaylistView;
        if ([last_pl isKindOfClass:[PlaylistViewController class]])
        {
            if (last_pl.rootInfo.didBookmark)
            {
                return NO;
            }
        }
    }
    else
    {
        if (del.current_item && del.current_item.didBookmark)
        {
            return NO;
        }
        else if (!del.current_item)
        {
            return NO;
        }
    }
    return YES;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
}

- (UIViewController *)activityViewController
{
    return nil;
}

- (void)performActivity
{
    // This is where you can do anything you want, and is the whole reason for creating a custom
    // UIActivity
    // Bookmark action
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    AnimPlayerViewController *anim = del.animController;
    
    if (anim.plView.video == nil)
    {
        // Must be viewing playlist, bookmark it
        PlaylistViewController *last_pl = (PlaylistViewController*)del.activePlaylistView;
        if ([last_pl isKindOfClass:[PlaylistViewController class]])
        {
            [last_pl addToBookmarks:self];
        }
    }
    else
    {
        // Must be watching anim, save it
        [anim bookmarkCurrentVideo];
    }
    
    [self activityDidFinish:YES];
}
@end
