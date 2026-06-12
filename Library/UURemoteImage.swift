//
//  UURemoteImage.swift
//  Useful Utilities - An extension to Useful Utilities
//  UURemoteData that exposes the cached data as UIImage/NSImage objects
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//
//  NOTE: This class depends on the following toolbox classes:
//
//  UUHttpSession
//  UUDataCache
//  UURemoteData
//
#if os(macOS)
	import AppKit
	public typealias UUImage = NSImage
#else
	import UIKit
	public typealias UUImage = UIImage
#endif

import UUSwiftCore

public typealias UUImageLoadedCompletionBlock = @Sendable (UUImage?, Error?) -> Void


public class UURemoteImage: @unchecked Sendable
{
    public static let shared = UURemoteImage(remoteData: UURemoteData.shared)
    nonisolated(unsafe) public static var useDiskCache = true
    
    private let remoteData: UURemoteData

    /// Serial queue for image decode work. Defaults to utility QoS.
    public var imageDecodeQueue: DispatchQueue = DispatchQueue(
        label: "com.silverpine.uu.remoteImage.decode",
        qos: .utility)

    /// Queue used to deliver `remoteLoadCompletion` handlers. Defaults to main.
    public var imageCallbackQueue: DispatchQueue = .main

    /// Queue used to post image download notifications. Defaults to main.
    public var imageNotificationQueue: DispatchQueue = .main
    
    required init(remoteData: UURemoteData)
    {
        self.remoteData = remoteData
    }
	
	public struct Notifications
    {
        public static let ImageDownloaded = Notification.Name("UUImageDownloadedNotification")
    }

    public func imageSize(for path: String) async -> CGSize?
    {
        if UURemoteImage.useDiskCache
        {
            let md = await remoteData.metaData(for: path)
            
            if let w = md[MetaData.ImageWidth] as? NSNumber,
               let h = md[MetaData.ImageHeight] as? NSNumber
            {
                return CGSize(width: CGFloat(w.floatValue), height: CGFloat(h.floatValue))
            }
        }
        
        return nil
    }
    
	public func memoryCache() -> NSCache<NSString, UUImage>
	{
		return self.systemImageCache
	}

	public func clearCache()
    {
        self.systemImageCache.removeAllObjects()
    }
    
    public func isDownloaded( for key: String) async -> Bool
    {
        if self.systemImageCache.object(forKey: key as NSString) != nil
        {
            return true
        }
        
        if UURemoteImage.useDiskCache
        {
            return await remoteData.cachedDataExists(for: key)
        }
        
        return false
    }
    
    public func image(for key: String) async -> UUImage?
    {
        return await image(for: key, remoteLoadCompletion: nil)
    }
    
    public func image(for key: String, remoteLoadCompletion: UUImageLoadedCompletionBlock? = nil) async -> UUImage?
    {
        if let image = self.systemImageCache.object(forKey: key as NSString)
        {
            return image
        }

        let instance = self
        let imageKey = key
        let completion = remoteLoadCompletion
        let data = await remoteData.data(for: key)
        { data, error in
            let image = await instance.processImageData(for: imageKey, data: data)
            instance.deliverImageCompletion(completion, image: image, error: error)
        }
        
        if let imageData = data
        {
            return await processImageData(for: key, data: imageData)
        }
        
        return nil
    }

    private func deliverImageCompletion(
        _ completion: UUImageLoadedCompletionBlock?,
        image: UUImage?,
        error: Error?)
    {
        guard let completion else
        {
            return
        }

        imageCallbackQueue.async
        {
            completion(image, error)
        }
    }

    private func processImageData(for key: String, data: Data?) async -> UUImage?
    {
        let instance = self
        let imageKey = key
        let imageData = data
        let decodeQueue = imageDecodeQueue
        return await withCheckedContinuation
        { continuation in
            decodeQueue.async
            {
                Task
                {
                    let image = await instance.decodeAndCacheImage(for: imageKey, data: imageData)
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private func decodeAndCacheImage(for key: String, data: Data?) async -> UUImage?
    {
        if let imageData = data, let image = UUImage(data: imageData)
        {
            var preparedImage = image
            
            // If available, prepare the image
            #if canImport(UIKit)
            preparedImage = await image.byPreparingForDisplay() ?? image
            #endif
            
            self.systemImageCache.setObject(preparedImage, forKey: key as NSString)
            
            if UURemoteImage.useDiskCache
            {
                var md = await remoteData.metaData(for: key)
                md[MetaData.ImageWidth] = NSNumber(value: Float(image.size.width))
                md[MetaData.ImageHeight] = NSNumber(value: Float(image.size.height))
                await remoteData.set(metaData: md, for: key)
            }

            notifyImageDownloaded(key)
            
            return image
        }
        
        return nil
    }
        
    private func notifyImageDownloaded(_ key: String)
    {
        let queue = imageNotificationQueue
        queue.async
        {
            var metaData : [String:Any] = [:]
            metaData[UURemoteData.NotificationKeys.RemotePath] = key
            NotificationCenter.default.post(name: Notifications.ImageDownloaded, object: nil, userInfo: metaData)
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // Private implementation
    ////////////////////////////////////////////////////////////////////////////
    private let systemImageCache = NSCache<NSString, UUImage>()
    
    private struct MetaData
    {
        static let ImageWidth = "ImageWidth"
        static let ImageHeight = "ImageHeight"
    }

}
