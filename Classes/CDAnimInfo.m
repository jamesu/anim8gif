//
//  CDAnimInfo.m
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

#import "CDAnimInfo.h"
#include "Video.h"
#import <CommonCrypto/CommonDigest.h>


@implementation CDAnimInfo

@dynamic image;
@dynamic url;
@dynamic isLink;
@dynamic didSync;
@dynamic didBookmark;
@dynamic dontShow;
@dynamic lastPlay;

@dynamic storedThumbID;
@dynamic storedID;

@dynamic parsedURL;

// TODO: update derived attrs

// since CoreData sucks, we're going to ensure the cache values with this method
- (void)ensureClean {
    image = nil;
    parsedURL = nil;
}

- (void)awakeFromFetch {
    [super awakeFromFetch];
    image = nil;
    parsedURL = nil;
}

- (void)clearAttrCache {
    if (image)
        [image release];
    if (parsedURL)
        [parsedURL release];
    image = nil;
    parsedURL = nil;
}

- (void)setDerivedAttrs {
    NSURL *theURL = [NSURL URLWithString:self.url];
    if (parsedURL)
        [parsedURL release];
    parsedURL = [theURL retain];
}

- (NSURL*)parsedURL
{
    if (!parsedURL)
        [self setDerivedAttrs];
    return parsedURL;
}

- (void)setUrl:(NSString *)value 
{
    [self willChangeValueForKey:@"url"];
    [self setPrimitiveUrl:value];
    [self clearAttrCache];
    [self didChangeValueForKey:@"url"];
}

- (NSComparisonResult)alphabeticalPathSort:(CDAnimInfo *)aInfo
{
    return [self.parsedURL.path compare: aInfo.parsedURL.path];
}

- (NSComparisonResult)alphabeticalHostSort:(CDAnimInfo *)aInfo
{
    return [self.parsedURL.host compare: aInfo.parsedURL.host];
}

static NSString *doMD5(const char *cStr)
{
	unsigned char result[16];
	CC_MD5( cStr, strlen(cStr), result );
	return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X.gif",
            result[0], result[1], result[2], result[3], 
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

static NSString *doMD5WithExt(const char *cStr, const char *ext)
{
	unsigned char result[16];
	CC_MD5( cStr, strlen(cStr), result );
	return [NSString stringWithFormat:
           @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X.%s",
           result[0], result[1], result[2], result[3], 
           result[4], result[5], result[6], result[7],
           result[8], result[9], result[10], result[11],
           result[12], result[13], result[14], result[15], ext
           ];
}

+ (NSString*)fileNameForURL:(NSURL*)url {
    if ([url isFileURL]) {
        return [url.path lastPathComponent];
    } else {
        return [NSString stringWithFormat:@"%@-%@", [[url.path lastPathComponent] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], doMD5([[url absoluteString] UTF8String])];
    }
}

+ (NSString*)fileNameForURL:(NSURL*)url ofType:(int)aType {
   if ([url isFileURL]) {
      return [url.path lastPathComponent];
   } else {
      const char *ext = "gif";
      switch (aType) {
         case VIDEO_PNG:
            ext = "png";
            break;
      }
      
      return [NSString stringWithFormat:@"%@-%@", [[url.path lastPathComponent] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], doMD5WithExt([[url absoluteString] UTF8String], ext)];
   }
}

static NSString *addPath(NSString *name, NSString* folder)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    if (folder)
        return [NSString stringWithFormat:@"%@/%@/%@", documentsDirectory, folder, name];
    else
        return [NSString stringWithFormat:@"%@/%@", documentsDirectory, name];
}

- (NSString*)fileNameWithPath {
    return addPath(self.storedID, nil);
}

- (BOOL)ensureStored:(DynamicCache*)receivedData withType:(int)videoType
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    // Just write to the file
    NSString *storedName = [CDAnimInfo fileNameForURL:self.parsedURL ofType:videoType];
    NSString *fname = [NSString stringWithFormat:@"%@/%@", documentsDirectory, storedName];
    
    bool ok = DynamicCache_dumpToFile(receivedData, [fname UTF8String]);
    
    if (!ok)
        return false;
    
    self.storedID = storedName;
    
    // Thumb too...
    return [self saveThumb];
}

- (NSString*)storedThumbPath
{
    return addPath(self.storedThumbID, @".thumbs");
}

- (void)ensureErased
{
    if ([self.isLink boolValue])
        return;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:[self fileNameWithPath] error:nil];
    
    // Also eliminate thumb
    [fileManager removeItemAtPath:[self storedThumbPath] error:nil];
}

- (NSString*)storedFile
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [self fileNameWithPath];
    if ([fileManager fileExistsAtPath:path]) {
        return path;
    }
    
    return NULL;
}

static bool sDidCheckThumbDir=false;

+ (void)ensureThumbDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *thumbDirectory = [paths objectAtIndex:0];
    
    thumbDirectory = [thumbDirectory stringByAppendingPathComponent:@".thumbs"];
    NSError *error = nil;
    if (![fileManager contentsOfDirectoryAtPath:thumbDirectory error:&error])
        [fileManager createDirectoryAtPath:thumbDirectory withIntermediateDirectories:false attributes:nil error:nil];
    
    sDidCheckThumbDir = YES;
}

- (BOOL)saveThumb
{
    if (image == nil || self.storedThumbID != nil)
        return false;
    
    NSString *idStr = [self.objectID.URIRepresentation absoluteString];
    self.storedThumbID = [NSString stringWithFormat:@"%@.png", doMD5([[NSString stringWithFormat:@"%@-%i", [self.parsedURL absoluteString], idStr] UTF8String])];
    
    NSString *thumbPath = [self storedThumbPath];
    
    if (!sDidCheckThumbDir)
    {
        [CDAnimInfo ensureThumbDirectory];
    }
    
    NSData *dat = UIImagePNGRepresentation(image);
    BOOL saved = [dat writeToFile:thumbPath atomically:YES];
    
    if (!saved)
        self.storedThumbID = nil;
    
    return saved;
}

- (void)loadThumb
{
    if ([self.isLink boolValue] || image)
        return;
    
    NSString *thumbPath = [self storedThumbPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:thumbPath]) {
        image = [[UIImage imageWithContentsOfFile:thumbPath] retain];
    }
}

- (void)setThumb:(UIImage*)img
{
    if (image)
        [image release];
    image = [img retain];
}

- (UIImage*)image
{
    if (image)
        return image;
    else if (self.storedThumbID != nil) {
        [self loadThumb];
        
        if (image == nil)
            self.storedThumbID = nil;
        
        return image;
    }
    
    return nil;
}

- (void)clearCache
{
    if (image) {
        [image release];
        image = nil;
    }
}

- (void)dealloc
{
    [self clearAttrCache];
    [super dealloc];
}

@end
