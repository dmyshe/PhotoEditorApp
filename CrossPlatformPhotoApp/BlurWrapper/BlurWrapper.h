//
//  BlurWrapper.h
//  CrossPlatformPhotoApp
//
//  Created by Дмитро  on 13/06/22.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BlurWrapper : NSObject
- (NSImage*)proceedImage:(NSString*)strPath value:(int)value;
@end

NS_ASSUME_NONNULL_END
