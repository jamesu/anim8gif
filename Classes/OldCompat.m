//
//  Compat.m
//  webplay
//
//  Created by James Urquhart on 12/09/2010.
//
// (C) James S Urquhart 2010 - 2016
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

#import "OldCompat.h"

@implementation OldCompat

+ (BOOL)isMultitaskingAvailable
{
    UIDevice* device = [UIDevice currentDevice];
    if ([device respondsToSelector:@selector(isMultitaskingSupported)])
        return device.multitaskingSupported;
    else
        return NO;
}

+ (BOOL)isTVOutAvailable
{
    if ([[UIScreen class] respondsToSelector:@selector(screens)])
        return YES;
    else {
        return NO;
    }
}

@end
