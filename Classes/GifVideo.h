//
//  GifVideo.h
//  template
//
//  Created by James Urquhart on 27/02/2009.
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

#import <Foundation/Foundation.h>

#import "Video.h"
#import "VideoWorker.h"
#include "gif_lib.h"

@interface GifVideo : Video {
    // gif state
    GifFileType *gifinfo;
    int transindex;
    int disposal;
    bool trans;
    
    bool bestQuality;
    bool readingFrame;
    unsigned int    current_frame;
}

// Overrides
- (id)initWithSource:(VideoSource*)source inContext:(EAGLContext*)ctx;
- (void)frameClipScale:(float*)scale;
- (CGSize)frameSize;

- (bool)drawFrame:(VideoWorkerFrame_t*)current_frame andDisposal:(bool)updateDisposal;
- (void)flushState;

@end
