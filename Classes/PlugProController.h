//
//  PlugProController.h
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

#import <UIKit/UIKit.h>


@interface PlugProController : UIViewController {
    UINavigationController *nav;
    
    IBOutlet UIButton *moreApps;
    IBOutlet UITextView *copyright;
}

@property(nonatomic, retain) UINavigationController *nav;
@property(nonatomic, retain) UIButton *moreApps;
@property(nonatomic, retain) UITextView *copyright;

- (IBAction)onMoreApps:(id)sender;

@end
