//
//  InstructionsViewController.m
//  webplay
//
//  Created by James Urquhart on 06/03/2009.
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

#import "InstructionsViewController.h"
#import "webplayAppDelegate.h"

#import "LibraryCell.h"
#import "CDAnimInfo.h"
#import "PlaylistItem.h"

extern void getImageForInfo(PlaylistItem *info, LibraryCell *cell);

@implementation InstructionsViewController


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self]; // don't reload!
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == 1 ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (void)viewWillAppear:(BOOL)animated
{
    nav.toolbarHidden = YES;
    nav.navigationBarHidden = NO;
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    del.activePlaylistView = self;
    
    UISearchBar *search = del.searchBar;
    CGRect searchRect = search.frame;
    searchRect.size.width = nav.navigationBar.frame.size.width;
    search.frame = searchRect;
    
    self.navigationItem.titleView = search;
    
    // Always reload the recent playlist
    [del loadRecentPlaylist];
    self.playlist = del.recent_playlist;
    
    [plView reloadData];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
    {
        NSMutableArray *list = playlist;
        PlaylistItem *info = [list objectAtIndex:indexPath.row];
        webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
        
        if (info.storedData)
        {
            if (info.didBookmark) {
                info.storedData.dontShow = [NSNumber numberWithBool:true];
                [del saveContext];
            } else {
                [info deleteStorage];
            }
        }
        
        [list removeObjectAtIndex:indexPath.row];
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                         withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return section == 0 ? NSLocalizedString(@"inst", @"Instructions") : NSLocalizedString(@"rectp", @"Recently played");
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (indexPath.row > 0)
            return 44.0;
        else
            return 64.0;

    }
    
    return 64.0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 0 && indexPath.row == 0) ? NULL : indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 1) {
            [del showPro];
        } else if (indexPath.row == 2) {
            NSURL *build = [[[NSURL alloc] initWithScheme:@"http" host:@"jamesu.net" path:@"/a/anim8gif/bookmarklet.html?b=javascript:window.location=unescape('animgif%3A%2F%2Fplay%3Furl%3D')+escape(window.location);"] autorelease];
            [[UIApplication sharedApplication] openURL:build];
        }
        return;
    }
    
    [del playItem:[playlist objectAtIndex:indexPath.row]];
}

extern NSString *kLCell;
NSString *kICell = @"KCELL";

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    int row = indexPath.row;
    UITableViewCell *tCell;
    
    if (indexPath.section == 0) {
        if (row == 0) {
            UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(kCellLeftOffset, 0, tableView.frame.size.width - (kCellLeftOffset*2), 60.0)];
            label.lineBreakMode = NSLineBreakByWordWrapping;
            label.numberOfLines = 3;
            label.font = [UIFont systemFontOfSize:14.0];
            //label.backgroundColor = [UIColor redColor];
            label.text = NSLocalizedString(@"instructions", @"Enter a URL above to look for GIFs, or use the bookmarklet to grab straight from safari.");
            [cell.contentView addSubview:label];
            [label release];
            
            tCell = cell;
        } else if (row == 1) { 
            UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
            cell.textLabel.text = NSLocalizedString(@"about_inf", @"About");
            tCell = cell;
        } else {
            UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
            cell.textLabel.text = NSLocalizedString(@"add_bkt", @"Add Bookmarklet");
            tCell = cell;
        }
    } else {
        LibraryCell *cell = (LibraryCell *)[tableView dequeueReusableCellWithIdentifier:kLCell];
    
        if (cell == nil)
            cell = [[[LibraryCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kLCell] autorelease];
    
        PlaylistItem *info = [playlist objectAtIndex:row];
        cell.info = info;
        cell.textLabel.text = info.title;
        cell.description = info.info;
        
        getImageForInfo(info, cell);
        
        tCell = cell;
    }
    
    // Accessory
    if (tCell)
        tCell.accessoryType = (indexPath.section == 1 || (indexPath.section == 0 && indexPath.row > 0)) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    
    return tCell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 0 ? 3 : (playlist == nil ? 0 : [playlist count]);
}

- (void)animListLoaded:(id)notification
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    self.playlist = del.recent_playlist;
    
    [plView reloadData];
    [[NSNotificationCenter defaultCenter] removeObserver:self]; // don't reload again!
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


@end
