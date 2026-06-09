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

public typealias UUImageLoadedCompletionBlock = (UUImage?, Error?) -> Void


public class UURemoteImage
{
    nonisolated(unsafe) public static let shared = UURemoteImage(remoteData: UURemoteData.shared)
    nonisolated(unsafe) public static var useDiskCache = true
    
    private let remoteData: UURemoteData
    
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
            let md = await remoteData.dataCache.metaData(for: path)
            
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
            return await remoteData.dataCache.dataExists(for: key)
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
        else
        {
            let data = await remoteData.data(for: key)
            { data, error in
                let image = await self.processImageData(for: key, data: data)
                
                if let completion = remoteLoadCompletion
                {
                    completion(image, error)
                }
            }
            
            if let imageData = data
            {
                let image = await self.processImageData(for: key, data: imageData)
                return image
            }
        }
        
        return nil
    }

    private func processImageData(for key: String, data : Data?) async -> UUImage?
    {
        if let imageData = data, let image = UUImage(data: imageData)
        {
            self.systemImageCache.setObject(image, forKey: key as NSString)
            
            if UURemoteImage.useDiskCache
            {
                var md = await remoteData.dataCache.metaData(for: key)
                md[MetaData.ImageWidth] = NSNumber(value: Float(image.size.width))
                md[MetaData.ImageHeight] = NSNumber(value: Float(image.size.height))
                await remoteData.dataCache.set(metaData: md, for: key)
            }

            self.notifyImageDownloaded(key)
            
            return image
        }
        
        return nil
    }
        
    private func notifyImageDownloaded(_ key: String)
    {
        DispatchQueue.global(qos: .userInitiated).async
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
