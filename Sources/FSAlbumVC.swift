//
//  FSAlbumVC.swift
//  Fusuma
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 ytakzk. All rights reserved.
//

import UIKit
import Photos


@objc public protocol FSAlbumViewDelegate: class {
    func albumViewCameraRollUnauthorized()
}

public class FSAlbumVC: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, PHPhotoLibraryChangeObserver, UIGestureRecognizerDelegate {
    
    weak var delegate: FSAlbumViewDelegate? = nil
    
    public var showsVideo = false
    var images: PHFetchResult<PHAsset>!
    var imageManager: PHCachingImageManager?
    var previousPreheatRect: CGRect = CGRect.zero
    let cellSize = CGSize(width: 100, height: 100)
    var phAsset: PHAsset!
    
    // Variables for calculating the position
    enum Direction {
        case scroll
        case stop
        case up
        case down
    }
    let imageCropViewOriginalConstraintTop: CGFloat = 0
    let imageCropViewMinimalVisibleHeight: CGFloat  = 100
    var dragDirection = Direction.up
    var imaginaryCollectionViewOffsetStartPosY: CGFloat = 0.0
    
    var cropBottomY: CGFloat  = 0.0
    var dragStartPos: CGPoint = CGPoint.zero
    let dragDiff: CGFloat     = 20.0
    
    var v:FSAlbumView!
    
    public override func loadView() {
        let bundle = Bundle(for: self.classForCoder)
        v = UINib(nibName: "FSAlbumView", bundle:bundle).instantiate(withOwner: self, options: nil)[0] as! FSAlbumView
        view = v
    }
    
    convenience init() {
        self.init(nibName:nil, bundle:nil)
        title = "Bibliothèque"
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        v.collectionView.dataSource = self
        v.collectionView.delegate = self
        initialize()
    }

    func initialize() {
        if images != nil {
            return
        }
        
        let panGesture      = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        panGesture.delegate = self
        v.addGestureRecognizer(panGesture)
        
        v.collectionViewConstraintHeight.constant = v.frame.height - v.imageCropView.frame.height - imageCropViewOriginalConstraintTop
        v.imageCropViewConstraintTop.constant = 0
        dragDirection = Direction.up
        
        v.imageCropViewContainer.layer.shadowColor   = UIColor.black.cgColor
        v.imageCropViewContainer.layer.shadowRadius  = 30.0
        v.imageCropViewContainer.layer.shadowOpacity = 0.9
        v.imageCropViewContainer.layer.shadowOffset  = CGSize.zero
        
        
        v.collectionView.register(FSAlbumViewCell.self, forCellWithReuseIdentifier: "FSAlbumViewCell")
        //		collectionView.backgroundColor = fusumaBackgroundColor
        
        // Never load photos Unless the user allows to access to photo album
        checkPhotoAuth()
        
        // Sorting condition
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        images = PHAsset.fetchAssets(with: options)
        
        if images.count > 0 {
            changeImage(images[0])
            v.collectionView.reloadData()
            v.collectionView.selectItem(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: UICollectionViewScrollPosition())
        }
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func panned(_ sender: UITapGestureRecognizer) {
        
        if sender.state == UIGestureRecognizerState.began {
            let view    = sender.view
            let loc     = sender.location(in: view)
            let subview = view?.hitTest(loc, with: nil)
            
            if subview == v.imageCropView && v.imageCropViewConstraintTop.constant == imageCropViewOriginalConstraintTop {
                return
            }
            
            dragStartPos = sender.location(in: v)
            cropBottomY = v.imageCropViewContainer.frame.origin.y + v.imageCropViewContainer.frame.height
            
            // Move
            if dragDirection == Direction.stop {
                dragDirection = (v.imageCropViewConstraintTop.constant == imageCropViewOriginalConstraintTop) ? Direction.up : Direction.down
            }
            
            // Scroll event of CollectionView is preferred.
            if (dragDirection == Direction.up   && dragStartPos.y < cropBottomY + dragDiff) ||
                (dragDirection == Direction.down && dragStartPos.y > cropBottomY) {
                dragDirection = Direction.stop
                v.imageCropView.changeScrollable(false)
            } else {
                v.imageCropView.changeScrollable(true)
            }
        } else if sender.state == UIGestureRecognizerState.changed {
            let currentPos = sender.location(in: v)
            if dragDirection == Direction.up && currentPos.y < cropBottomY - dragDiff {
                v.imageCropViewConstraintTop.constant = max(imageCropViewMinimalVisibleHeight - v.imageCropViewContainer.frame.height, currentPos.y + dragDiff - v.imageCropViewContainer.frame.height)
                v.collectionViewConstraintHeight.constant = min(v.frame.height - imageCropViewMinimalVisibleHeight, v.frame.height - v.imageCropViewConstraintTop.constant - v.imageCropViewContainer.frame.height)
            } else if dragDirection == Direction.down && currentPos.y > cropBottomY {
                v.imageCropViewConstraintTop.constant = min(imageCropViewOriginalConstraintTop, currentPos.y - v.imageCropViewContainer.frame.height)
                v.collectionViewConstraintHeight.constant = max(v.frame.height - imageCropViewOriginalConstraintTop - v.imageCropViewContainer.frame.height, v.frame.height - v.imageCropViewConstraintTop.constant - v.imageCropViewContainer.frame.height)
            } else if dragDirection == Direction.stop && v.collectionView.contentOffset.y < 0 {
                dragDirection = Direction.scroll
                imaginaryCollectionViewOffsetStartPosY = currentPos.y
            } else if dragDirection == Direction.scroll {
                v.imageCropViewConstraintTop.constant = imageCropViewMinimalVisibleHeight - v.imageCropViewContainer.frame.height + currentPos.y - imaginaryCollectionViewOffsetStartPosY
                v.collectionViewConstraintHeight.constant = max(v.frame.height - imageCropViewOriginalConstraintTop - v.imageCropViewContainer.frame.height, v.frame.height - v.imageCropViewConstraintTop.constant - v.imageCropViewContainer.frame.height)
                
            }
            
        } else {
            imaginaryCollectionViewOffsetStartPosY = 0.0
            if sender.state == UIGestureRecognizerState.ended && dragDirection == Direction.stop {
                v.imageCropView.changeScrollable(true)
                return
            }
            
            let currentPos = sender.location(in: v)
            
            if currentPos.y < cropBottomY - dragDiff && v.imageCropViewConstraintTop.constant != imageCropViewOriginalConstraintTop {
                // The largest movement
                v.imageCropView.changeScrollable(false)
                v.imageCropViewConstraintTop.constant = imageCropViewMinimalVisibleHeight - v.imageCropViewContainer.frame.height
                v.collectionViewConstraintHeight.constant = v.frame.height - imageCropViewMinimalVisibleHeight
                
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    self.v.layoutIfNeeded()
                    }, completion: nil)
                dragDirection = Direction.down
            } else {
                // Get back to the original position
                v.imageCropView.changeScrollable(true)
                v.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop
                v.collectionViewConstraintHeight.constant = v.frame.height - imageCropViewOriginalConstraintTop - v.imageCropViewContainer.frame.height
                
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                    self.v.layoutIfNeeded()
                    }, completion: nil)
                dragDirection = Direction.up
            }
        }
    }
    
    // MARK: - UICollectionViewDelegate Protocol
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FSAlbumViewCell", for: indexPath) as! FSAlbumViewCell
        let currentTag = cell.tag + 1
        cell.tag = currentTag
        
        let asset = images[(indexPath as NSIndexPath).item]
        imageManager?.requestImage(for: asset,
                                   targetSize: cellSize,
                                   contentMode: .aspectFill,
                                   options: nil) { result, info in
                                    if cell.tag == currentTag {
                                        cell.imageView.image = result
                                    }
        }
        
        
        
        if asset.mediaType == .video {
            cell.durationLabel.isHidden = false
            cell.durationLabel.text = formattedStrigFrom(asset.duration)
        } else {
            cell.durationLabel.isHidden = true
            cell.durationLabel.text = ""
        }
        
        return cell
    }
    
    func formattedStrigFrom(_ timeInterval:TimeInterval) -> String {
        let interval = Int(timeInterval)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images == nil ? 0 : images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 3) / 4
        return CGSize(width: width, height: width)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        changeImage(images[(indexPath as NSIndexPath).row])
        v.imageCropView.changeScrollable(true)
        v.imageCropViewConstraintTop.constant = imageCropViewOriginalConstraintTop
        v.collectionViewConstraintHeight.constant = v.frame.height - imageCropViewOriginalConstraintTop - v.imageCropViewContainer.frame.height
        UIView.animate(withDuration: 0.2, delay: 0.0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            self.v.layoutIfNeeded()
            }, completion: nil)
        dragDirection = Direction.up
        collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
    }
    
    // MARK: - ScrollViewDelegate
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == v.collectionView {
            updateCachedAssets()
        }
    }
    
    //MARK: - PHPhotoLibraryChangeObserver
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            let collectionChanges = changeInstance.changeDetails(for: self.images)
            if collectionChanges != nil {
                self.images = collectionChanges!.fetchResultAfterChanges
                let collectionView = self.v.collectionView!
                if !collectionChanges!.hasIncrementalChanges || collectionChanges!.hasMoves {
                    collectionView.reloadData()
                } else {
                    collectionView.performBatchUpdates({
                        let removedIndexes = collectionChanges!.removedIndexes
                        if (removedIndexes?.count ?? 0) != 0 {
                            collectionView.deleteItems(at: removedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        let insertedIndexes = collectionChanges!.insertedIndexes
                        if (insertedIndexes?.count ?? 0) != 0 {
                            collectionView.insertItems(at: insertedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        let changedIndexes = collectionChanges!.changedIndexes
                        if (changedIndexes?.count ?? 0) != 0 {
                            collectionView.reloadItems(at: changedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
                        }
                        }, completion: nil)
                }
                self.resetCachedAssets()
            }
        }
    }


    func changeImage(_ asset: PHAsset) {
        v.imageCropView.image = nil
        phAsset = asset
        DispatchQueue.global(qos: .default).async() {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            self.imageManager?.requestImage(for: asset,
                                            targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                                            contentMode: .aspectFill,
                                            options: options) { result, info in
                                                DispatchQueue.main.async() {
                                                    self.v.imageCropView.imageSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                                                    self.v.imageCropView.image = result
                                                }
            }
        }
    }
    
    // Check the status of authorization for PHPhotoLibrary
    func checkPhotoAuth() {
        PHPhotoLibrary.requestAuthorization { status  in
            switch status {
            case .authorized:
                self.imageManager = PHCachingImageManager()
                if self.images != nil && self.images.count > 0 {
                    self.changeImage(self.images[0])
                }
            case .restricted, .denied:
                DispatchQueue.main.async() {
                    self.delegate?.albumViewCameraRollUnauthorized()
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Asset Caching
    
    func resetCachedAssets() {
        imageManager?.stopCachingImagesForAllAssets()
        previousPreheatRect = CGRect.zero
    }
    
    func updateCachedAssets() {
        var preheatRect = v.collectionView!.bounds
        preheatRect = preheatRect.insetBy(dx: 0.0, dy: -0.5 * preheatRect.height)
        
        let delta = abs(preheatRect.midY - self.previousPreheatRect.midY)
        if delta > self.v.collectionView!.bounds.height / 3.0 {
            
            var addedIndexPaths: [IndexPath] = []
            var removedIndexPaths: [IndexPath] = []
            
            self.computeDifferenceBetweenRect(self.previousPreheatRect, andRect: preheatRect, removedHandler: {removedRect in
                let indexPaths = self.v.collectionView.aapl_indexPathsForElementsInRect(removedRect)
                removedIndexPaths += indexPaths
                }, addedHandler: {addedRect in
                    let indexPaths = self.v.collectionView.aapl_indexPathsForElementsInRect(addedRect)
                    addedIndexPaths += indexPaths
            })
            
            let assetsToStartCaching = self.assetsAtIndexPaths(addedIndexPaths)
            let assetsToStopCaching = self.assetsAtIndexPaths(removedIndexPaths)
            
            self.imageManager?.startCachingImages(for: assetsToStartCaching,
                                                  targetSize: cellSize,
                                                  contentMode: .aspectFill,
                                                  options: nil)
            self.imageManager?.stopCachingImages(for: assetsToStopCaching,
                                                 targetSize: cellSize,
                                                 contentMode: .aspectFill,
                                                 options: nil)
            
            self.previousPreheatRect = preheatRect
        }
    }
    
    func computeDifferenceBetweenRect(_ oldRect: CGRect, andRect newRect: CGRect, removedHandler: (CGRect)->Void, addedHandler: (CGRect)->Void) {
        if newRect.intersects(oldRect) {
            let oldMaxY = oldRect.maxY
            let oldMinY = oldRect.minY
            let newMaxY = newRect.maxY
            let newMinY = newRect.minY
            if newMaxY > oldMaxY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: oldMaxY, width: newRect.size.width, height: (newMaxY - oldMaxY))
                addedHandler(rectToAdd)
            }
            if oldMinY > newMinY {
                let rectToAdd = CGRect(x: newRect.origin.x, y: newMinY, width: newRect.size.width, height: (oldMinY - newMinY))
                addedHandler(rectToAdd)
            }
            if newMaxY < oldMaxY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: newMaxY, width: newRect.size.width, height: (oldMaxY - newMaxY))
                removedHandler(rectToRemove)
            }
            if oldMinY < newMinY {
                let rectToRemove = CGRect(x: newRect.origin.x, y: oldMinY, width: newRect.size.width, height: (newMinY - oldMinY))
                removedHandler(rectToRemove)
            }
        } else {
            addedHandler(newRect)
            removedHandler(oldRect)
        }
    }
    
    func assetsAtIndexPaths(_ indexPaths: [IndexPath]) -> [PHAsset] {
        if indexPaths.count == 0 { return [] }
        
        var assets: [PHAsset] = []
        assets.reserveCapacity(indexPaths.count)
        for indexPath in indexPaths {
            let asset = self.images[(indexPath as NSIndexPath).item]
            assets.append(asset)
        }
        return assets
    }
    
    public func selectedMedia(photo:@escaping (_ photo:UIImage) -> Void, video:@escaping (_ videoURL:URL) -> Void) {
        let view = v.imageCropView
        
        if fusumaCropImage {
            let normalizedX = (view?.contentOffset.x)! / (view?.contentSize.width)!
            let normalizedY = (view?.contentOffset.y)! / (view?.contentSize.height)!
            
            let normalizedWidth = (view?.frame.width)! / (view?.contentSize.width)!
            let normalizedHeight = (view?.frame.height)! / (view?.contentSize.height)!
            
            let cropRect = CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
            
            DispatchQueue.global(qos: .default).async() {
                
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.normalizedCropRect = cropRect
                options.resizeMode = .exact
                
                let targetWidth = floor(CGFloat(self.phAsset.pixelWidth) * cropRect.width)
                let targetHeight = floor(CGFloat(self.phAsset.pixelHeight) * cropRect.height)
                let dimension = max(min(targetHeight, targetWidth), 1024 * UIScreen.main.scale)
                
                let targetSize = CGSize(width: dimension, height: dimension)
                
                let asset = self.phAsset!
                
                if asset.mediaType == .video {
                    PHImageManager.default().requestAVAsset(forVideo: asset,
                                                            options: nil) { v, audioMix, info in
                                                                DispatchQueue.main.async() {
                                                                    let urlAsset = v as! AVURLAsset
                                                                    video(urlAsset.url)
                                                                }
                    }
                } else {
                    PHImageManager.default()
                        .requestImage(for: asset,
                                      targetSize: targetSize,
                                      contentMode: .aspectFill,
                                      options: options) { result, info in
                                        DispatchQueue.main.async() {
                                            photo(result!)
                                        }
                    }
                }
            }
        } else {
            photo(view!.image)
        }
    }
}

internal extension UICollectionView {
    
    func aapl_indexPathsForElementsInRect(_ rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)
        if (allLayoutAttributes?.count ?? 0) == 0 {return []}
        var indexPaths: [IndexPath] = []
        indexPaths.reserveCapacity(allLayoutAttributes!.count)
        for layoutAttributes in allLayoutAttributes! {
            let indexPath = layoutAttributes.indexPath
            indexPaths.append(indexPath)
        }
        return indexPaths
    }
}

internal extension IndexSet {
    
    func aapl_indexPathsFromIndexesWithSection(_ section: Int) -> [IndexPath] {
        var indexPaths: [IndexPath] = []
        indexPaths.reserveCapacity(count)
        (self as NSIndexSet).enumerate({idx, stop in
            indexPaths.append(IndexPath(item: idx, section: section))
        })
        return indexPaths
    }
}

    