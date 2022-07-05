//
//  BlurWrapper.m
//  CrossPlatformPhotoApp
//
//  Created by Дмитро  on 13/06/22.
//

#import "BlurWrapper.h"
#import "../GausianBlur/include/Blur.h"

@interface BlurWrapper()
@property Blur* blur;
@end

@implementation BlurWrapper

- (instancetype)init {
    self = [super init];
    
    if (self != nil) {
        _blur = new Blur();
    }
    
    return self;
}

- (NSImage*)proceedImage:(NSString*)strPath value:(int)value {
    _blur->setSource([strPath UTF8String]);
    _blur->setBlurAmount(value);
    
    std::vector<uint8_t> vectorArray = _blur->dataChanged();
    
    const int bytesPerRow = _blur->getCols() * _blur->getChannels();
    
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
    
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
                                initWithBitmapDataPlanes:(unsigned char **)&reverse
                                pixelsWide: _blur->getCols()
                                pixelsHigh: _blur->getRows()
                                bitsPerSample:8
                                samplesPerPixel: _blur->getChannels()
                                hasAlpha:NO
                                isPlanar:NO
                                colorSpaceName:NSDeviceRGBColorSpace
                                bytesPerRow: bytesPerRow
                                bitsPerPixel:8 * _blur->getChannels()];
    
    NSImage* image = [[NSImage alloc]init];
    [image addRepresentation:bitmap];
    
    return image;
}


@end
