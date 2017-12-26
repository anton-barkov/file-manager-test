//
//  Files.swift
//  MacPaw Test
//
//  Created by Anton Barkov on 24.12.2017.
//  Copyright © 2017 Anton Barkov. All rights reserved.
//

import Cocoa
import Zip

class Files: NSObject {
    
    static let shared: Files = {
        return Files()
    }()
    
    struct File {
        var url: URL
        var icon: NSImage
        var name: String
        var sizeString: String
        var sizeInt: Int64
        var createdString: String
        var createdDate: Date
        var modifiedString: String
        var modifiedDate: Date
        var hash: String
    }
    private var files = [File]()
    
    public var allFiles: [File] {
        return files
    }
    
    public func appendFile(url: URL) {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)

            // MARK: Creation/modification date formatting
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.doesRelativeDateFormatting = true
            dateFormatter.timeStyle = .short
            
            guard let createdDate = attributes[FileAttributeKey.creationDate] as? Date else { return }
            let createdString = dateFormatter.string(from: createdDate)

            guard let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date else { return }
            let modifiedString = dateFormatter.string(from: modifiedDate)

            // MARK: File size formatting
            let sizeFormatter = ByteCountFormatter()
            guard let sizeInt = attributes[FileAttributeKey.size] as? Int64 else { return }
            let sizeString = sizeFormatter.string(fromByteCount: sizeInt)

            self.files.append(File(
                url: url,
                icon: NSWorkspace.shared.icon(forFile: url.path),
                name: url.lastPathComponent,
                sizeString: sizeString,
                sizeInt: sizeInt,
                createdString: createdString,
                createdDate: createdDate,
                modifiedString: modifiedString,
                modifiedDate: modifiedDate,
                hash: "-"
            ))

        } catch {
            print("Failed to get file info: \(url)")
        }
    }
    
    public func removeFiles(atIndexes: IndexSet) {
        for index in atIndexes.reversed() {
            files.remove(at: index)
        }
    }
    
    public func sortData(field: String, ascending: Bool) {
        switch field {
        case "name":     files.sort { ascending ? $0.name < $1.name : $0.name > $1.name }
        case "size":     files.sort { ascending ? $0.sizeInt < $1.sizeInt : $0.sizeInt > $1.sizeInt }
        case "created":  files.sort { ascending ? $0.createdDate < $1.createdDate : $0.createdDate > $1.createdDate }
        case "modified": files.sort { ascending ? $0.modifiedDate < $1.modifiedDate : $0.modifiedDate > $1.modifiedDate }
        case "hash":     files.sort { ascending ? $0.hash < $1.hash : $0.hash > $1.hash }
        default:
            return
        }
    }
    
    private func getAllUrls() -> [URL] {
        var urls = [URL]()
        for file in files {
            urls.append(file.url)
        }
        return urls
    }
    
    public func zipAllFiles(acrchiveName: String, progressStatus: @escaping (Double) -> ()) {
        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try Zip.zipFiles(paths: self.getAllUrls(), zipFilePath: desktopPath.appendingPathComponent("\(acrchiveName).zip"), password: nil, progress: { (progress) in
                    DispatchQueue.main.async {
                        progressStatus(progress)
                    }
                })
            } catch {
                print(error)
            }
        }
    }
    
    public func countAllHashes(progressStatus: @escaping (Double) -> ()) {
        DispatchQueue.global(qos: .userInitiated).async {
            var index = 0
            while index < self.files.count {
                if let hash = self.md5(url: self.files[index].url) {
                    self.files[index].hash = hash
                    DispatchQueue.main.async {
                        print(index)
                        print(self.files.count)
                        progressStatus(Double(index) / Double(self.files.count))
                    }
                }
                index += 1
            }
        }
    }
    
    private func md5(url: URL) -> String? {
        let bufferSize = 1024 * 1024
        
        do {
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }
            
            // Create and initialize MD5 context:
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)
            
            // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0, numericCast(data.count))
                    }
                    return true // Continue
                } else {
                    return false // End of file
                }
            }) { }
            
            // Compute the MD5 digest:
            var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes {
                _ = CC_MD5_Final($0, &context)
            }
            
            let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
            return hexDigest
            
        } catch {
            print("Cannot open file:", error.localizedDescription)
            return nil
        }
    }
}
