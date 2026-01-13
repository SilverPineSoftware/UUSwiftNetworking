//
//  UUHttpBody.swift
//  
//
//  Created by Ryan DeVore on 2/17/23.
//

import Foundation

open class UUHttpBody
{
    public let contentType: String
    public let content: Any
    
    public required init(_ contentType: String, _ content: Any)
    {
        self.contentType = contentType
        self.content = content
    }
    
    open func serializeBody() -> Data?
    {
        fatalError("Derived classes must implement serializeBody")
    }
}

open class UUCodableBody<T: Codable>: UUHttpBody
{
    let codableContent: T
    
    public required init(_ content: T)
    {
        codableContent = content
        super.init("application/json", content)
    }
    
    public required init(_ contentType: String, _ content: Any)
    {
        fatalError("Use init(content:T)")
    }
    
    override open func serializeBody() -> Data?
    {
        let encoder = JSONEncoder()
        return try? encoder.encode(codableContent)
    }
}
