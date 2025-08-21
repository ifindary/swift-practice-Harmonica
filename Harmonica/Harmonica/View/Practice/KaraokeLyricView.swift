import SwiftUI
import SwiftData

struct KaraokeLyricView: View {
    @StateObject private var viewModel: KaraokeLyricViewModel
    
    // 얘는 왜 이렇게 처리하지?
//    let songInfo: SongInfo
    init(songInfo: SongInfo) {
        _viewModel = StateObject(wrappedValue: KaraokeLyricViewModel(songInfo: songInfo))
    }

    let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
    
    var body: some View {
        
        ZStack{
            Image("MetronomeField")
                .resizable()
                .scaledToFit()
                .frame(width: 1250, height: 279)
            VStack {
                HStack {
                    Button(action: {
                        
                    }) {
                        Image("Power")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 76, height: 76)
                    }
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Image(viewModel.mode == .ar ? "SeonChang": "WhoChang")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 121, height: 67)
                        .padding(.trailing, 5)
                }
                .padding(.bottom, 3)
            }
            .frame(width: 1250, height: 279)
                
            if viewModel.isPlaying || viewModel.countdown != nil {
                HStack(spacing: 20) {
                    ForEach(0..<viewModel.beatsPerMeasure, id: \.self) { index in
                        ZStack {
                            Image("ClapEmpty")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 115)
                            
                            if viewModel.getMetronomeImageState(for: index) {
                                Image("ClapFilled")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 115)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.bottom, 0)
        .padding(.top, 40)
        
        ZStack{
            RoundedRectangle(cornerRadius: 40)
                .fill(Color(Color(hex: "DDDDDD")))
                .frame(width: 1250, height: 421)
            
            if let count = viewModel.countdown {
                let circleColors: [Color] = [Color(hex:"00484A"), Color(hex:"007A7D"), Color(hex:"00ADB2"), Color(hex:"04D1D7")]
                VStack {
                    HStack(spacing: 20) {
                        ForEach(0..<4) { index in
                            if index <= count {
                                ZStack {
                                    Circle()
                                        .fill(circleColors[index])
                                        .frame(width: 50, height: 50)
                                    Text(["1", "2", "3", "4"][index])
                                        .font(.system(size: 40))
                                        .bold()
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
                .padding(.top, 20)
                .padding(.leading, 120)
            }
            
            VStack{
                ZStack(alignment: .leading) {
                    Text(viewModel.fullText)
                        .foregroundColor(.gray)
                        .bold()
                    
                    HStack(spacing: 0) {
                        Text(viewModel.highlightedText)
                            .foregroundColor(Color(hex: "00B6BA"))
                            .bold()
                        
                        //두개로 label을 나눠서 마스크 & 텍스트를 두개로 해버리는게 나을까?
                        //아니면 mask가 Text 위치를 따라갈 수 있는 방법이 있을까?
                        if !viewModel.currentChar.isEmpty {
                            Text(viewModel.currentChar)
                                .foregroundColor(Color(hex: "00B6BA"))
                                .bold()
                                .mask(
                                    GeometryReader { geo in
                                        Rectangle()
                                            .frame(width: geo.size.width * viewModel.currentCharacterProgress)
                                    }
                                )
                        }
                    }
                }
                .font(.system(size: 96))
                .padding(.bottom, 0)
                
                ZStack{
                    if viewModel.hasNextLine {
                        ZStack(alignment: .leading) {
                            Text(viewModel.nextfullText)
                                .foregroundColor(.gray)
                                .bold()
                            
                            HStack(spacing: 0) {
                                Text(viewModel.nexthighlightedtext)
                                    .foregroundColor(Color(hex: "00B6BA"))
                                    .bold()

                                if !viewModel.nextcurrentChar.isEmpty {
                                    Text(viewModel.nextcurrentChar)
                                        .foregroundColor(Color(hex: "00B6BA"))
                                        .bold()
                                        .mask(
                                            GeometryReader { geo in
                                                Rectangle()
                                                    .frame(width: geo.size.width * viewModel.nextCharacterProgress)
                                            }
                                        )
                                }
                            }
                        }
                        .font(.system(size: 96))
                        .padding(.top, 0)
                    }
                }
            }
        }
        .padding(.bottom, 40)
        .padding(.top, 16)
            
        HStack(spacing: 45){
            Button(action: viewModel.previous) {
                Image(viewModel.isBackPressed ? "BackPressed" : "Back")
                    .resizable()
                    .frame(width: 172, height: 172)
                    .scaledToFit()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                viewModel.isBackPressed = true
                            }
                            .onEnded { _ in
                                viewModel.isBackPressed = false
                                viewModel.previous()
                            }
                    )
            }
            .disabled(viewModel.currentSegmentIndex <= 0)
            
            Button(action: viewModel.replay) {
                Image(viewModel.isRetryPressed ? "Retry_Pressed" : "Retry")
                    .resizable()
                    .frame(width: 172, height: 172)
                    .scaledToFit()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                viewModel.isRetryPressed = true
                            }
                            .onEnded { _ in
                                viewModel.isRetryPressed = false
                                viewModel.replay()
                            }
                    )
            }
            
            Button(action: viewModel.next) {
                Image(viewModel.isNextPressed ? "Next_Pressed" : "Next")
                    .resizable()
                    .frame(width: 172, height: 172)
                    .scaledToFit()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                viewModel.isNextPressed = true
                            }
                            .onEnded { _ in
                                viewModel.isNextPressed = false
                                viewModel.next()
                            }
                    )
            }
            .disabled(viewModel.currentSegmentIndex >= viewModel.segments.count - 1)
        }
        .padding(.bottom, 40)
        
        .onAppear {
            viewModel.setupAudio()
            viewModel.setupMetronomeSound()
            viewModel.loadLyrics()
            
            if !viewModel.lyricLines.isEmpty {
                viewModel.updateCurrentLines()
            }
            viewModel.replay()
        }
        .onDisappear {
            viewModel.stopPlayback()
            viewModel.stopMetronome()
        }
        
        .onReceive(timer) { _ in
            viewModel.updateTimer()
        }
        .onReceive(timer) { _ in
            viewModel.updateTimer2() // 수정 필요
        }
        .onReceive(timer) { _ in
            viewModel.updateMetronome()
        }
    }
}

#Preview {
    KaraokeLyricView(songInfo: .preview)
}
