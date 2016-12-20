//
//  CDAnimInfo.h
//  webplay
//
//  Created by James Urquhart on 07/11/2010.
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
//

#import <CoreData/CoreData.h>
#include "VideoSource.h"

@interface CDAnimInfo : NSManagedObject {
    UIImage *image;
    NSURL *parsedURL;
}

@property(nonatomic, readonly) UIImage *image;
@property(nonatomic, readonly) NSURL *parsedURL;

@property (nonatomic, retain) NSNumber * didBookmark;
@property (nonatomic, retain) NSNumber * dontShow;
@property (nonatomic, retain) NSNumber * isLink;
@property (nonatomic, retain) NSNumber * didSync;
@property (nonatomic, retain) NSDate * lastPlay;
@property (nonatomic, retain) NSString * storedID;
@property (nonatomic, retain) NSString * storedThumbID;
@property (nonatomic, retain) NSString * url;

- (NSString*)storedFile;
- (BOOL)ensureStored:(DynamicCache*)receivedData withType:(int)videoType;
- (void)ensureErased;
- (void)ensureClean;

- (BOOL)saveThumb;
- (void)setThumb:(UIImage*)img;

- (void)clearCache;

+ (NSString*)fileNameForURL:(NSURL*)url;
+ (NSString*)fileNameForURL:(NSURL*)url ofType:(int)vidType;
+ (void)ensureThumbDirectory;
@end
