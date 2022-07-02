//
//  ImageProcessor.swift
//  CrossPlatformPhotoApp
//
//  Created by Дмитро  on 13/06/22.
//

import Foundation
import Cocoa

class ImageProcessor: Operation {
    var onImageProcced: ((NSImage?) -> Void)?
    
    var imagePath: String?
    var blurValue: Int = 0
    
    private var blurWrapper = BlurWrapper()
    
     init(imagePath: String, blurValue: Int) {
        self.imagePath = imagePath
        self.blurValue = blurValue
        super.init()
    }
    
    override func main() {
        guard let imagePath = imagePath, !isCancelled  else { return }
        
        let filteredImage = blurWrapper.proceedImage(imagePath, value: Int32(blurValue))

        guard !isCancelled else { return }
        
        if let outputImage = onImageProcced {
            DispatchQueue.main.async {
                outputImage(filteredImage)
            }
        }
    }
}
