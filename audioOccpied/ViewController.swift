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
    
    private var delayTimer: Timer?
    private var remainingSeconds: Int = 0
    private var isInDelayCountdown: Bool = false
    
    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始中断测试", for: .normal)
        button.setTitle("停止中断", for: .selected)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let delaySwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = false
        sw.translatesAutoresizingMaskIntoConstraints = false
        return sw
    }()
    
    private let delayLabel: UILabel = {
        let label = UILabel()
        label.text = "延迟2秒开始"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = """
        📱 音频中断测试工具
        
        功能：强制中断其他应用的音频播放
        
        使用步骤：
        1. 确保目标应用正在播放音频
        2. 选择是否延迟6秒开始
        3. 点击"开始中断"按钮
        4. 观察目标应用是否收到中断通知
        
        日志会显示中断配置详情
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
        setupAudioSessionInterruptionMonitoring()
        
        log("✅ 测试工具已启动")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        let logLabel = createLabel(text: "日志输出:")
        
        view.addSubview(infoLabel)
        view.addSubview(delayLabel)
        view.addSubview(delaySwitch)
        view.addSubview(playButton)
        view.addSubview(logLabel)
        view.addSubview(logTextView)
        
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            delayLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 25),
            delayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            delaySwitch.centerYAnchor.constraint(equalTo: delayLabel.centerYAnchor),
            delaySwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            playButton.topAnchor.constraint(equalTo: delayLabel.bottomAnchor, constant: 25),
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
        // 这个测试应用是用来中断其他应用的，不需要监听自己的中断
        // 只监听路由变化用于调试
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        log("ℹ️ 测试应用角色：中断其他应用，不监听自身中断")
    }
    
    private func setupAudioSessionInterruptionMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            log("⚠️ 音频会话被中断")
        case .ended:
            log("✅ 音频会话中断结束")
            startAudio()
        @unknown default:
            log("❓ 未知的音频中断类型")
        }
    }
    
    @objc private func playButtonTapped() {
        if isInDelayCountdown {
            // 如果在倒计时期间再次点击，取消倒计时
            cancelDelayCountdown()
            log("⏹️ 已取消延迟中断")
            return
        }
        
        if playButton.isSelected {
            stopAudio()
            playButton.isSelected = false
        } else {
            startAudio()
        }
    }
    
    @objc private func clearLog() {
        logTextView.text = ""
    }
    
    private func startAudio() {
        log("🚀 开始音频中断测试")
        
        // 检查当前是否有其他音频在播放
        let session = AVAudioSession.sharedInstance()
        if session.isOtherAudioPlaying {
            log("✅ 检测到其他应用正在播放音频")
        } else {
            log("⚠️ 未检测到其他应用正在播放音频")
            log("   请确保目标应用:")
            log("   1. 设置了正确的音频会话类别")
            log("   2. 调用了 setActive(true)")
            log("   3. 开始播放音频")
        }
        
        // 根据延迟开关决定是否延迟执行
        if delaySwitch.isOn {
            startDelayCountdown(seconds: 2)
        } else {
            playButton.isSelected = true
            forceInterruptionTest()
        }
    }
    
    private func startDelayCountdown(seconds: Int) {
        remainingSeconds = seconds
        isInDelayCountdown = true
        playButton.isSelected = true
        
        log("⏰ 延迟\(seconds)秒后开始中断...")
        updateCountdownButtonTitle()
        
        // 创建定时器并添加到RunLoop，确保在后台也能执行
        delayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.remainingSeconds -= 1
            self.updateCountdownButtonTitle()
            
            if self.remainingSeconds <= 0 {
                timer.invalidate()
                self.delayTimer = nil
                self.isInDelayCountdown = false
                self.log("🎯 延迟结束，开始中断测试")
                self.forceInterruptionTest()
            }
        }
        
        // 确保定时器在后台模式下也能继续运行
        if let timer = delayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func cancelDelayCountdown() {
        delayTimer?.invalidate()
        delayTimer = nil
        isInDelayCountdown = false
        remainingSeconds = 0
        playButton.isSelected = false
        playButton.setTitle("开始中断测试", for: .normal)
        playButton.setTitle("停止中断", for: .selected)
    }
    
    private func updateCountdownButtonTitle() {
        if isInDelayCountdown && remainingSeconds > 0 {
            playButton.setTitle("取消 (\(remainingSeconds)s)", for: .normal)
            playButton.setTitle("取消 (\(remainingSeconds)s)", for: .selected)
        } else {
            playButton.setTitle("开始中断测试", for: .normal)
            playButton.setTitle("停止中断", for: .selected)
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
    
    // MARK: - 音频播放
    private func playAudioWithPlayer(volume: Float = 1, loops: Int = -1, description: String = "C大调旋律") -> Bool {
        guard let audioFileURL = generateTestAudioFile() else {
            log("❌ 生成测试音频文件失败")
            return false
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = loops
            audioPlayer?.volume = volume
            
            let success = audioPlayer?.play() ?? false
            if success {
                log("✅ AVAudioPlayer 开始播放（\(description)）")
                log("   音量: \(volume)")
                log("   是否正在播放: \(audioPlayer?.isPlaying ?? false)")
                
                // 打印当前音频会话配置
                let currentSession = AVAudioSession.sharedInstance()
                logAudioSessionDetails(currentSession)
                
                // 延迟检查音频会话状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.logAudioSessionStatus()
                }
                return true
            } else {
                log("❌ AVAudioPlayer play() 返回 false")
                return false
            }
        } catch {
            log("❌ AVAudioPlayer 初始化失败: \(error.localizedDescription)")
            return false
        }
    }
    
    
    
    
    // MARK: - 强制中断测试
    private func forceInterruptionTest() {
        log("🚀 开始强制中断测试")
        log("   目标：强制中断使用 .mixWithOthers 的主端应用")
        
        // 首先播放音乐
        playAudioForInterruptionTest()
        log("🎵 开始播放测试音乐（C大调旋律）")
        
        // 方法1：使用高优先级的音频模式（只配置，不重复播放音乐）
        forceInterruptionWithHighPriorityMode()
        
        // 方法2：使用特定的音频配置（只配置，不重复播放音乐）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.forceInterruptionWithSpecificConfiguration()
        }
        
        // 方法3：模拟电话来电场景（只配置，不重复播放音乐）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.simulatePhoneCallScenario()
        }
    }
    
    private func forceInterruptionWithHighPriorityMode() {
        log("📞 方法1：使用高优先级音频模式")
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 使用 .voiceChat 模式，这是系统优先级最高的模式之一
            // 即使其他应用使用 .mixWithOthers，也会被中断
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [])
            
            // 激活时使用 .notifyOthersOnDeactivation，这会通知其他应用
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            log("✅ 配置为 .playAndRecord + .voiceChat 模式")
            log("   这是系统优先级最高的音频模式之一")
            log("   应该能强制中断其他应用的音频")
            
        } catch {
            log("❌ 配置高优先级模式失败: \(error.localizedDescription)")
        }
    }
    
    private func forceInterruptionWithSpecificConfiguration() {
        log("🎯 方法2：使用特定配置强制中断")
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 使用 .videoChat 模式，这也是高优先级模式
            // 添加 .defaultToSpeaker 和 .allowBluetooth
            let options: AVAudioSession.CategoryOptions = [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP
            ]
            
            try session.setCategory(.playAndRecord, mode: .videoChat, options: options)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            log("✅ 配置为 .playAndRecord + .videoChat 模式")
            log("   选项: defaultToSpeaker, allowBluetooth, allowBluetoothA2DP")
            log("   这种配置常用于视频通话，优先级很高")
            
        } catch {
            log("❌ 配置特定模式失败: \(error.localizedDescription)")
        }
    }
    
    private func simulatePhoneCallScenario() {
        log("📱 方法3：模拟电话来电场景（使用麦克风）")
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 模拟电话场景：使用 .voiceChat 模式 + 特定选项
            let options: AVAudioSession.CategoryOptions = [
                .allowBluetooth,
                .allowAirPlay,
                .allowBluetoothA2DP,
                .defaultToSpeaker  // 电话通常使用扬声器
            ]
            
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: options)
            
            // 使用 .notifyOthersOnDeactivation 激活
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            log("✅ 模拟电话来电配置完成")
            log("   配置: .playAndRecord + .voiceChat")
            log("   选项: allowBluetooth, allowAirPlay, allowBluetoothA2DP, defaultToSpeaker")
            log("   这种配置最接近真实的电话中断场景")
            
            // 检查系统状态
            if session.secondaryAudioShouldBeSilencedHint {
                log("✅ 系统提示：其他音频应该被静音")
            }
            
            if session.isOtherAudioPlaying {
                log("✅ 检测到其他应用正在播放音频")
                log("   应该会收到中断通知")
            }
            
            // 关键：开始使用麦克风（模拟通话）
            startMicrophoneForPhoneCall()
            
            // 同时播放一些音频（模拟通话声音）
            playPhoneCallAudio()
            
        } catch {
            log("❌ 模拟电话场景失败: \(error.localizedDescription)")
        }
    }
    
    private func startMicrophoneForPhoneCall() {
        log("🎤 开始使用麦克风（模拟通话）")
        
        // 创建新的音频引擎用于麦克风采集
        let phoneCallEngine = AVAudioEngine()
        
        do {
            let inputNode = phoneCallEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            log("📡 麦克风配置:")
            log("   采样率: \(inputFormat.sampleRate) Hz")
            log("   声道数: \(inputFormat.channelCount)")
            
            // 安装 tap 采集麦克风数据（模拟通话中的语音输入）
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
                // 模拟处理通话语音数据
                let channelData = buffer.floatChannelData
                let frameLength = Int(buffer.frameLength)
                
                // 计算音量（模拟通话中的语音活动）
                if let data = channelData?.pointee {
                    var sum: Float = 0
                    for i in 0..<frameLength {
                        let value = data[i]
                        sum += value * value
                    }
                    let rms = sqrt(sum / Float(frameLength))
                    
                    // 定期记录音量（模拟通话中的语音检测）
                    if Int(time.sampleTime) % Int(inputFormat.sampleRate) == 0 {
                        DispatchQueue.main.async {
                            self?.log("📞 通话中... 语音电平: \(String(format: "%.4f", rms))")
                        }
                    }
                }
            }
            
            // 启动音频引擎
            try phoneCallEngine.start()
            
            // 保存引用
            self.audioEngine = phoneCallEngine
            
            log("✅ 麦克风已启动（模拟通话中）")
            log("   这会强制占用麦克风设备")
            log("   使用麦克风的应用应该会收到中断")
            
        } catch {
            log("❌ 启动麦克风失败: \(error.localizedDescription)")
        }
    }
    
    private func playPhoneCallAudio() {
        log("🔊 播放通话音频（模拟对方声音）")
        
        // 生成一个简单的通话音频（模拟对方说话）
        let phoneCallEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        phoneCallEngine.attach(playerNode)
        
        let format = phoneCallEngine.mainMixerNode.outputFormat(forBus: 0)
        phoneCallEngine.connect(playerNode, to: phoneCallEngine.mainMixerNode, format: format)
        
        // 生成一个简单的语音频率的正弦波（模拟通话声音）
        if let buffer = generatePhoneCallBuffer(format: format) {
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        }
        
        do {
            try phoneCallEngine.start()
            playerNode.play()
            
            log("✅ 通话音频已开始播放")
            log("   频率: 300-800Hz（模拟语音范围）")
            log("   音量: 90%")
            
        } catch {
            log("❌ 播放通话音频失败: \(error.localizedDescription)")
        }
    }
    
    private func generatePhoneCallBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let duration = 2.0  // 2秒的缓冲区
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        let channels = Int(format.channelCount)
        let floatChannelData = buffer.floatChannelData
        
        // 使用变化的频率模拟语音
        let baseFrequency = 300.0
        let frequencyRange = 500.0  // 300-800Hz
        
        for frame in 0..<Int(frameCount) {
            // 随时间变化的频率（模拟语音的音调变化）
            let time = Double(frame) / sampleRate
            let frequency = baseFrequency + (frequencyRange * (0.5 + 0.5 * sin(2.0 * .pi * 2.0 * time)))
            
            let value = sin(2.0 * .pi * frequency * Double(frame) / sampleRate)
            
            // 应用包络使声音更自然
            let envelope: Float
            let frameProgress = Float(frame) / Float(frameCount)
            if frameProgress < 0.1 {
                envelope = frameProgress / 0.1  // 淡入
            } else if frameProgress > 0.9 {
                envelope = (1.0 - frameProgress) / 0.1  // 淡出
            } else {
                envelope = 1.0
            }
            
            let amplitude: Float = 1 * envelope  
            
            for channel in 0..<channels {
                floatChannelData?[channel][frame] = Float(value) * amplitude
            }
        }
        
        return buffer
    }
    
    private func playAudioForInterruptionTest() {
        let success = playAudioWithPlayer(volume: 1.0, loops: -1, description: "测试音乐（C大调旋律）")
        if success {
            log("✅ 开始播放测试音频")
            log("   音量: 100%")
            log("   循环播放: 是")
        }
    }
    
    
    // MARK: - 音频会话配置
    private func configureAudioSession(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode = .default,
        options: AVAudioSession.CategoryOptions = [],
        activateOptions: AVAudioSession.SetActiveOptions = []
    ) throws {
        let session = AVAudioSession.sharedInstance()
        
        // 先停用旧会话
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        
        // 配置新的音频会话
        try session.setCategory(category, mode: mode, options: options)
        
        // 激活音频会话
        try session.setActive(true, options: activateOptions)
        
        // 打印详细配置参数
        logAudioSessionDetails(session)
    }
    
    // MARK: - 音频生成
    private func generateTestAudioFile() -> URL? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_music.m4a")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        let sampleRate = 44100.0
        let duration = 4.0  // 延长到4秒以播放完整旋律
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            let format = audioFile.processingFormat
            
            if let buffer = generateSimpleMusicBuffer(duration: duration, format: format) {
                try audioFile.write(from: buffer)
                log("✅ 生成简单音乐文件成功（C大调旋律）")
                return fileURL
            }
        } catch {
            log("❌ 生成音乐文件失败: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func generateSimpleMusicBuffer(duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        let channels = Int(format.channelCount)
        let floatChannelData = buffer.floatChannelData
        
        // C大调音阶频率 (C4, D4, E4, F4, G4, A4, B4, C5)
        let cMajorScale: [Double] = [
            261.63,  // C4
            293.66,  // D4
            329.63,  // E4
            349.23,  // F4
            392.00,  // G4
            440.00,  // A4
            493.88,  // B4
            523.25   // C5
        ]
        
        // 每个音符的持续时间（秒）
        let noteDuration = duration / Double(cMajorScale.count)
        let framesPerNote = Int(sampleRate * noteDuration)
        
        for noteIndex in 0..<cMajorScale.count {
            let frequency = cMajorScale[noteIndex]
            let startFrame = noteIndex * framesPerNote
            let endFrame = min(startFrame + framesPerNote, Int(frameCount))
            
            for frame in startFrame..<endFrame {
                // 计算当前帧在音符中的位置（用于淡入淡出）
                let noteFrame = frame - startFrame
                let noteProgress = Double(noteFrame) / Double(framesPerNote)
                
                // 淡入淡出包络
                var envelope: Float = 1.0
                if noteProgress < 0.1 {
                    // 淡入
                    envelope = Float(noteProgress / 0.1)
                } else if noteProgress > 0.9 {
                    // 淡出
                    envelope = Float((1.0 - noteProgress) / 0.1)
                }
                
                // 生成正弦波
                let value = sin(2.0 * .pi * frequency * Double(frame) / sampleRate)
                
                // 应用包络
                let amplitude: Float = 1 * envelope
                
                for channel in 0..<channels {
                    floatChannelData?[channel][frame] = Float(value) * amplitude
                }
            }
        }
        
        // 填充剩余帧（如果有）
        let totalNotesFrames = cMajorScale.count * framesPerNote
        if totalNotesFrames < Int(frameCount) {
            for frame in totalNotesFrames..<Int(frameCount) {
                for channel in 0..<channels {
                    floatChannelData?[channel][frame] = 0.0
                }
            }
        }
        
        return buffer
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
    
    private func logAudioSessionStatus() {
        let session = AVAudioSession.sharedInstance()
        log("📊 音频会话状态检查:")
        log("   category: \(session.category.rawValue)")
        log("   mode: \(session.mode.rawValue)")
        log("   isOtherAudioPlaying: \(session.isOtherAudioPlaying)")
        log("   secondaryAudioShouldBeSilencedHint: \(session.secondaryAudioShouldBeSilencedHint)")
        
        if let route = session.currentRoute.outputs.first {
            log("   输出设备: \(route.portType.rawValue)")
        }
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

