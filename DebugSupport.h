//
//  DebugSupport.h
//  iC64
//
//  Created by Stuart Carnie on 1/30/09.

#ifdef DEBUG
#import <Foundation/Foundation.h>


@interface DebugSupport : NSObject<UIAlertViewDelegate> {
	BOOL waiting;
}

+ (void)waitForDebugger;

@end
#endif
