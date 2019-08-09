//
//  ViewController.swift
//  StyleTrasfer
//
//  Created by Jasmin Patel on 30/04/19.
//  Copyright © 2019 Simform. All rights reserved.
//

import UIKit
import CoreML
import AVKit
import Fritz
import AVFoundation
func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage? {
    
    let scale = newWidth / image.size.width
    let newHeight = image.size.height * scale
    UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
    image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage
}
struct StyleData {
    var image: UIImage {
        didSet {
            if let resizedImage = resizeImage(image: image, newWidth: 200) {
                self.image = resizedImage
            }
        }
    }
    static let data = [StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate")),
                       StyleData(image: #imageLiteral(resourceName: "numberplate"))]
    static let numberOfStyles: NSNumber = NSNumber(value: StyleData.data.count)
}

class StyleCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var styleImageView: UIImageView!
}

class ViewController: UIViewController {

    @IBOutlet weak var baseProgressView: UIView! {
        didSet {
            baseProgressView.isHidden = true
        }
    }
    
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBOutlet weak var sampleImageView: UIImageView!{
        didSet {
            sampleImageView.isUserInteractionEnabled = true
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressOnImageView(_:)))
            sampleImageView.addGestureRecognizer(longPressGesture)
        }
    }
    @IBOutlet weak var scrollView: UIScrollView! {
        didSet {
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = 10.0
        }
    }
    @IBOutlet var videoView: BlurredVideoView!
    
    let imagePicker = UIImagePickerController()
    
    var selectedImage = #imageLiteral(resourceName: "bitmap@3x")

    var filteredImage = #imageLiteral(resourceName: "bitmap@3x")
    
    var selectedIndex = -1
    
    let localURL: URL? = URL.init(fileURLWithPath: Bundle.main.path(forResource: "20190208151842301", ofType: "mp4")!)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        sampleImageView.image = selectedImage
        videoView.play(stream: localURL!) {
            self.videoView.player.isMuted = true
        }
    }
    
    @IBAction func chooseImage(_ sender: Any) {
        // Choose Image Here
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    var coreMLExporter = CoreMLExporter()
    @IBAction func cancelExporting(_ sender: Any) {
        DispatchQueue.main.async {
            self.baseProgressView.isHidden = true
        }
        coreMLExporter.cancelExporting()
    }
    
    @IBAction func saveImage(_ sender: Any) {
        SCAlbum.shared.save(image: filteredImage)
//        guard selectedIndex != -1 else {
//            return
//        }
//        videoView.stop()
//        self.baseProgressView.isHidden = false
//        coreMLExporter.exportVideo(for: localURL!, and: selectedIndex, progress: { progress in
//            DispatchQueue.main.async {
//                self.progressView.progress = progress
//            }
//        }, completion: { exportedURL in
//            DispatchQueue.main.async {
//                self.baseProgressView.isHidden = true
//            }
//            SCAlbum.shared.saveMovieToLibrary(movieURL: exportedURL)
//        })
    }
    
    @objc func handleLongPressOnImageView(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed {
            removeFilter()
        } else {
            applyFilter()
        }
    }
    
    func removeFilter() {
        sampleImageView.image = selectedImage
    }
    
    func applyFilter() {
        sampleImageView.image = filteredImage
    }
    
    func resizeImage(image: UIImage, scale: CGFloat) -> UIImage? {
        let size = image.size
        let targetSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize.init(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize.init(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect.init(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let maxWidth: CGFloat = image.size.width
        let maxHeight: CGFloat = image.size.height

        UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: maxHeight), true, 2.0)
        image.draw(in: CGRect(x: 0, y: 0, width: maxWidth, height: maxHeight))
        UIGraphicsEndImageContext()
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(maxWidth), Int(maxHeight), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(maxWidth), height: Int(maxHeight), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: maxHeight)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: maxWidth, height: maxHeight))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
}

extension ViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.sampleImageView
    }
    
}

extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return StyleData.data.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StyleCollectionViewCell", for: indexPath) as! StyleCollectionViewCell
        cell.styleImageView.image = StyleData.data[indexPath.row].image
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
//        guard localURL == nil else {
//            videoView.selectedIndex = selectedIndex
//            return
//        }
        
        let model = model_43styles_10000iter_2019_08_02_122155()
        
        do {
            let styles = try MLMultiArray(shape: [StyleData.numberOfStyles],
                                          dataType: .double)
            for i in 0..<styles.count {
                styles[i] = 0.0
            }
            styles[selectedIndex] = 1.0
            if let image = pixelBuffer(from: selectedImage) {
                do {
                    let predictionOutput = try model.prediction(image: image, index: styles)
                    let ciImage = CIImage(cvPixelBuffer: predictionOutput.stylizedImage)
                    let tempContext = CIContext(options: nil)
                    let tempImage = tempContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(predictionOutput.stylizedImage), height: CVPixelBufferGetHeight(predictionOutput.stylizedImage)))
                    filteredImage = UIImage(cgImage: tempImage!)
                    applyFilter()
                } catch let error as NSError {
                    print("CoreML Model Error: \(error)")
                }
            }
        } catch let error {
            print(error)
        }
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage,
            let selectedImage = self.resizeImage(image: pickedImage, scale: 800.0/pickedImage.size.width) {
            self.selectedImage = selectedImage
            sampleImageView.image = self.selectedImage
        }
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
}
