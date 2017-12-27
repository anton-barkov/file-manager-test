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
    
    // Singleton shared instance
    static let shared: Files = {
        return Files()
    }()
    
    /**
        File item.
     
        - localID: An ID assigned to file after it's been added, used for sorting.
        - url: System URL of a file.
        - icon: System file icon.
        - name: File name with extension.
        - sizeString: File size formatted for table output.
        - sizeInt: Raw file size, used for sorting.
        - createdString: File creation date formatted for table output.
        - createdDate: Raw file creation date, used for sorting.
        - modifiedString: File last modification date formatted for table output.
        - modifiedDate: Raw file last modification date, used for sorting.
        - hash: File's MD5 hash.
     */
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
    
    // ID of the last appended file
    private var previousLocalId: Int = 0
    
    // Private array of files data
    // Stays in its original order all the time, changed only by addition/removal of files
    private var files = [File]()
    
    // Returns an unsorted array of files
    public var allFiles: [File] {
        return files
    }
    
    // An array of indexes, that describes the order in which table data should be presented
    private var sortedFilesOrder = [Int]()
    
    // Returns an array of sorted files based on the `sortedFilesOrder`
    public var sortedFiles: [File] {
        var sortedFiles = [File]()
        for index in sortedFilesOrder {
            sortedFiles.append(files[index])
        }
        return sortedFiles
    }
    
    /**
        Sorts original array of files according to the description, writes the sorted order of elements to `sortedFilesOrder`.
     
        The idea is to keep the original array of files untouched and use an array of indexes to handle table sorting.
        This way operations that run concurrently on files data won't break because of elements reordering.
     
        - Parameter field: The type of data by which to sort.
        - Parameter ascending: Sort direction, `true` for ascending.
     
        - Returns: `File` array, sorted by description.
     */
    public func sortFiles(field: String, ascending: Bool) {
        var sortedFiles = [File]()
        switch field {
        case "name":     sortedFiles = files.sorted { ascending ? $0.name < $1.name : $0.name > $1.name }
        case "size":     sortedFiles = files.sorted { ascending ? $0.sizeInt < $1.sizeInt : $0.sizeInt > $1.sizeInt }
        case "created":  sortedFiles = files.sorted { ascending ? $0.createdDate < $1.createdDate : $0.createdDate > $1.createdDate }
        case "modified": sortedFiles = files.sorted { ascending ? $0.modifiedDate < $1.modifiedDate : $0.modifiedDate > $1.modifiedDate }
        case "hash":     sortedFiles = files.sorted { ascending ? $0.hash < $1.hash : $0.hash > $1.hash }
        default:
            return
        }
        
        sortedFilesOrder = []
        for sortedIndex in 0...sortedFiles.count - 1 {
            guard let originalIndex = files.index(where: { (file) -> Bool in
                file.localId == sortedFiles[sortedIndex].localId
            }) else { return }
            self.sortedFilesOrder.append(originalIndex)
        }
    }
    
    /**
        Gets file's info by its URL and appends the data to the main `files` array.
        - Parameter url: System URL to file's location.
     */
    public func appendFile(url: URL) {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)

            // Creation/modification date formatting
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.doesRelativeDateFormatting = true
            dateFormatter.timeStyle = .short
            
            guard let createdDate = attributes[FileAttributeKey.creationDate] as? Date else { return }
            let createdString = dateFormatter.string(from: createdDate)

            guard let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date else { return }
            let modifiedString = dateFormatter.string(from: modifiedDate)

            // File size formatting
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
    
    /**
        Removes files by a set of indexes from table view.
        - Parameter atIndexes: A set of indexes of selected table view rows.
     */
    public func removeFiles(atIndexes: IndexSet) {
        for index in atIndexes.reversed() {
            if sortedFilesOrder.isEmpty {
                // Table hasn't been sorted yet, remove file using the same index
                files.remove(at: index)
            } else {
                // Table has been sorted, grab the corresponding original index
                let indexToRemove = sortedFilesOrder[index]
                files.remove(at: indexToRemove)
                
                // Indexes are no longer correct since we removed one of the elements
                // Get rid of the removed file index
                sortedFilesOrder.remove(at: index)
                
                // Move every element following the removed one down by one position
                if !sortedFilesOrder.isEmpty {
                    for i in 0...sortedFilesOrder.count - 1 {
                        if(sortedFilesOrder[i] > indexToRemove) {
                            sortedFilesOrder[i] = sortedFilesOrder[i] - 1
                        }
                    }
                }
            }
        }
    }
    
    /**
        Adds all files that are currently present in the app to a zip archive and places it on the desktop.
        - Parameter archiveName: User defined name of the archive.
        - Parameter progressStatus: Closure that notifies on progress.
     */
    public func zipAllFiles(archiveName: String, progressStatus: @escaping (Double) -> ()) {
        // Get all the file URLs
        var urls = [URL]()
        for file in files {
            urls.append(file.url)
        }
        
        // Handle archive file name and path
        let name = (archiveName == "") ? "test-archive" : archiveName
        let desktopPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        
        // Dispatch work to a background thread, notify main thread on progress
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try Zip.zipFiles(paths: urls, zipFilePath: desktopPath.appendingPathComponent("\(name).zip"), password: nil, progress: { (progress) in
                    DispatchQueue.main.async {
                        progressStatus(progress)
                    }
                })
            } catch {
                print(error)
            }
        }
    }
    
    
    /**
        Calculates MD5 hashes for all files that are currently present in the app.
        - Parameter progressStatus: Closure that notifies on progress.
     */
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
    
    /**
        Calculates MD5 hash for a single file.
     
        Courtesy of Martin R from SO.
     
        - Parameter url: File URL describing its location in the system.
        - Returns: String containing MD5 hash of the file.
     */
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
