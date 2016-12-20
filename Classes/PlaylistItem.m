//
//  PlaylistItem.m
//  webplay
//
//  Created by James Urquhart on 08/01/2014.
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

#import "PlaylistItem.h"
#import "CDAnimInfo.h"
#import "webplayAppDelegate.h"

@implementation PlaylistItem

@synthesize itemURL;
@synthesize previewImage;
@synthesize storedData;
@synthesize isLink;

@dynamic dontShow;

@dynamic title;
@dynamic info;

- (id)initWithURL:(NSURL*)url isLink:(bool)isLink
{
    if (self = [super init])
    {
        self.itemURL = url;
        self.isLink = isLink;
        self.storedData = nil;
    }
    return self;
}

- (id)initWithData:(CDAnimInfo*)data
{
    if (self = [super init])
    {
        self.storedData = data;
        [self updateFromCoreData];
    }
    return self;
}

- (void)dealloc
{
    self.storedData = nil;
    if (title)
        [title release];
    if (info)
        [info release];
    self.itemURL = nil;
    self.previewImage = nil;
    [super dealloc];
}

- (void)updateFromCoreData
{
    if (storedData != nil)
    {
        UIImage *storedImage = storedData.image;
        self.itemURL = storedData.parsedURL;
        if (storedImage)
            self.previewImage = storedData.image;
        self.isLink = [storedData.isLink boolValue];
    }
}

- (void)setDerivedAttrs {
    if (title)
        [title release];
    if (info)
        [info release];
    
    NSString *path = itemURL.path;
    if (path == nil || [path length] == 0) {
        title = itemURL.absoluteString;
        info = nil;
    } else {
        NSString *param = itemURL.query;
        if (param) {
            title = [NSString stringWithFormat:@"%@?%@", [itemURL.path lastPathComponent], param];
        } else {
            title = [itemURL.path lastPathComponent];
        }
        
        NSString *buildStr = itemURL.path;
        NSMutableArray *components = [NSMutableArray arrayWithArray:[buildStr pathComponents]];
        if ([components count] > 1) {
            [components removeLastObject];
            buildStr = [NSString pathWithComponents:components];
        }
        info = [NSString stringWithFormat:@"%@%@", itemURL.host, buildStr];
    }
    
    [title retain];
    [info retain];
}

- (void)setThumb:(UIImage*)image
{
    self.previewImage = image;
    if (storedData)
        [storedData setThumb:image];
}

- (void)saveThumb
{
    if (storedData)
        [storedData saveThumb];
}

- (NSString*)title
{
    if (!title)
        [self setDerivedAttrs];
    return title;
}

- (NSString*)info
{
    if (!info)
        [self setDerivedAttrs];
    return info;
}

- (void)deleteStorage
{
    if (!storedData)
        return;
    webplayAppDelegate *del = [[UIApplication sharedApplication] delegate];
    [del deleteInfo:storedData];
    self.storedData = nil;
}


- (NSComparisonResult)alphabeticalPathSort:(PlaylistItem *)aInfo
{
    return [itemURL.path compare: aInfo.itemURL.path];
}

- (bool)dontShow
{
    return storedData ? [storedData.dontShow boolValue] : false;
}

- (void)setDontShow:(bool)aValue
{
    if (storedData)
    {
        storedData.dontShow = aValue;
    }
}

- (bool)didBookmark
{
    return storedData ? [storedData.didBookmark boolValue] : false;
}

+ (PlaylistItem*)wrapAnimInfo:(CDAnimInfo*)info
{
    PlaylistItem *item = [[PlaylistItem alloc] initWithData:info];
    return [item autorelease];
}

@end

