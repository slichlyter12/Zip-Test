//
//  ViewController.swift
//  Zip Test
//
//  Created by Samuel Lichlyter on 4/10/19.
//  Copyright © 2019 Samuel Lichlyter. All rights reserved.
//

import UIKit
import ZIPFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    
    var rasterDirURL: URL!
    let files: [String] = [
        "pnw_NO2_1997.tif",
        "pnw_NO2_1998.tif",
        "pnw_NO2_1999.tif",
        "pnw_NO2_2000.tif",
        "pnw_NO2_2001.tif",
        "pnw_NO2_2002.tif",
        "pnw_NO2_2003.tif",
        "pnw_NO2_2004.tif",
        "pnw_NO2_2005.tif",
        "pnw_NO2_2006.tif",
        "pnw_NO2_2007.tif",
        "pnw_NO2_2008.tif",
        "pnw_NO2_2009.tif",
        "pnw_NO2_2010.tif",
        "pnw_NO2_2011.tif",
    ]
    var progressValue = Double(0)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // check if file exists, if not unzip
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileManager = FileManager()
            rasterDirURL = dir.appendingPathComponent("rasters")
            let NO2Dir = rasterDirURL.appendingPathComponent("NO2")
            deleteDir(rasterDirURL)
            if !fileManager.fileExists(atPath: NO2Dir.path) {
                unzipFiles(files: files)
            } else {
                for file in files {
                    let filePath = NO2Dir.appendingPathComponent(file).path
                    if !fileManager.fileExists(atPath: filePath) {
                        deleteDir(rasterDirURL)
                        unzipFiles(files: files)
                        print("re-running unzip because missing \(file)")
                        return
                    }
                }
                self.progressLabel.text = "Found!"
                self.progressView.isHidden = true
            }
        }
    }
    
    func unzipFiles(files: [String]) {

        let path = Bundle.main.path(forResource: "NO2", ofType: "zip")
        let sourceURL = URL(fileURLWithPath: path!)

        do {
            // create raster directory
            let fileManager = FileManager()
            try fileManager.createDirectory(atPath: rasterDirURL.path, withIntermediateDirectories: true, attributes: nil)
            
            let q = DispatchQueue(label: "unzip", qos: .utility)
            q.async {
                self.doUnzip(files: files, source: sourceURL, callback: {
                    DispatchQueue.main.async {
                        self.progressLabel.text = "Saved!"
                        self.progressView.isHidden = true
                    }
                })
            }
        } catch {
            print("Error creating raster directory with error: \(error.localizedDescription)")
        }
    }
    
    func doUnzip(files: [String], source: URL, callback: () -> Void) {
        for file in files {
            let q = DispatchQueue(label: file, qos: .utility)
            q.async {
                self.unzip(fileName: file, sourceURL: source)
            }
        }
    }
    
    func unzip(fileName: String, sourceURL: URL) {
        guard let archive = Archive(url: sourceURL, accessMode: .read) else {
            print("Failed to create archive")
            return
        }
        guard let entry = archive["NO2/" + fileName] else {
            print("Failed to get entry")
            return
        }
        
        // TODO: This doesn't work, need to add up percentage differently
        let progress = Progress()
        var last = Double(0)
        let r = progress.observe(\Progress.fractionCompleted) { (progress, change) in
            DispatchQueue.main.async {
                let d = progress.fractionCompleted
                print(d)
                let diff = (d - last)
                print("diff: \(diff)")
                last = d
//                let percentComplete = diff * 100.0
                self.progressValue += diff / Double(self.files.count)
                print("progressValue: \(self.progressValue)")
                self.progressLabel.text = String(Int(self.progressValue * 100.0)) + "%"
                self.progressView.progress = Float(self.progressValue)
            }
        }

        do {
            let NO2Dir = rasterDirURL.appendingPathComponent("NO2")
            try archive.extract(entry, to: NO2Dir.appendingPathComponent(fileName), progress: progress)
        } catch {
            print("failed to extract with error: \(error.localizedDescription)")
        }
    }
    
    func runUnzip() {
        let q = DispatchQueue(label: "zip", qos: .utility)
        q.async {
            self.unzip()
        }
    }
    
    func unzip() {
        let path = Bundle.main.path(forResource: "NO2", ofType: "zip")
        let url = URL(fileURLWithPath: path!)
        let progress = Progress()
        let r = progress.observe(\Progress.fractionCompleted, options: .new) { (progress, change) in
            let d = progress.fractionCompleted
            let percentage = d * 100.0
            let percentageString = String(Int(percentage)) + "%"
            
            DispatchQueue.main.async {
                self.progressLabel.text = percentageString
                self.progressView.progress = Float(d)
            }
        }
        
        do {
            let fileManager = FileManager()
            try fileManager.createDirectory(atPath: rasterDirURL.path, withIntermediateDirectories: true, attributes: nil)
            try fileManager.unzipItem(at: url, to: rasterDirURL, progress: progress)
        } catch {
            print("Reading entry from archive failed with error: \(error.localizedDescription)")
            print("Deleting and trying again")
            deleteDir(rasterDirURL)
            DispatchQueue.main.async {
                self.progressLabel.text = "Please force-close and relaunch the app"
            }
        }
        
        DispatchQueue.main.async {
            self.progressLabel.text = "Saved!"
        }
    }
    
    func deleteDir(_ dir: URL) {
        do {
            print("Deleting directory...")
            let fileManager = FileManager()
            try fileManager.removeItem(at: rasterDirURL)
        } catch {
            print("Error deleting directory with error: \(error.localizedDescription)")
        }
        
        print("Directory deleted!")
    }
    
    func showError(errorDescription: String) {
        let alertController = UIAlertController(title: "Error", message: errorDescription, preferredStyle: .alert)
        let okayAction = UIAlertAction(title: "Okay", style: .default, handler: nil)
        alertController.addAction(okayAction)
        present(alertController, animated: true, completion: nil)
    }
}

