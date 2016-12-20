//
//  SlavePlayerView.m
//  webplay
//
//  Created by James Urquhart on 24/11/2010.
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

#import "SlavePlayerView.h"
#import "Video.h"


@implementation SlavePlayerView

- (void)setVideo:(Video*)theVideo {
    if (video) {
        [video release];
    }
    video = [theVideo retain];
    
    if (!theVideo)
        return;
    
    float scale[2];
    [video frameClipScale:scale];
    
    // set width and height scale
    sx = 2.0;
    sy = 3.0;
    t_rot = rot;
    rot = 0.0;
    t_sx = sx;
    t_sy = sy;
    tex_sx = scale[0];
    tex_sy = scale[1];
    
    [self setAspectScale:YES];
    gotVideoFrame = NO;
}

/*
// TODO: port this code over to the normal display code
- (void)setAspectScale:(bool)force
{
    [self clearAspectScale];
    CGSize bounds = self.bounds.size;
    CGSize fSize = [video frameSize];
    
    float frame_size[2];
    {
        frame_size[0] = fSize.width;
        frame_size[1] = fSize.height;
    }
    
    float src_ratio = frame_size[1] / frame_size[0]; // height / width == widths to height
    //float base_scale = 1.0;
    float dest_ratio = bounds.height / bounds.width; // height / width == widths to height
    
    float dest_to_x = t_sx / bounds.width;
    float dest_to_y = t_sy / bounds.height;
  
    
    if (src_ratio > dest_ratio) {
        // src is longer than dest, so shrink x and y accordingly
        
        // Basically we resize y to bounds.height
        float y_to_bounds_y = bounds.height / frame_size[1];
        t_sy = frame_size[1] * y_to_bounds_y;
        t_sx = t_sy / src_ratio;
        
        if (t_sx > bounds.width) {
            float correct_downscale = bounds.width / t_sx;
            //t_sx *= correct_downscale;
            t_sy *= correct_downscale;
        }
        
        t_sx *= dest_to_x;
        t_sy *= dest_to_y;
    } else {
        // src is shorter than dest, so grow x and y accordingly
        
        // Basically we resize x to bounds.width
        float x_to_bounds_x = bounds.width / frame_size[0];
        t_sx = frame_size[0] * x_to_bounds_x;
        t_sy = t_sx * src_ratio;
        
        if (t_sy > bounds.height) {
            float correct_downscale = bounds.height / t_sy;
            t_sx *= correct_downscale;
            t_sy *= correct_downscale;
        }
        
        t_sx *= dest_to_x;
        t_sy *= dest_to_y;
    }
    
    if (force) {
        sx = t_sx;
        sy = t_sy;
        rot = t_rot;
        d_rot = 0.0;
        d_sx = 0.0;
        d_sy = 0.0;
    } else {
        d_rot = (t_rot - rot) / 25.0;
        d_sx = (t_sx - sx) / 25.0;
        d_sy = (t_sy - sy) / 25.0;
    }
   
}
*/
/*
- (void)clearAspectScale
{
    //CGRect frame = self.bounds;
    
    // 2.0,3.0 is the coordinate space of the view
    t_sx = 2.0;
    t_sy = 3.0;
    t_rot = 0.0;
    
    d_rot = (t_rot - rot) / 25.0;
    d_sx = (t_sx - sx) / 25.0;
    d_sy = (t_sy - sy) / 25.0;
}
*/

- (void)dealloc {
    [super dealloc];
}

@end
