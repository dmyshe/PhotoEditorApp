//
//  BlurWrapper.m
//  CrossPlatformPhotoApp
//
//  Created by Дмитро  on 13/06/22.
//

#import "BlurWrapper.h"
#import "../GausianBlur/include/Blur.h"

@implementation BlurWrapper

- (NSImage*)proceedImage:(NSString*)strPath value:(int)value {
    Blur blur;
    blur.setSource([strPath UTF8String]);
    blur.setBlurAmount(value);
    
    std::vector<uint8_t> vectorArray = blur.dataChanged();
    
    const int bytesPerRow = blur.getCols() * blur.getChannels();

    const size_t size = vectorArray.size();
   
    unsigned char * reverse = new unsigned char[size];
    
    for (int i = 0; i < size; i+=3)
    {
        unsigned char r = vectorArray[i];
        unsigned char g = vectorArray[i + 1];
        unsigned char b = vectorArray[i + 2];
        
        reverse[i] = b;
        reverse[i + 1] = g;
        reverse[i + 2] = r;
    }
    
    
//    NSData *nsdata = [NSData dataWithBytes: &reverse length: sizeof(&reverse[0]) * size];
//    NSImage* image = [[NSImage alloc] initWithData: nsdata];

    
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
                                initWithBitmapDataPlanes:(unsigned char **)&reverse
                                pixelsWide: blur.getCols()
                                pixelsHigh: blur.getRows()
                                bitsPerSample:8
                                samplesPerPixel: blur.getChannels()
                                hasAlpha:NO
                                isPlanar:NO
                                colorSpaceName:NSDeviceRGBColorSpace
                                bytesPerRow: bytesPerRow
                                bitsPerPixel:8 * blur.getChannels()];

    NSImage* image = [[NSImage alloc]init];
    [image addRepresentation:bitmap];

    return image;
}

@end
