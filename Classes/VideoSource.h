//
// VideoSource.h
// webplay
//
// Created by James Urquhart on 07/03/2009.
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

typedef enum
{
    VIDEOSOURCE_DYNAMICCACHE = 0,
    VIDEOSOURCE_FILE = 1
} VideoSourceType;

// Dynamic cache. Basically this first loads stuff into memory then dumps it to disk to save memory
typedef struct DynamicCache
{
	char *data;    // current cache frame
    int dataSize;
	int cachePos;  // offset of data for cache
	int cacheSize; // cache size
	
    char *filename; // file cache filename to write to if cache overflows
	FILE *cacheRead;  // file cache will be read from
    FILE *cacheWrite; // file cache will be written to
    
    int retainCount;
} DynamicCache;

DynamicCache* DynamicCache_initWithData(NSData *data, const char *filename);
DynamicCache* DynamicCache_init(int cacheSize, const char *filename);
void DynamicCache_retain(DynamicCache *cache);
void DynamicCache_release(DynamicCache *cache);
bool DynamicCache_dumpToFile(DynamicCache *cache, const char *filename);


typedef struct VideoSource {
    VideoSourceType type;
    void *ptr;
    int pos;
    int last_pos;
    bool dirty;
    int retain;
    bool writeable;
    bool didEOF;
   
    int size;
   
    bool trackBytes;
    int expectedBytes;
   
    void *user_ptr;
} VideoSource;

VideoSource* VideoSource_init(void *in_ptr, VideoSourceType type);
void VideoSource_release(VideoSource *src);

void VideoSource_seek(VideoSource *src, int pos);
int VideoSource_seekread(VideoSource *src, int pos);
int VideoSource_read(VideoSource *src, unsigned char *destBytes, int bytes);
int VideoSource_append(VideoSource *src, char *srcBytes, int bytes);
int VideoSource_appendData(VideoSource *src, NSData *data);
void VideoSource_finishedBytes(VideoSource *src);

void VideoSource_rewind(VideoSource *src);
int VideoSource_lastread(VideoSource *src);

void VideoSource_startBytes(VideoSource *src);
void VideoSource_endBytes(VideoSource *src);
bool VideoSource_waitforbytes(VideoSource *src);
bool VideoSource_bytesready(VideoSource *src);

bool VideoSource_eof(VideoSource *src);
