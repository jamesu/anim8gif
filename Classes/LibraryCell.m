//
//  LibraryCell.m
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

#import "LibraryCell.h"


@implementation LibraryCell

@dynamic description;
@synthesize info = _info;

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
        _description = nil;
        _info = nil;
    }
    return self;
}

- (NSString*)description
{
    UILabel *desc = self.detailTextLabel;
    if (desc)
        return desc.text;
    else
        return NULL;
}

- (void)setDescription:(NSString*)aValue {
    self.detailTextLabel.text = aValue;
    [self layoutSubviews];
}

- (void)drawRect:(CGRect)rect {
    // Drawing code
    [super drawRect:rect];
}


- (void)dealloc {
    [_description release];
    [super dealloc];
}


@end
