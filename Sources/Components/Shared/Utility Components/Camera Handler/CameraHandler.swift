//
//  CameraHandler.swift
//  CometChatUIKit
//
//  Created by CometChat Inc. on 23/10/19.
//  Copyright © 2022 CometChat Inc. All rights reserved.
//

import Foundation
import UIKit
import Photos

class CameraHandler: NSObject{
    static let shared = CameraHandler()
    
    fileprivate var currentVC: UIViewController!
    
    //MARK: Internal Properties
    
    var imagePickedBlock: ((String) -> Void)?
    var videoPickedBlock: ((String) -> Void)?
    func presentCamera(for view: UIViewController)
    {
        currentVC = view
        if UIImagePickerController.isSourceTypeAvailable(.camera){
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self;
            myPickerController.sourceType = .camera
            currentVC.present(myPickerController, animated: true, completion: nil)
        }
        
    }
    
    let myPickerController = UIImagePickerController()
    
    func presentPhotoLibrary(for view: UIViewController)
    {
        currentVC = view
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .authorized:
            DispatchQueue.main.async { [weak self] in // wrap UI updates in a main thread block
                guard let self = self else { return }
                self.myPickerController.delegate = self;
                self.myPickerController.sourceType = .photoLibrary
                self.myPickerController.mediaTypes = ["public.image", "public.movie"]
                self.currentVC.present(self.myPickerController, animated: true, completion: nil)
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ [weak self] newStatus in
                if newStatus == PHAuthorizationStatus.authorized {
                    DispatchQueue.main.async { [weak self] in // wrap UI updates in a main thread block
                        guard let self = self else { return }
                        self.myPickerController.delegate = self;
                        self.myPickerController.sourceType = .photoLibrary
                        self.myPickerController.mediaTypes = ["public.image", "public.movie"]
                        self.currentVC.present(self.myPickerController, animated: true, completion: nil)
                    }
                } else {
                    self?.showPermissionAlert(title: "Access Denied", message: "Please grant access to your photo library in Settings")
                }
            })
        default:
            showPermissionAlert(title: "Access Denied", message: "Please grant access to your photo library in Settings")
        }
    }
    
    func showPermissionAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(settingsAction)
            alertController.addAction(cancelAction)
            self?.currentVC.present(alertController, animated: true, completion: nil)
        }
    }
    
    func showActionSheet(vc: UIViewController) {
        currentVC = vc
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Gallery", style: .default, handler: { (alert:UIAlertAction!) -> Void in
            self.presentPhotoLibrary(for: vc)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "CANCEL".localize(), style: .cancel, handler: nil))
        vc.view.tintColor = CometChatTheme.palatte?.primary
        vc.present(actionSheet, animated: true, completion: nil)
    }
}


extension CameraHandler: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        currentVC.dismiss(animated: true, completion: nil)
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        switch picker.sourceType {
        case .photoLibrary:
            
            if let  videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL {
                self.videoPickedBlock?(videoURL.absoluteString ?? "")
            }
            
            if let imageURL = info[UIImagePickerController.InfoKey.imageURL] as? NSURL {
                self.imagePickedBlock?(imageURL.absoluteString ?? "")
            }
        case .camera:
            guard
                let image = info[.originalImage] as? UIImage
            else {
                return
            }
            let fixedImage = image.fixOrientation()
            saveImage(imageName: "image_\(Int(Date().timeIntervalSince1970 * 100)).png", image: fixedImage)
        case .savedPhotosAlbum:
            self.imagePickedBlock?("\(String(describing: info[UIImagePickerController.InfoKey.imageURL]!))")
        @unknown default:
            break
        }
        currentVC.dismiss(animated: true, completion: nil)
    }
    
    func saveImage(imageName: String, image: UIImage) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileName = imageName
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 1) else { return }
        
        //Checks if file exists, removes it if so.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(atPath: fileURL.path)
               
            } catch let removeError {
               
            }
        }
        do {
            try data.write(to: fileURL)
            let path = self.getImagePathFromDiskWith(fileName: fileName)
            if let imagePath = path {
                self.imagePickedBlock?(imagePath.absoluteString)
            }
        } catch let error {
           
        }
    }
    
    
    func getImagePathFromDiskWith(fileName: String) -> URL? {
        let documentDirectory = FileManager.SearchPathDirectory.documentDirectory
        let userDomainMask = FileManager.SearchPathDomainMask.userDomainMask
        let paths = NSSearchPathForDirectoriesInDomains(documentDirectory, userDomainMask, true)
        if let dirPath = paths.first {
            let imageUrl = URL(fileURLWithPath: dirPath).appendingPathComponent(fileName)
            return imageUrl
        }
        return nil
    }
    
    func getAllMetadata(from image: UIImage) -> [String: Any]? {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }
        
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        for (key, value) in imageProperties {
                    print("\(key): \(value)")
                }
        
        return imageProperties
    }

    
}


public extension UIImage {
    
    /// Extension to fix orientation of an UIImage without EXIF
    func fixOrientation() -> UIImage {
        
        guard let cgImage = cgImage else { return self }
        
        if imageOrientation == .up { return self }
        
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
            
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat(Double.pi))
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat(Double.pi/2))
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat(-Double.pi/2))
            
        case .up, .upMirrored:
            break
        }
        
        switch imageOrientation {
            
        case .upMirrored, .downMirrored:
            transform.translatedBy(x: size.width, y: 0)
            transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform.translatedBy(x: size.height, y: 0)
            transform.scaledBy(x: -1, y: 1)
            
        case .up, .down, .left, .right:
            break
        }
        
        if let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: cgImage.colorSpace!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            
            ctx.concatenate(transform)
            
            switch imageOrientation {
                
            case .left, .leftMirrored, .right, .rightMirrored:
                ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
                
            default:
                ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            }
            
            if let finalImage = ctx.makeImage() {
                return (UIImage(cgImage: finalImage))
            }
        }
        
        // something failed -- return original
        return self
    }
}
