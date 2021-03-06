//
//  PlugProController.m
//  webplay
//
//  Created by James Urquhart on 11/11/2009.
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

#import "webplayAppDelegate.h"
#import "PlugProController.h"


@implementation PlugProController

@synthesize nav;
@synthesize moreApps;
@synthesize copyright;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *str = NSLocalizedString(@"about_apps", @"Send Feedback");
    [moreApps setTitle:str forState:UIControlStateNormal];
    [moreApps setTitle:str forState:UIControlStateHighlighted];
   
    copyright.text = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Copyright" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
    
    [moreApps release];
    moreApps = nil;
   
    [copyright release];
    copyright = nil;
    
    [super viewDidUnload];
}

- (IBAction)onMoreApps:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.jamesu.net/feedback"]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)dealloc {
    [moreApps release];
    [copyright release];
    [nav release];
    [super dealloc];
}


@end
