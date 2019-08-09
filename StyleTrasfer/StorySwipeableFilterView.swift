//
//  StorySwipeableFilterView.swift
//  Camera
//
//  Created by Viraj Patel on 30/10/18.
//

import UIKit
import Foundation
import CoreImage
import AVFoundation
import AVKit
import GLKit

public protocol StorySwipeableFilterViewDelegate: NSObjectProtocol {
    func swipeableFilterView(_ swipeableFilterView: StorySwipeableFilterView, didScrollTo filter: CIFilter?)
}
/**
 A filter selector view that works like the Snapchat presentation of the available filters.
 Filters are swipeable from horizontally.
 */
open class StorySwipeableFilterView: StoryImageView, UIScrollViewDelegate {
    /**
     The available filterGroups that this SCFilterSwitcherView shows
     If you want to show an empty filter (no processing), just add a [NSNull null]
     entry instead of an instance of SCFilterGroup
     */
    open var filters: [CIFilter]?
    /**
     The currently selected filter group.
     This changes when scrolling in the underlying UIScrollView.
     This value is Key-Value observable.
     */
    open var selectedFilter: CIFilter?
    /**
     A filter that is applied before applying the selected filter
     */
    var preprocessingFilter: CIFilter?
    /**
     The delegate that will receive messages
     */
    weak open var delegate: StorySwipeableFilterViewDelegate?
    /**
     The underlying scrollView used for scrolling between filterGroups.
     You can freely add your views inside.
     */
    private(set) var selectFilterScrollView: UIScrollView!
    /**
     Whether the current image should be redraw with the new contentOffset
     when the UIScrollView is scrolled. If disabled, scrolling will never
     show up the other filters, until it receives a new CIImage.
     On some device it seems better to disable it when the StorySwipeableFilterView
     is set inside a StoryPlayer.
     Default is YES
     */
    var refreshAutomaticallyWhenScrolling = false
    
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        _swipeableCommonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _swipeableCommonInit()
    }
    
    deinit {
        
    }
    
    func _swipeableCommonInit() {
        refreshAutomaticallyWhenScrolling = true
        selectFilterScrollView = UIScrollView(frame: bounds)
        selectFilterScrollView.delegate = self
        selectFilterScrollView.isPagingEnabled = true
        selectFilterScrollView.showsHorizontalScrollIndicator = false
        selectFilterScrollView.showsVerticalScrollIndicator = false
        selectFilterScrollView.bounces = true
        selectFilterScrollView.alwaysBounceHorizontal = true
        selectFilterScrollView.alwaysBounceVertical = true
        selectFilterScrollView.backgroundColor = UIColor.clear
        
        addSubview(selectFilterScrollView)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        selectFilterScrollView.frame = bounds
        updateScrollViewContentSize()
    }
    
    func updateScrollViewContentSize() {
        guard let filters = self.filters else { return }
        selectFilterScrollView.contentSize = CGSize(width: CGFloat(filters.count) * frame.size.width * 3, height: frame.size.height)
        
        if let selectedFilter = self.selectedFilter {
            scroll(to: selectedFilter, animated: false)
        }
    }
    /**
     Scrolls to a specific filter
     */
    func scroll(to filter: CIFilter, animated: Bool) {
        guard let filters = self.filters,
            let index = filters.index(of: filter) else { return }
        if index >= 0 {
            let contentOffset = CGPoint(x: selectFilterScrollView.contentSize.width / 3 + (selectFilterScrollView.frame.size.width * CGFloat(index)), y: 0)
            selectFilterScrollView.setContentOffset(contentOffset, animated: animated)
            updateCurrentSelected(false)
        } else {
            fatalError("InvalidFilterException : This filter is not present in the filters array")
        }
    }
    
    func updateCurrentSelected(_ shouldNotify: Bool) {
        guard let filters = self.filters else { return }
        let filterGroupsCount = filters.count
        let selectedIndex = Int((selectFilterScrollView.contentOffset.x + selectFilterScrollView.frame.size.width / 2) / selectFilterScrollView.frame.size.width) % filterGroupsCount
        var newFilterGroup: CIFilter?
        
        if selectedIndex >= 0 && selectedIndex < filterGroupsCount {
            newFilterGroup = filters[selectedIndex]
        } else {
            print("Invalid contentOffset of scrollView in SCFilterSwitcherView (\(selectFilterScrollView.contentOffset.x)/\(selectFilterScrollView.contentOffset.y) with \(Int(filters.count)))")
        }
        
        if selectedFilter != newFilterGroup {
            self.selectedFilter = newFilterGroup
            
            if shouldNotify {
                if let del = self.delegate {
                    del.swipeableFilterView(self, didScrollTo: newFilterGroup)
                }
            }
        }
    }
    
    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        updateCurrentSelected(true)
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateCurrentSelected(true)
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentSelected(true)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateCurrentSelected(true)
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let filters = self.filters else { return }
        let width: CGFloat = scrollView.frame.size.width
        let contentOffsetX: CGFloat = scrollView.contentOffset.x
        let contentSizeWidth: CGFloat = scrollView.contentSize.width
        let normalWidth: CGFloat = CGFloat(filters.count) * width
        
        if width > 0 && contentSizeWidth > 0 {
            if contentOffsetX <= 0 {
                scrollView.contentOffset = CGPoint(x: contentOffsetX + normalWidth, y: scrollView.contentOffset.y)
            } else if contentOffsetX + width >= contentSizeWidth {
                scrollView.contentOffset = CGPoint(x: contentOffsetX - normalWidth, y: scrollView.contentOffset.y)
            }
        }
        
        if refreshAutomaticallyWhenScrolling {
            setNeedsDisplay()
        }
    }
    
    override func renderedCIImage(in rect: CGRect) -> CIImage? {
        var image = super.renderedCIImage(in: rect)
        
        if preprocessingFilter != nil {
            selectedFilter?.setValue(image, forKey: kCIInputImageKey)
            image = selectedFilter?.value(forKey: kCIOutputImageKey) as? CIImage
        }
        
        let extent = image?.extent
        
        let contentSize: CGSize = selectFilterScrollView.frame.size
        
        if contentSize.width == 0 {
            return image
        }
        
        let ratio: CGFloat = selectFilterScrollView.contentOffset.x / contentSize.width
        
        var index = Int(ratio)
        let upIndex = Int(ceilf(Float(ratio)))
        let remainingRatio = ratio - (CGFloat(index))
        
        guard let filters = self.filters else { return nil }
        
        var xImage: CGFloat = (extent?.size.width ?? 0.0) * -remainingRatio
        var outputImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0))
        
        while index <= upIndex {
            let currentIndex: Int = index % filters.count
            let filter = filters[currentIndex]
            filter.setValue(image, forKey: kCIInputImageKey)
            var filteredImage = filter.value(forKey: kCIOutputImageKey) as? CIImage
            
            filteredImage = filteredImage?.cropped(to: CGRect(x: (extent?.origin.x ?? 0.0) + xImage, y: extent?.origin.y ?? 0.0, width: extent?.size.width ?? 0.0, height: extent?.size.height ?? 0.0))
            if let anImage = filteredImage?.composited(over: outputImage) {
                outputImage = anImage
            }
            xImage += extent?.size.width ?? 0.0
            index += 1
        }
        outputImage = outputImage.cropped(to: extent ?? CGRect.zero)
        
        return outputImage
    }
    
    open func setFilters(_ filters: [CIFilter]?) {
        self.filters = filters
        updateScrollViewContentSize()
        updateCurrentSelected(true)
    }
    
    open func setSelectedFilter(_ selectedFilter: CIFilter?) {
        if self.selectedFilter != selectedFilter {
            willChangeValue(forKey: "selectedFilter")
            self.selectedFilter = selectedFilter
            
            didChangeValue(forKey: "selectedFilter")
            
            setNeedsLayout()
        }
    }
    
}
