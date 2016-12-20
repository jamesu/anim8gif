//
//  PngVideo.h
//  webplay
//
//  Created by Stuart Urquhart on 16/04/2012.
//
// (C) James S Urquhart 2012 - 2016
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


#import "Video.h"
#import "VideoWorker.h"

#include "png.h"

@interface PngVideo : Video {
   // png state
   png_structp pngfile;
   png_infop pnginfo;
   int transindex;
   int disposal;
   bool trans;
   
   float currentTime;
   
   bool inError;
   bool readFirstImage;
   
   int rowbytes;
   int png_width, png_height;
   png_uint_32     plays;
   unsigned int    frames;
   unsigned int    current_frame;
   unsigned int    first;
   int anim;
   
   bool bestQuality;
   bool readingFrame;
}

// Overrides
- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx;
- (void)frameClipScale:(float*)scale;
- (CGSize)frameSize;

- (bool)drawFrame:(VideoWorkerFrame_t*)frame andDisposal:(bool)updateDisposal;
- (void)flushState;

- (void)setError;

@end
