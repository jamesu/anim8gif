//
//  LibraryCell.h
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

#import <UIKit/UIKit.h>
#import "CDAnimInfo.h"
#import "PlaylistItem.h"

// table view cell content offsets
#define kCellLeftOffset			8.0
#define kCellLeftImageOffset    8.0+64.0
#define kCellTopOffset			12.0
#define kCellDescriptionOffset	24.0

#define kCellHeight 64.0

@interface LibraryCell : UITableViewCell {
    UILabel *_description;
    PlaylistItem *_info;

}

@property(nonatomic, copy) NSString *description;
@property(nonatomic, assign) PlaylistItem *info;

@end
