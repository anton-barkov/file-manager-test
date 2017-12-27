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
        var localId: Int
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
    
    private var previousLocalId: Int = 0
    
    private var files = [File]()
    
    public var allFiles: [File] {
        return files
    }
    
    private var sortedToOriginalIndexes = [Int: Int]()
    
    /**
        Creates a copy of files array and returns it sorted in descripted way.
     
        The idea is to keep the original array of files untouched and remember their corresponding indexes
        in both arrays. Sorting gets a little bit heavier for the CPU, but this way it won't break
        any operations that may run concurrently on files data by changing their order.
     
        - Parameter field: The type of data by which to sort.
        - Parameter ascending: Sort direction, `true` for ascending.
     
        - Returns: `File` array, sorted by description.
     */
    public func getSortedFiles(field: String, ascending: Bool) -> [File] {
        var sortedFiles = [File]()
        switch field {
        case "name":     sortedFiles = files.sorted { ascending ? $0.name < $1.name : $0.name > $1.name }
        case "size":     sortedFiles = files.sorted { ascending ? $0.sizeInt < $1.sizeInt : $0.sizeInt > $1.sizeInt }
        case "created":  sortedFiles = files.sorted { ascending ? $0.createdDate < $1.createdDate : $0.createdDate > $1.createdDate }
        case "modified": sortedFiles = files.sorted { ascending ? $0.modifiedDate < $1.modifiedDate : $0.modifiedDate > $1.modifiedDate }
        case "hash":     sortedFiles = files.sorted { ascending ? $0.hash < $1.hash : $0.hash > $1.hash }
        default:
            return []
        }
        
        // Find original indexes of corresponding files in the new sorted array
        // This operation is quite heavy when done on the main thread with lots of files, move it to background
        DispatchQueue.global(qos: .utility).async {
            for sortedIndex in 0...sortedFiles.count - 1 {
                guard let originalIndex = self.files.index(where: { (file) -> Bool in
                    file.localId == sortedFiles[sortedIndex].localId
                }) else { return }
                self.sortedToOriginalIndexes.updateValue(originalIndex, forKey: sortedIndex)
            }
        }
        
        
        return sortedFiles
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
                localId: previousLocalId + 1,
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
            
            previousLocalId += 1

        } catch {
            print("Failed to get file info: \(url)")
        }
    }
    
    public func removeFiles(atIndexes: IndexSet) {
        for index in atIndexes.reversed() {
            // Table hasn't been sorted yet, remove file by the same index
            if sortedToOriginalIndexes.isEmpty {
                files.remove(at: index)
            } else {
                // Table has been sorted, grab the corresponding original index
                if let originalIndex = sortedToOriginalIndexes[index] {
                    files.remove(at: originalIndex)
                }
            }
        }
    }
    
    public func zipAllFiles(acrchiveName: String, progressStatus: @escaping (Double) -> ()) {
        var urls = [URL]()
        for file in files {
            urls.append(file.url)
        }
        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try Zip.zipFiles(paths: urls, zipFilePath: desktopPath.appendingPathComponent("\(acrchiveName).zip"), password: nil, progress: { (progress) in
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
