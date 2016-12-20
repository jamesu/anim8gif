//
//  VideoTexture.h
//  webplay
//
//  Created by James Urquhart on 03/03/2009.
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
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

typedef struct VideoTexture {
    GLuint tex;
    GLint format;
    int width;
    int height;
    
    int size;
    char *data;
} VideoTexture;

extern void VideoTexture_filter(GLint filter);

extern VideoTexture* VideoTexture_init(int width, int height, GLint fmt);
extern void VideoTexture_release(VideoTexture *tex);

extern bool VideoTexture_lock(VideoTexture *tex);
extern bool VideoTexture_unlock(VideoTexture *tex);
extern bool VideoTexture_load(VideoTexture *tex);

extern bool VideoTexture_compressed(GLint fmt);
extern int VideoTexture_sizeOfTexture(GLint format, int width, int height, int mipmaplevels);

