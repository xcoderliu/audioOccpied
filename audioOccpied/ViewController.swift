//
//  ViewController.swift
//  audioOccpied
//
//  Created by 刘智民 on 2026/1/8.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioRecorder: AVAudioRecorder?
    
    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始播放（抢占音频）", for: .normal)
        button.setTitle("停止播放", for: .selected)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let categorySegment: UISegmentedControl = {
        let items = ["playback", "playAndRecord", "ambient"]
        let segment = UISegmentedControl(items: items)
        segment.selectedSegmentIndex = 0
        segment.translatesAutoresizingMaskIntoConstraints = false
        return segment
    }()
    
    private let optionsSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        sw.translatesAutoresizingMaskIntoConstraints = false
        return sw
    }()
    
    private let optionsDescLabel: UILabel = {
        let label = UILabel()
        label.text = "开启后会中断其他应用音频"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let methodSegment: UISegmentedControl = {
        let items = ["AVAudioPlayer", "AVAudioEngine", "实时采集麦克风"]
        let segment = UISegmentedControl(items: items)
        segment.selectedSegmentIndex = 0
        segment.translatesAutoresizingMaskIntoConstraints = false
        return segment
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = """
        📱 音频抢占测试工具
        
        使用步骤：
        1. 先在主应用中播放音频
        2. 选择音频会话类别
        3. 开启"中断其他App"选项
        4. 点击"开始播放"按钮
        5. 观察主应用是否收到中断
        
        ⚠️ 主应用检查清单：
        • 音频会话类别必须是 .playback 或 .playAndRecord
        • 必须调用 setActive(true) 激活
        • 必须正在播放音频
        • 必须监听 interruptionNotification
        """
        return label
    }()
    
    private let logTextView: UITextView = {
        let textView = UITextView()
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .secondarySystemBackground
        textView.textColor = .label
        textView.layer.cornerRadius = 8
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "音频抢占测试"
        
        setupUI()
        setupActions()
        setupNotifications()
        setupGestures()
        
        log("✅ 测试工具已启动")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        let categoryLabel = createLabel(text: "音频会话类别:")
        let methodLabel = createLabel(text: "播放方式:")
        let optionsLabel = createLabel(text: "中断其他App:")
        let logLabel = createLabel(text: "日志输出:")
        
        view.addSubview(infoLabel)
        view.addSubview(categoryLabel)
        view.addSubview(categorySegment)
        view.addSubview(optionsLabel)
        view.addSubview(optionsSwitch)
        view.addSubview(methodLabel)
        view.addSubview(methodSegment)
        view.addSubview(playButton)
        view.addSubview(logLabel)
        view.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            categoryLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 25),
            categoryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            categorySegment.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 8),
            categorySegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categorySegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            optionsLabel.topAnchor.constraint(equalTo: categorySegment.bottomAnchor, constant: 20),
            optionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            optionsSwitch.centerYAnchor.constraint(equalTo: optionsLabel.centerYAnchor),
            optionsSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            methodLabel.topAnchor.constraint(equalTo: optionsLabel.bottomAnchor, constant: 20),
            methodLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            methodSegment.topAnchor.constraint(equalTo: methodLabel.bottomAnchor, constant: 8),
            methodSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            methodSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            playButton.topAnchor.constraint(equalTo: methodSegment.bottomAnchor, constant: 25),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 260),
            playButton.heightAnchor.constraint(equalToConstant: 55),
            
            logLabel.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 20),
            logLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            logTextView.topAnchor.constraint(equalTo: logLabel.bottomAnchor, constant: 8),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func setupActions() {
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
    }
    
    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(clearLog))
        doubleTap.numberOfTapsRequired = 2
        logTextView.addGestureRecognizer(doubleTap)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func playButtonTapped() {
        if playButton.isSelected {
            stopAudio()
        } else {
            startAudio()
        }
        playButton.isSelected.toggle()
    }
    
    @objc private func clearLog() {
        logTextView.text = ""
        log("✅ 日志已清空（双击可清空日志）")
    }
    
    private func startAudio() {
        let category: AVAudioSession.Category
        let categoryName: String
        
        switch categorySegment.selectedSegmentIndex {
        case 0:
            category = .playback
            categoryName = "playback"
        case 1:
            category = .playAndRecord
            categoryName = "playAndRecord"
        case 2:
            category = .ambient
            categoryName = "ambient"
        default:
            category = .playback
            categoryName = "playback"
        }
        
        // 配置选项
        var options: AVAudioSession.CategoryOptions = []
        if !optionsSwitch.isOn {
            // 如果不想中断其他App，添加混音选项
            options.insert(.mixWithOthers)
            log("ℹ️ 已添加 .mixWithOthers 选项（不会中断其他App）")
        } else {
            log("⚡️ 将尝试中断其他App的音频")
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 检查当前是否有其他音频在播放
            if session.isOtherAudioPlaying {
                log("✅ 检测到其他应用正在播放音频")
            } else {
                log("⚠️ 未检测到其他应用正在播放音频")
                log("   请确保主应用已经:")
                log("   1. 设置了正确的 category")
                log("   2. 调用了 setActive(true)")
                log("   3. 开始播放音频")
            }
            
            // 先停用旧会话
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            
            // 配置新的音频会话
            try session.setCategory(category, mode: .default, options: options)
            log("✅ 音频会话类别: \(categoryName)")
            
            // 激活音频会话
            try session.setActive(true, options: [])
            log("✅ 音频会话已激活")
            
            // 打印详细配置参数
            logAudioSessionDetails(session)
            
            // 再次检查
            if session.secondaryAudioShouldBeSilencedHint {
                log("✅ 系统提示: 其他音频应该被静音")
            }
            
        } catch {
            log("❌ 音频会话配置失败: \(error.localizedDescription)")
            playButton.isSelected = false
            return
        }
        
        switch methodSegment.selectedSegmentIndex {
        case 0:
            playWithAVAudioPlayer()
        case 1:
            playWithAVAudioEngine()
        case 2:
            captureAudioRealtime()
        default:
            break
        }
    }
    
    private func stopAudio() {
        // 移除 tap
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
        }
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            log("✅ 音频会话已停止（通知其他应用）")
        } catch {
            log("❌ 停止音频会话失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioPlayer
    private func playWithAVAudioPlayer() {
        guard let audioFileURL = generateTestAudioFile() else {
            log("❌ 生成测试音频文件失败")
            playButton.isSelected = false
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1 // 无限循环
            audioPlayer?.volume = 1.0
            
            let success = audioPlayer?.play() ?? false
            if success {
                log("✅ AVAudioPlayer 开始播放（440Hz正弦波）")
                log("   音量: \(audioPlayer?.volume ?? 0)")
                log("   是否正在播放: \(audioPlayer?.isPlaying ?? false)")
                
                // 打印当前音频会话配置
                let currentSession = AVAudioSession.sharedInstance()
                logAudioSessionDetails(currentSession)
                
                // 延迟检查音频会话状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let session = AVAudioSession.sharedInstance()
                    self.log("📊 音频会话状态检查:")
                    self.log("   category: \(session.category.rawValue)")
                    self.log("   mode: \(session.mode.rawValue)")
                    self.log("   isOtherAudioPlaying: \(session.isOtherAudioPlaying)")
                    self.log("   secondaryAudioShouldBeSilencedHint: \(session.secondaryAudioShouldBeSilencedHint)")
                    
                    if let route = session.currentRoute.outputs.first {
                        self.log("   输出设备: \(route.portType.rawValue)")
                    }
                }
            } else {
                log("❌ AVAudioPlayer play() 返回 false")
                playButton.isSelected = false
            }
        } catch {
            log("❌ AVAudioPlayer 初始化失败: \(error.localizedDescription)")
            playButton.isSelected = false
        }
    }
    
    // MARK: - AVAudioEngine
    private func playWithAVAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        engine.attach(player)
        
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        if let buffer = generateSineWaveBuffer(frequency: 440, duration: 1.0, format: format) {
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        }
        
        do {
            try engine.start()
            player.play()
            log("✅ AVAudioEngine 开始播放（440Hz正弦波）")
            
            // 打印当前音频会话配置
            let session = AVAudioSession.sharedInstance()
            logAudioSessionDetails(session)
        } catch {
            log("❌ AVAudioEngine 启动失败: \(error.localizedDescription)")
            playButton.isSelected = false
        }
    }
    
    // MARK: - 边播放边录音
    private func playAndRecord() {
        // 必须使用 playAndRecord 类别
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            log("✅ 音频会话已配置为 playAndRecord")
            
            // 打印详细配置参数
            logAudioSessionDetails(session)
        } catch {
            log("❌ 配置 playAndRecord 失败: \(error.localizedDescription)")
            playButton.isSelected = false
            return
        }
        
        // 1. 开始播放
        guard let audioFileURL = generateTestAudioFile() else {
            log("❌ 生成测试音频文件失败")
            playButton.isSelected = false
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            log("✅ 开始播放音频")
        } catch {
            log("❌ 播放失败: \(error.localizedDescription)")
        }
        
        // 2. 同时开始录音（数据直接扔掉）
        let recordURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_record_\(Date().timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordURL, settings: settings)
            audioRecorder?.record()
            log("✅ 开始录音（麦克风已被占用）")
            log("   这会触发使用麦克风的主app收到中断")
        } catch {
            log("❌ 录音失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 实时采集麦克风+播放
    private func captureAudioRealtime() {
        // 使用 .playAndRecord 类别（既采集麦克风又播放音频）
        do {
            let session = AVAudioSession.sharedInstance()
            
            var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]
            
            // 根据开关决定是否中断其他音频
            if !optionsSwitch.isOn {
                options.insert(.mixWithOthers)
                log("ℹ️ 添加 .mixWithOthers - 不会中断其他App")
            } else {
                log("⚡️ 未添加 .mixWithOthers - 将尝试中断其他App")
            }
            
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            try session.setActive(true)
            log("✅ 音频会话已配置为 .playAndRecord（采集+播放）")
            
            // 打印详细配置参数
            logAudioSessionDetails(session)
        } catch {
            log("❌ 配置音频会话失败: \(error.localizedDescription)")
            playButton.isSelected = false
            return
        }
        
        // 使用 AVAudioEngine 实时采集麦克风
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        log("🎤 麦克风格式:")
        log("   采样率: \(inputFormat.sampleRate) Hz")
        log("   声道数: \(inputFormat.channelCount)")
        log("   位深度: \(inputFormat.commonFormat.rawValue)")
        
        // 安装 tap 实时读取音频数据（这是关键！）
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] (buffer, time) in
            // 实时处理音频数据
            // 这里不做任何处理，只是读取数据以触发真正的麦克风占用
            let channelData = buffer.floatChannelData
            let channelDataValue = channelData?.pointee
            
            // 计算音量（可选，用于验证确实在采集）
            if let data = channelDataValue {
                var sum: Float = 0
                let frameLength = Int(buffer.frameLength)
                for i in 0..<frameLength {
                    let value = data[i]
                    sum += value * value
                }
                let rms = sqrt(sum / Float(frameLength))
                
                // 每秒打印一次音量
                if Int(time.sampleTime) % Int(inputFormat.sampleRate) == 0 {
                    DispatchQueue.main.async {
                        self?.log("📊 实时音量: \(String(format: "%.4f", rms))")
                    }
                }
            }
        }
        
        do {
            try engine.start()
            log("✅ 开始实时采集麦克风数据")
            log("   这种方式最接近真实的音频输入场景")
        } catch {
            log("❌ 启动麦克风采集失败: \(error.localizedDescription)")
            playButton.isSelected = false
            return
        }
        
        // 同时播放音频
        guard let audioFileURL = generateTestAudioFile() else {
            log("❌ 生成测试音频文件失败")
            playButton.isSelected = false
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
            log("✅ 同时开始播放音频")
            log("   既采集麦克风又播放音频，应该能触发主app收到中断")
        } catch {
            log("❌ 播放失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 音频生成
    private func generateTestAudioFile() -> URL? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_audio.m4a")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        let sampleRate = 44100.0
        let duration = 1.0
        let frequency = 440.0
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            let format = audioFile.processingFormat
            
            if let buffer = generateSineWaveBuffer(frequency: frequency, duration: duration, format: format) {
                try audioFile.write(from: buffer)
                return fileURL
            }
        } catch {
            log("❌ 生成音频文件失败: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func generateSineWaveBuffer(frequency: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        let channels = Int(format.channelCount)
        let floatChannelData = buffer.floatChannelData
        
        for frame in 0..<Int(frameCount) {
            let value = sin(2.0 * .pi * frequency * Double(frame) / sampleRate)
            for channel in 0..<channels {
                floatChannelData?[channel][frame] = Float(value) * 0.5
            }
        }
        
        return buffer
    }
    
    // MARK: - 通知处理
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            log("🔴 本App收到中断: 音频被其他应用抢占")
        case .ended:
            let options = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            log("🟢 本App中断结束\(shouldResume ? "（可以恢复播放）" : "")")
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        let reasonText: String
        switch reason {
        case .oldDeviceUnavailable:
            reasonText = "旧设备不可用"
        case .newDeviceAvailable:
            reasonText = "新设备可用"
        case .categoryChange:
            reasonText = "类别变化"
        default:
            reasonText = "其他原因"
        }
        
        log("🔄 音频路由变化: \(reasonText)")
    }
    
    private func logAudioSessionDetails(_ session: AVAudioSession) {
        let currentCategory = session.category.rawValue
        let currentMode = session.mode.rawValue
        let options = session.categoryOptions
        
        var optionsDesc = [String]()
        if options.contains(.mixWithOthers) { optionsDesc.append("mixWithOthers") }
        if options.contains(.duckOthers) { optionsDesc.append("duckOthers") }
        if options.contains(.allowBluetooth) { optionsDesc.append("allowBluetooth") }
        if options.contains(.defaultToSpeaker) { optionsDesc.append("defaultToSpeaker") }
        if options.contains(.interruptSpokenAudioAndMixWithOthers) { optionsDesc.append("interruptSpokenAudioAndMixWithOthers") }
        if options.contains(.allowBluetoothA2DP) { optionsDesc.append("allowBluetoothA2DP") }
        if options.contains(.allowAirPlay) { optionsDesc.append("allowAirPlay") }
        if #available(iOS 14.5, *) {
            if options.contains(.overrideMutedMicrophoneInterruption) { optionsDesc.append("overrideMutedMicrophoneInterruption") }
        }
        
        let optionsStr = optionsDesc.isEmpty ? "[]" : "[\(optionsDesc.joined(separator: ", "))]"
        log("📊 音频会话详细配置:")
        log("   category: \(currentCategory)")
        log("   mode: \(currentMode)")
        log("   options: \(optionsStr)")
    }
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        DispatchQueue.main.async {
            self.logTextView.text = logMessage + self.logTextView.text
        }
        
        print(logMessage)
    }
}

// MARK: - AVAudioPlayerDelegate
extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        log("🎵 AVAudioPlayer 播放结束: \(flag)")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        log("❌ AVAudioPlayer 解码错误: \(error?.localizedDescription ?? "unknown")")
    }
}

