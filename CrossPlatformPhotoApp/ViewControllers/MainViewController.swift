//
//  MainViewController.swift
//  MultiplatformPhotoApp
//
//  Created by Дмитро  on 06/06/22.
//

import Cocoa
import RxSwift
import RxCocoa

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
    private var backgroundImageBluringOperation: ImageProcessor?
    private var photoImageBluringOperation: ImageProcessor?
    
    //MARK: - Other Properties
    private var imageURL: URL? {
        didSet {
            checkIfNeedToResetUI()
            prepareUIOnScreen()
        }
    }
    
    private var copiedBlurredImageLayer: CALayer?
    
    //MARK: - RxSwift
    private var bag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindUI()
    }
    
    //MARK: - IBActions
    @IBAction func openPhotoImage(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.begin { [weak self] result in
            if result == .OK, let url = openPanel.url {
                self?.imageURL = url
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
    
    @IBAction func resetImageModification(sender: NSButton) {
        photoImageBlurLevelSlider.intValue = 0
    }
    
    @IBAction func showOriginalImage(sender: NSButton) {
        self.copiedBlurredImageLayer = photoImageView.layer
        
        guard let imageURL = imageURL, let originalImage = NSImage(contentsOf: imageURL) else {
            return
        }
        
        setupLayerForView(photoImageView, cornerRadius: 10,
                          imageContent: originalImage)
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
            self.showAndAnimateProgressIndicator(false)
            self.saveButton.isEnabled = true
        }
        
        self.photoImageBluringOperation = foregroundImageLoader
        
        guard let backGroundLoader = backgroundImageBluringOperation else { return }
        
        foregroundImageLoader.addDependency(backGroundLoader)
        imageBlurringOperationQueue.addOperation(foregroundImageLoader)
    }
    
    private func applyBlurForBackgroundImage() {
        guard let url = self.imageURL else { return }
        
        let backgroundBluringOperation = ImageProcessor(imagePath: url.path, blurValue: 40)
        
        backgroundBluringOperation.onImageProcced = { [weak self] image in
            guard let image = image, let self = self else { return  }
            self.setupLayerForView(self.view,imageContent: image)
            self.backgroundImageBluringOperation = nil
        }
        self.backgroundImageBluringOperation = backgroundBluringOperation
        
        imageBlurringOperationQueue.addOperation(backgroundBluringOperation)
    }
    
    private func applyBlurToImage(by value: Int) {
        guard let url = self.imageURL else { return }
        
        let blurOperation = ImageProcessor(imagePath: url.path, blurValue: value)
        blurOperation.onImageProcced = { [weak self] image in
            guard let image = image , let self = self else { return }
            self.setupLayerForView(self.photoImageView, cornerRadius: 10,imageContent: image)
            self.showAndAnimateProgressIndicator(false)
            self.showOnScreenResetAndComparisonButton(true)
            self.blurLevelLabel.isHidden = true
        }
        
        
        if let prevOperation = self.photoImageBluringOperation, !prevOperation.isCancelled {
            self.photoImageBluringOperation = blurOperation
            guard blurOperation.blurValue != prevOperation.blurValue else {
                return
            }
        }
        
        self.imageBlurringOperationQueue.cancelAllOperations()
        self.imageBlurringOperationQueue.addOperation(blurOperation)
    }
        
    private func prepareUIOnScreen() {
        self.applyBlurForBackgroundImage()
        self.setPhotoImageView()
        
        self.photoImageBlurLevelSlider.isHidden = false
        showAndAnimateProgressIndicator(true)
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
            backgroundImageBluringOperation = nil
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
        let blurSlider = photoImageBlurLevelSlider.rx.value.changed
            .share()
            .filter { $0 != 0 }
        
        blurSlider
            .subscribe(onNext: { [weak self] value in
                guard let self = self else { return }
                self.showAndAnimateProgressIndicator(true)
                self.showBlurLevelLabel(withValue: value,
                                        status: true)
            })
            .disposed(by: bag)
        
        blurSlider
            .distinctUntilChanged()
            .debounce(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] value in
                guard let self = self else { return }
                self.applyBlurToImage(by: Int(value))
            })
            .disposed(by: bag)
    }
    
    private func showOnScreenResetAndComparisonButton(_ status: Bool) {
        resetImageModificationButton.isHidden = !status
        resetImageModificationButton.isEnabled = status
        
        imageComparisonButton.isHidden = !status
        imageComparisonButton.isEnabled = status
    }
    
    private func showAndAnimateProgressIndicator(_ status: Bool) {
        self.progressIndicator.isHidden = !status
        status ? self.progressIndicator.startAnimation(nil) : self.progressIndicator.stopAnimation(nil)
    }
    
    private func showBlurLevelLabel(withValue value: Double = 0.0, status: Bool) {
        blurLevelLabel.isHidden = status
        blurLevelLabel.stringValue =
        "\(Int(Double(value) / 100 * 100))%"
    }
}
