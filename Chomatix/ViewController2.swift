//
//  ViewController.swift
//  ChromaticTuner
//
//  Created by swift on 06.05.2024.
//

import UIKit
import AVFoundation
import SnapKit

class ViewController2 : UIViewController, AVAudioRecorderDelegate {
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    
    var numberOfRecords: Int = 0
    
    let buttonLabel: UIButton = {
           let recordButton = UIButton()
        recordButton.setTitle("Record", for: .normal)
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.backgroundColor = .red
        recordButton.layer.cornerRadius = 50
        recordButton.translatesAutoresizingMaskIntoConstraints = false

            return recordButton
        }()


    @objc func record(_ sender: Any) {
        
        print ("RECORDING...")
        
        if audioRecorder == nil
        {
            numberOfRecords += 1
            let fileName = getDirectory().appendingPathComponent("\(numberOfRecords).m4a")
            
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue ]
            
            do
            {
                audioRecorder = try AVAudioRecorder(url: fileName, settings: settings)
                audioRecorder.delegate = self
                audioRecorder.record()
                
                buttonLabel.setTitle("Stop", for: .normal)
            }
            catch
            {
                displayAlert(title: "Uh oh.", message:  "Something went wrong \n Recording Failed \n (try to restart recorder app idk) \n or your storage is full \n dunno \n ._.")
            }
        }
        else
        {
            
            print ("STOPPING...")
            
            audioRecorder.stop()
            audioRecorder = nil
            
            UserDefaults.standard.set(numberOfRecords, forKey: "myNumber")

            buttonLabel.setTitle("Record", for: .normal)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(buttonLabel)
        
        buttonLabel.snp.makeConstraints {
            make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(100)
            make.width.equalTo(100)
            
        }
        
        buttonLabel.addTarget(self, action: #selector(record(_:)), for: .touchUpInside)
                
        // Do any additional setup after loading the view.
        recordingSession = AVAudioSession.sharedInstance()
        
        if let number: Int = UserDefaults.standard.object(forKey: "myNumbers") as? Int {
            numberOfRecords = number
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { (hasPermission) in
            if hasPermission
            {
                print("ACCEPTED")
            }
        }
    }
    
    func getDirectory() -> URL
    {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        return documentDirectory
    }
    func displayAlert(title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "dismiss", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
