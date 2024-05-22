import UIKit
import AVFoundation
import Accelerate
import SnapKit

class ViewController: UIViewController {
    
    let notesFreq: [String: Float] = [
        "C": 261.63,
        "C#": 277.18,
        "D": 293.66,
        "D#": 311.13,
        "E": 329.63,
        "F": 349.23,
        "F#": 369.99,
        "G": 392.00,
        "G#": 415.30,
        "A": 440.00,
        "A#": 466.16,
        "B": 493.88
    ]
    
    var audioRecorder: AVAudioRecorder!
    var timer: Timer!
    
    lazy var noteLabel: UILabel = {
       let label = UILabel ()
        label.text = "sdfsdfds"
        label.font = .systemFont(ofSize: 15)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(noteLabel)
        noteLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        requestPermissionAndSetupRecorder()
    }
    
    func requestPermissionAndSetupRecorder() {
        AVAudioSession.sharedInstance().requestRecordPermission { (granted) in
            if granted {
                DispatchQueue.main.async {
                    self.setupRecorder()
                }
            } else {
                print("Permission for microphone access denied")
            }
        }
    }
    
    func setupRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
            let settings = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
            audioRecorder.prepareToRecord()
            audioRecorder.isMeteringEnabled = true
            audioRecorder.record()
            startTimer()
        } catch {
            print("Error setting up audio recorder: \(error.localizedDescription)")
        }
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (_) in
            self.audioRecorder.updateMeters()
            let averagePower = self.audioRecorder.averagePower(forChannel: 0)
            let amplitude = abs(pow(10, (0.05 * averagePower)))
            
            // Check if audioData is non-empty before processing
            if let audioData = self.getAudioData(), !audioData.isEmpty {
                if let dominantFrequency = self.findDominantFrequency2(audioData: audioData, sampleRate: self.audioRecorder.settings[AVSampleRateKey] as? Float ?? 44100) {
                    print("Dominant Frequency: \(dominantFrequency) Hz")
                    if let detectedNote = self.findNearestNoteFrequency(dominantFrequency) {
                        DispatchQueue.main.async {
                            self.noteLabel.text = detectedNote
                        }
                    }
                } else {
                    print("Unable to find dominant frequency.")
                }
            } else {
                print("Audio data is empty or unavailable.")
            }
        }
    }

    func getAudioData() -> [Float]? {
        let audioFileURL = audioRecorder.url
//        else {
//            print("Audio file URL is nil")
//            return nil
//        }
        
        do {
            let audioFile = try AVAudioFile(forReading: audioFileURL)
            let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: audioFile.fileFormat.sampleRate, channels: audioFile.fileFormat.channelCount, interleaved: false)
            let audioFrameCount = UInt32(audioFile.length)
            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: audioFrameCount) else {
                print("Unable to create audio buffer")
                return nil
            }
            
            try audioFile.read(into: audioBuffer)
            
            // Convert audio buffer to an array of floats
            guard let floatChannelData = audioBuffer.floatChannelData else {
                print("Audio buffer does not contain float channel data")
                return nil
            }
            
            let floatArray = Array(UnsafeBufferPointer(start: floatChannelData.pointee, count:Int(audioBuffer.frameLength)))
            return floatArray
        } catch {
            print("Error getting audio data: \(error.localizedDescription)")
            return nil
        }
    }

    
    func findDominantFrequency2(audioData: [Float], sampleRate: Float) -> Float? {
        let signalLength = vDSP_Length(audioData.count)
        let log2N = vDSP_Length(log2(Float(audioData.count)))

        // Prepare FFT setup
        guard let fftSetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2)) else {
            return nil
        }

        // Prepare input/output buffers
        var realPart = [Float](repeating: 0.0, count: audioData.count)
        var imagPart = [Float](repeating: 0.0, count: audioData.count / 2)
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        // Perform FFT
        audioData.withUnsafeBytes { buffer in
            vDSP_ctoz(UnsafePointer<DSPComplex>(buffer.baseAddress!.assumingMemoryBound(to: DSPComplex.self)),
                      2,
                      &splitComplex,
                      1,
                      signalLength / 2)
        }
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2N, FFTDirection(FFT_FORWARD))

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0.0, count: audioData.count / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, signalLength / 2)

        // Find peak frequency
        let maxIndex = magnitudes.indices.max { magnitudes[$0] < magnitudes[$1] }
        let peakFrequency = Float(maxIndex!) * sampleRate / Float(audioData.count)

        // Cleanup
        vDSP_destroy_fftsetup(fftSetup)

        return peakFrequency
    }

    func findNearestNoteFrequency(_ frequency: Float) -> String? {
        let threshold: Float = 10.0 // Adjust this threshold as needed
        for (note, freq) in notesFreq {
            if abs(freq - frequency) < threshold {
                return note
            }
        }
        return nil
    }
}
