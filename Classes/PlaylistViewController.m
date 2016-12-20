//
//  PlaylistViewController.m
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

#import "PlaylistViewController.h"
#import "LibraryCell.h"
#import "AnimPlayerViewController.h"
#import "webplayAppDelegate.h"
#import "CDAnimInfo.h"
#import "AnimGifActivity.h"

static UIImage *kPlaceImg = nil;

void getImageForInfo(PlaylistItem *item, LibraryCell *cell)
{
    UIImage *img = item.previewImage;
    if (img) {
        cell.imageView.image = img;
    } else {
        // placeholder
        if (!item.isLink) {
            //
            cell.imageView.image = kPlaceImg;
            return;
        }
        
        cell.imageView.image = nil;
    }
}

@implementation PlaylistViewController

@synthesize plView;
@dynamic playlist;
@synthesize links;
@dynamic showToolbar;
@dynamic showBookmarks;
@synthesize nav;
@synthesize rootInfo;
@synthesize pushIDX;

@synthesize barButtonItemPopover;

// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
        plView = nil;
        playlist = nil;
        showToolbar = NO;
        rootInfo = nil;
        barButtonItemPopover = nil;
        
        pushIDX = -1;
        
        [self waitForNotification];
    }
    return self;
}

- (NSArray*)bookmarkItems:(bool)editing
{
    UIBarButtonItem *but = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(editing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit) 
                                                                         target:self 
                                                                         action:@selector(editBookmarks:)];
    NSArray *arr = [NSArray arrayWithObjects:but,
                    nil];
    [but release];
    return arr;
}

- (void)viewWillAppear:(BOOL)animated {
    nav.toolbarHidden = NO;
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    del.activePlaylistView = self;
    [self reloadVisibleImage];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (bool)showToolbar
{
    return showToolbar;
}

- (void)setShowToolbar:(bool)aValue
{
    if (aValue) {
        NSArray *items;
        if (showBookmarks) {
            items = [self bookmarkItems:NO];
        } else {
            UIBarButtonItem *leftFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIBarButtonItem *rightFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(performAction:)];
            addButton.style = UIBarButtonItemStylePlain;
            items = [NSArray arrayWithObjects:
                            leftFlex,
                            addButton,
                            rightFlex,
                            nil];
            
            [leftFlex release];
            [addButton release];
            [rightFlex release];
        }
        
        //Reposition and resize the receiver
        [self setToolbarItems:items animated:NO];
    } else if (!aValue) {
        [self setToolbarItems:[NSArray array] animated:NO];
    }
    
    showToolbar = aValue;
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.barButtonItemPopover = nil;
}

- (void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    return;
}

- (IBAction)performAction:(id)sender
{
    if (barButtonItemPopover)
        return;
    
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    NSURL *shareUrl = del.currentURL;
    NSString *shareString = [shareUrl absoluteString];
    AnimGifActivity *ca = [[AnimGifActivity alloc] init];
    NSArray *appList = [NSArray arrayWithObjects:ca, nil];
    NSArray *activityItems = [NSArray arrayWithObjects:shareString, shareUrl, nil];
    
    [ca release];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:appList];
    activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        CGRect rect = [self.view frame];
        if (!barButtonItemPopover)
        {
            self.barButtonItemPopover = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
            self.barButtonItemPopover.delegate = self;
        }
        
        [self.barButtonItemPopover
         presentPopoverFromRect:rect inView:self.view
         permittedArrowDirections:0
         animated:YES];
    }
    else
    {
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
    
    [activityViewController release];
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{
    if (self.barButtonItemPopover)
    {
        CGRect rect = [self.view frame];
        [barButtonItemPopover dismissPopoverAnimated:NO];
        [self.barButtonItemPopover
         presentPopoverFromRect:rect inView:self.view
         permittedArrowDirections:0
         animated:YES];
    }
}

- (bool)showBookmarks
{
    return showBookmarks;
}

- (void)setShowBookmarks:(bool)aValue
{
    showBookmarks = aValue;
    if (showBookmarks)
        self.navigationItem.title = NSLocalizedString(@"bks", @"Bookmarks");
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    if (buttonIndex == 0 && rootInfo != nil) {
        //rootInfo.didBookmark = true;
        [del saveContext];
    }
    
    del.currentSheet = nil;
}

- (IBAction)addToBookmarks:(id)sender
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    CDAnimInfo *storedAnimInfo = rootInfo.storedData;
    
    if (!storedAnimInfo)
    {
        storedAnimInfo = (CDAnimInfo*)[NSEntityDescription insertNewObjectForEntityForName:@"AnimInfo"
                                                                      inManagedObjectContext:del.managedObjectContext] ;
        storedAnimInfo.url = [rootInfo.itemURL absoluteString];
        storedAnimInfo.dontShow = [NSNumber numberWithBool:false];
        storedAnimInfo.isLink = [NSNumber numberWithBool:rootInfo.isLink];
        storedAnimInfo.didSync = [NSNumber numberWithBool:NO];
        storedAnimInfo.dontShow = [NSNumber numberWithBool:NO];
    }
    
    if (storedAnimInfo)
    {
        storedAnimInfo.didBookmark = [NSNumber numberWithBool:YES];
    }
    [del saveContext];
}

- (IBAction)editBookmarks:(id)sender
{
    if (!plView.editing) {
        plView.editing = YES;
        [nav.toolbar setItems:[self bookmarkItems:YES] animated:YES];
    } else {
        plView.editing = NO;
        [nav.toolbar setItems:[self bookmarkItems:NO] animated:YES];
    }
}

- (void)waitForNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(animListLoaded:) name:@"AnimListLoaded" object:nil];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    plView.allowsSelectionDuringEditing = NO;
    
    if (kPlaceImg == nil) {
        kPlaceImg = [[UIImage imageNamed:@"ico_gif.png"] retain];
    }
}

- (void)viewDidUnload {
    [plView release];
    plView = nil;
    
    self.barButtonItemPopover = nil;
    
    [super viewDidUnload];
}

- (void)animListLoaded:(id)notification
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    self.playlist = del.playlist;
    del.playlist = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self]; // don't reload again!
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    PlaylistItem *item;
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if (links != nil && (playlist == nil || indexPath.section == 1))
        item = [links objectAtIndex:indexPath.row];
    else
        item = [playlist objectAtIndex:indexPath.row];
    
    [del playItem:item];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (showBookmarks && tableView.editing) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        int section = indexPath.section;
        NSMutableArray *list = ((section == 0 && playlist != nil) ? playlist : links);
        PlaylistItem *item = [list objectAtIndex:indexPath.row];
        webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
        
        if (item.storedData)
        {
            item.storedData.didBookmark = [NSNumber numberWithBool:NO];
            [item deleteStorage];
        }
        
        [list removeObjectAtIndex:indexPath.row];
        
        if (showBookmarks) {
            del.recent_playlist = nil;
        }
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
         withRowAnimation:UITableViewRowAnimationFade];
        
        [del saveContext];
    }
}

// Data manipulation - reorder / moving support

/*- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
}*/

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kCellHeight;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    return proposedDestinationIndexPath;
}

NSString *kLCell = @"LCELL";

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    int row = indexPath.row;
    int section = indexPath.section;
    
    LibraryCell *cell = (LibraryCell *)[tableView dequeueReusableCellWithIdentifier:kLCell];
    
    NSArray *list = ((section == 0 && playlist != nil) ? playlist : links);
    if (row < [list count]) {
        
        if (cell == nil)
            cell = [[[LibraryCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kLCell] autorelease];
        
        PlaylistItem *info = [list objectAtIndex:row];
        cell.info = info;
        cell.textLabel.text = info.title;
        cell.description = info.info;
        
        // Accessory
        if (links != nil && (playlist == nil || indexPath.section == 1))
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        else
            cell.accessoryType = UITableViewCellAccessoryNone;
        
        getImageForInfo(info, cell);
        
        return cell;
    } else {
        //L0Log(@"Invalid row for section %i", section);
        return nil;
    }
}

- (void)reloadVisibleImage
{
    for (LibraryCell *cell in [plView visibleCells]) {
        if ([cell class] != [LibraryCell class])
            continue;
        
        PlaylistItem *info = cell.info;
        getImageForInfo(info, cell);
        
        [cell setNeedsLayout];
        [cell.imageView setNeedsDisplay];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (links == nil || playlist == nil) ? 1 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (playlist == nil || section == 1) {
        if (links == nil)
            return nil;
        else
            return NSLocalizedString(@"links", @"Links");
    } else
        return NSLocalizedString(@"anims", @"GIFS");
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (playlist == nil || section == 1) {
        if (links == nil)
            return 0;
        else
            return [links count];
    } else
        return [playlist count];
}

- (NSMutableArray*)playlist
{
    return playlist;
}

- (void)setPlaylist:(NSMutableArray*)aValue
{
    if (playlist)
        [playlist release];
    if (links)
        [links release];
    
    // Split playlist into two items: 
    NSMutableArray *linkConstruct = [NSMutableArray array];
    NSMutableArray *listConstruct = [NSMutableArray array];
    
    CDAnimInfo *info;
    for (info in aValue)
    {
        if (info.isLink) {
            //L0Log(@"LINK: %@", info.url);
            [linkConstruct addObject:info];
        } else {
            //L0Log(@"IMAGE: %@", info.url);
            [listConstruct addObject:info];
        }
    }
    
    if ([linkConstruct count] != 0)
        links = [linkConstruct retain];
    else
        links = nil;
    
    if ([listConstruct count] != 0)
        playlist = [listConstruct retain];
    else
        playlist = nil;
    [plView reloadData];
}

- (void)didReceiveMemoryWarning {
    // Clear images
    for (CDAnimInfo *info in playlist) {
        [info clearCache];
    }
    
    [super didReceiveMemoryWarning];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [rootInfo release];
    [playlist release];
    [links release];
    [nav release];
    [plView release];
    [super dealloc];
}


@end
