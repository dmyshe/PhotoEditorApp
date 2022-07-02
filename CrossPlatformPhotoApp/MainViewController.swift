//
//  ViewController.swift
//  MultiplatformPhotoApp
//
//  Created by Дмитро  on 06/06/22.
//

import Cocoa
import RxSwift

class MainViewController: NSViewController {
    //MARK: - IBOutlets
    @IBOutlet weak var openButton: NSButton!
    @IBOutlet weak var saveButton: NSButton!
    @IBOutlet weak var resetImageModificationButton: NSButton!
    @IBOutlet weak var imageComparisonButton: NSButton!
    @IBOutlet weak var photoImageView: NSImageView!
    @IBOutlet weak var photoImageBlurLevelSlider: NSSlider!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var photoImageEffectView: NSVisualEffectView!
    @IBOutlet weak var blurLevelLabel: NSTextField!
    
    // MARK: - OperationQueues and Operations
    private var imageBlurringOperationQueue = OperationQueue()
    private var backgroundBluringOperation: ImageProcessor?
    private var photoImageBluringOperation: ImageProcessor?
   
    //MARK: - Other Properties
    private var imageURL: URL?
    private var copiedBlurredImageLayer: CALayer?
    
    //MARK: - RxSwift
    private var bag = DisposeBag()
    private var sliderValue = PublishSubject<Int>()
    private var imageComparisonValue = PublishSubject<Int>()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindUI()
    }
    
    //MARK: -IBActions
    @IBAction func openPhotoImage(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.begin { [weak self] result in
            if result == .OK, let url = openPanel.url {
                self?.checkIfNeedToResetUI()
                self?.imageURL = url
                self?.prepareUIForScene()
            }
        }
    }
    
    @IBAction func savePhotoImage(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        savePanel.showsResizeIndicator = true
        savePanel.showsHiddenFiles = false
        savePanel.allowedFileTypes = ["png", "jpeg"]
        savePanel.title = "Choose photo destination"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let image = self.photoImageView.layer?.contents as? NSImage
            
            guard let tiffRep = image?.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffRep) else { return }
            
            let pngData = bitmapImage.representation(using: .png, properties: [:])
            try? pngData?.write(to: url,options: [.atomic])
        }
    }
    
    @IBAction func changeBlurForPhotoImage(_ sender: NSSlider) {
        sliderValue.onNext(sender.integerValue)
    }
    
    @IBAction func resetImageModification(sender: NSButton) {
        sliderValue.onNext(0)
        photoImageBlurLevelSlider.intValue = 0
    }
    
    @IBAction func showOriginalImage(sender: NSButton) {
        self.copiedBlurredImageLayer = photoImageView.layer
        
        guard let imageURL = imageURL, let originalImage = NSImage(contentsOf: imageURL) else {
            return
        }

        setupLayerForView(photoImageView, cornerRadius: 10, imageContent: originalImage)
    }
    
    //MARK: - Methods
    private func setPhotoImageView() {
        guard let url = self.imageURL else { return }
        
        let foregroundImageLoader = ImageProcessor(imagePath: url.path, blurValue: 0)
        foregroundImageLoader.onImageProcced = { [weak self] image in
            guard let image = image , let self = self  else { return }
            
            self.setupLayerForView(self.photoImageView,
                                    cornerRadius: 10,
                                   imageContent: image)

            self.enableSpinner(false)
            self.saveButton.isEnabled = true
        }
        
        self.photoImageBluringOperation = foregroundImageLoader
        
        guard let backGroundLoader = backgroundBluringOperation else { return }
        
        foregroundImageLoader.addDependency(backGroundLoader)
        imageBlurringOperationQueue.addOperation(foregroundImageLoader)
    }
    
    private func applyBlurForBackgroundImage() {
        guard let url = self.imageURL else { return }
        
        backgroundBluringOperation = ImageProcessor(imagePath: url.path, blurValue: 40)
        
        backgroundBluringOperation?.onImageProcced = { [weak self] image in
            guard let image = image, let self = self else { return  }
            self.setupLayerForView(self.view,imageContent: image)
            self.backgroundBluringOperation = nil
        }
        imageBlurringOperationQueue.addOperation(backgroundBluringOperation!)
    }
    
    private func applyBlurToImage(by value: Int) {
        guard let url = self.imageURL else { return }
        
        let blurOperation = ImageProcessor(imagePath: url.path, blurValue: value)
        blurOperation.onImageProcced = { [weak self] image in
            guard let image = image , let self = self else { return }
            self.setupLayerForView(self.photoImageView, cornerRadius: 10,imageContent: image)
        }
        
        if let prevOperation = self.photoImageBluringOperation, !prevOperation.isCancelled {
            self.photoImageBluringOperation = blurOperation
            guard blurOperation.blurValue != prevOperation.blurValue else {
                return
            }
        }
        
        self.imageBlurringOperationQueue.cancelAllOperations()
        self.imageBlurringOperationQueue.addOperation(blurOperation)
        
        self.enableSpinner(false)
        self.blurLevelLabel.isHidden = true
    }
    
    private func enableSpinner(_ status: Bool) {
        self.progressIndicator.isHidden = !status
        status ? self.progressIndicator.startAnimation(nil) : self.progressIndicator.stopAnimation(nil)
    }

    private func prepareUIForScene() {
        self.applyBlurForBackgroundImage()
        self.setPhotoImageView()
        
        self.photoImageBlurLevelSlider.isHidden = false
        self.progressIndicator.isHidden = false
        self.progressIndicator.startAnimation(self)
    }
    
    private func setupLayerForView(_ view: NSView, cornerRadius: CGFloat = 0, imageContent: NSImage) {
        let layer = CALayer()
        layer.cornerRadius = cornerRadius
        layer.contentsGravity = .resizeAspectFill
        layer.contents = imageContent
        view.layer = layer
    }
    
    private func checkIfNeedToResetUI() {
        if imageURL != nil {
            photoImageView.layer = nil
            view.layer = nil
            photoImageBlurLevelSlider.intValue = 0
            backgroundBluringOperation = nil
            photoImageBluringOperation = nil
        }
    }
    
    private func setupUI() {
        photoImageEffectView.alphaValue = 0.9
        photoImageView.wantsLayer = true
        view.wantsLayer = true
        
        imageComparisonButton.isContinuous = true
    }
    
    private func bindUI() {
        sliderValue
            .debounce(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] value in
                guard let self = self else { return }
                self.applyBlurToImage(by: value)
                self.showOnScreenResetAndComparisonButton()
            })
            .disposed(by: bag)
        
        sliderValue
            .subscribe { [weak self] value in
                guard let self = self else { return }
                self.blurLevelLabel.isHidden = false
                self.enableSpinner(true)
                self.blurLevelLabel.stringValue =
                "\(Int(Double(value.element ?? 0) / 100 * 100))%"
            }
            .disposed(by: bag)
        
        sliderValue
            .filter { $0 == 0 }
            .subscribe { [weak self] value in
                guard let self = self else { return }
                self.resetImageModificationButton.isHidden = true
            }
            .disposed(by: bag)
    }
    
    private func showOnScreenResetAndComparisonButton() {
        resetImageModificationButton.isHidden = false
        resetImageModificationButton.isEnabled = true
        
        imageComparisonButton.isHidden = false
        imageComparisonButton.isEnabled = true
    }

}
