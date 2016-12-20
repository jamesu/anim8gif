//
//  RootPlayerView.m
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

#import "RootPlayerView.h"
#import "webplayAppDelegate.h"
#import "AnimPlayerViewController.h"
#import "PlayerView.h"
#import "GifVideo.h"
#import "PngVideo.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation RootPlayerView

- (id)initWithFrame:(CGRect)frame
{
   if (self = [super initWithFrame:frame])
   {
      UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showMenu:)];
      [self addGestureRecognizer:gestureRecognizer];
   }
   
   return self;
}

- (CGRect)targetRect
{
   CGRect fr = self.frame;
   return CGRectMake((fr.size.width / 2) - 6, (fr.size.height / 2) - 6, 0.0, 0.0);
}

- (void)copy:(id)sender
{
   // Grab data for current gif
   
   UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
   pasteBoard.persistent = YES;
   
   webplayAppDelegate *app = [[UIApplication sharedApplication] delegate];
   NSString *typeName = NULL;
   NSData *dat = [app dataForVideoWithType:&typeName];
   
   if (dat)
   {
      [pasteBoard setData:dat forPasteboardType:typeName];
   }
}

- (void)showMenu:(UIGestureRecognizer *)gestureRecognizer
{
   webplayAppDelegate *app = [[UIApplication sharedApplication] delegate];
   if (![app isVideoLoaded])
      return;
   
   if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
      [self becomeFirstResponder];
      
      CGPoint center = [gestureRecognizer locationInView:self];
      
      UIMenuController *menu = [UIMenuController sharedMenuController];
      [menu setTargetRect:CGRectMake(center.x, center.y, 0, 0) inView:self];
      [menu setMenuVisible:YES animated:YES];
   }
}

- (BOOL)canBecomeFirstResponder
{
   return YES;
}

@end
