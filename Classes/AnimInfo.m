//
//  AnimInfo.m
//  webplay
//
//  Created by James Urquhart on 06/03/2009.
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

#import "AnimInfo.h"
#import "RegexKitLite.h"
#import "CDAnimInfo.h"
#import "webplayAppDelegate.h"
#include <sqlite3.h>
#import <CommonCrypto/CommonDigest.h>


@implementation AnimInfo

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

+ (NSString*)storedNameForURL:(NSString*)url andId:(int)pkId
{
    NSString *str = [NSString stringWithFormat:@"%s-%i", url, pkId];
	return doMD5([str UTF8String]);
}

+ (NSString*)storedThumbNameForURL:(NSString*)url andId:(int)thumbId
{
    NSString *thumbHash = [NSString stringWithFormat:@"%s-%i", url, thumbId];
    return [NSString stringWithFormat:@"%@.th.png", doMD5([thumbHash UTF8String])];
}


+ (void)convertOldBookmarksFromLocation:(NSString*)path withDelegate:(webplayAppDelegate*)app
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    L0Log(@"convertOldBookmarks");
    NSThread *thr = app.backgroundTask;
    [CDAnimInfo ensureThumbDirectory];
    
    NSString *docsDir = [app applicationDocumentsDirectory];
    
    // Stage 1: Load database
    sqlite3 *db;
    NSManagedObjectContext *objectCtx = app.managedObjectContext;
    if (sqlite3_open([path UTF8String], &db) != SQLITE_OK) {
        L0Log(@"No DB, fail!");
        [app.config setBool:YES forKey:@"didCheckOldDB"];
        [app performSelectorOnMainThread:@selector(finishedMigrationThread) withObject:nil waitUntilDone:NO];
        [pool release];
        return;
    }
    
    int   ret;
    int   numRecords = 0;
    int   pageSaved = 0;
    int   lastPK = [app.config integerForKey:@"lastAnimInfoPK"];
    
    sqlite3_stmt *stmt;
    ret = sqlite3_prepare_v2(db,
                             [[NSString stringWithFormat:@"SELECT * FROM anim_info WHERE pk > %i", lastPK] UTF8String],
                             -1,
                             &stmt,
                             NULL);
    if (ret != SQLITE_OK) {
        [app.config setBool:YES forKey:@"didCheckOldDB"];
        [app performSelectorOnMainThread:@selector(finishedMigrationThread) withObject:nil waitUntilDone:NO];
        [pool release];
        return;
    }
    
    // Step 2: Iterate through results
    while (![thr isCancelled]) {
		ret = sqlite3_step(stmt);
		if (ret == SQLITE_DONE)
			break;
        
		if (ret == SQLITE_BUSY)
            break;
        
		if (ret == SQLITE_ROW) {
            int columnCount = sqlite3_column_count(stmt);
            NSMutableDictionary *sqlObject = [[NSMutableDictionary alloc] init];
            NSKeyedUnarchiver *unarchiver;
            NSData *data;
            for (int i = 0; i < columnCount; ++i) {
                NSString *cname = [NSString stringWithUTF8String:sqlite3_column_name(stmt, i)];
                NSObject *cdata;
                int columnType = sqlite3_column_type(stmt, i);
                
                switch (columnType)
                {
                    case SQLITE_NULL:
                        cdata = [NSNull null];
                        break;
                    case SQLITE_INTEGER:
                        cdata = [NSNumber numberWithInt:sqlite3_column_int(stmt, i)];
                        break;
                    case SQLITE_FLOAT:
                        cdata = [NSNumber numberWithDouble:sqlite3_column_double(stmt, i)];
                        break;
                    case SQLITE_TEXT:
                        cdata = [NSString stringWithUTF8String:(const char*)sqlite3_column_text(stmt, i)];
                        break;
                    case SQLITE_BLOB:
                        data = [NSData dataWithBytes:sqlite3_column_blob(stmt, i) 
                                              length:sqlite3_column_bytes(stmt, i)];
                        unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
                        cdata = [unarchiver decodeObjectForKey:@"NSURL"];
                        [unarchiver finishDecoding];
                        [unarchiver release];
                        break;
                    default:
                        cdata = NULL;
                        break;
                }
                
                [sqlObject setObject:cdata forKey:cname];
            }
            
            // Process this particular record -> CDAnimInfo
            NSFileManager *files = [NSFileManager defaultManager];
            bool neverPlayed = [[sqlObject objectForKey:@"last_play"] isKindOfClass:[NSNull class]];
            CDAnimInfo *anim = (CDAnimInfo*)[NSEntityDescription insertNewObjectForEntityForName:@"AnimInfo"
                                                                          inManagedObjectContext:objectCtx] ;
            anim.url = [[sqlObject objectForKey:@"url"] absoluteString];
            anim.dontShow = [NSNumber numberWithBool:neverPlayed];
            anim.isLink = [sqlObject objectForKey:@"is_link"];
            anim.didBookmark = [sqlObject objectForKey:@"did_bookmark"];
            
            int thumbId = [[sqlObject objectForKey:@"stored_thumb_i_d"] intValue];
            if ([anim.didBookmark boolValue]) {
                NSString *origPath, *newPath, *newName;
                // Copy filename
                origPath = [AnimInfo storedNameForURL:anim.url andId:thumbId];
                newName = [CDAnimInfo fileNameForURL:anim.parsedURL];
                newPath = [NSString stringWithFormat:@"%@/%@", docsDir, newName];
                origPath = [NSString stringWithFormat:@"%@/stored/%@", docsDir, origPath];
                
                if ([files fileExistsAtPath:origPath]) {
                    [files copyItemAtPath:origPath toPath:newPath error:nil];
                    anim.storedID = newName;
                }
                
                if (thumbId != 0) {
                    // Load thumbnail
                    origPath = [AnimInfo storedThumbNameForURL:anim.url andId:thumbId];
                    anim.storedThumbID = origPath;
                    newPath = [NSString stringWithFormat:@"%@/.thumbs/%@", docsDir, origPath];
                    origPath = [NSString stringWithFormat:@"%@/stored/%@", docsDir, origPath];
                    
                    if ([files fileExistsAtPath:origPath]) {
                        [files copyItemAtPath:origPath toPath:newPath error:nil];
                    } else {
                        anim.storedThumbID = nil;
                    }
                }
            }
            
            lastPK = [[sqlObject objectForKey:@"pk"] intValue];
            pageSaved++;
            numRecords++;
            [sqlObject release];
            
            if (pageSaved == 25) {
                pageSaved = 0;
                [app saveContext];
                [app.config setInteger:lastPK forKey:@"lastAnimInfoPK"];
            }
        }
	}
    
    [app saveContext];
    [app.config setInteger:lastPK forKey:@"lastAnimInfoPK"];
    
    // We're finished, cleanup!
    
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    
    // Stage 2: Nuke "stored" directory and old database
    if (![thr isCancelled]) {
        [app.config setBool:YES forKey:@"didCheckOldDB"];
#ifdef DB_TESTING
        [app finishedMigrationThread];
#else
        [app performSelectorOnMainThread:@selector(finishedMigrationThread) withObject:nil waitUntilDone:NO];
#endif
    }
    
    [pool release];
}


@end
