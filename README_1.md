
# BookReaderTTS - 아이폰 백그라운드 TTS 리더

## 기능
- 파일: .txt .md (utf-8, cp949, euc-kr 자동)
- 자동 목차 v4: 대사 제외 ("그렇겠군요." 같은 반복 대사 무시), 중복 방지
- 목차 없을 때 단락 기반 fallback (15~20구간)
- **iPhone TTS**: AVSpeechSynthesizer ko-KR
- **백그라운드 재생**: Info.plist UIBackgroundModes audio + AVAudioSession .playback
- 하이라이트: 현재 읽는 단어 노란색
- 속도 조절: 느리게/보통/빠르게

## SideStore로 설치 (IPA 빌드 방법)

### 방법 A: Xcode에서 IPA 빌드 (Mac 필요)
1. Xcode 설치
2. 이 폴더 열기: BookReaderTTS.xcodeproj (아래에 프로젝트 생성 명령 포함)
3. Team을 Personal Team으로 설정, Bundle ID를 com.yourname.bookreadertts -> 본인 ID로 변경 (예: com.hong.bookreader)
4. Product > Archive > Distribute App > Ad Hoc > Export로 IPA 생성
5. SideStore에서 IPA 공유로 설치

### 방법 B: Xcode 없이 SideStore 직접 빌드 (SideStore + AltServer)
1. SideStore 앱 설치 (https://sidestore.io)
2. 이 소스 zip을 iPhone 파일에 저장
3. SideStore > My Apps > + > 이 IPA(빌드 후) 선택

### 프로젝트 생성 터미널:
cd BookReaderTTS-iOS
xcodegen 없이 수동: Xcode > New Project > iOS App > SwiftUI > 이름 BookReaderTTS, Bundle ID 변경, 파일 교체

### 빠른 테스트 (Playground)
- iPhone에서 Swift Playgrounds 앱으로 ContentView.swift 실행 가능

## 백그라운드 동작 확인
- 재생 중 홈 버튼 눌러도 계속 읽음
- 잠금 화면에서 재생/일시정지 컨트롤 표시 (MPNowPlayingInfoCenter 추가 가능)
- 설정 > 음성: 한국어 Siri 음성 다운로드 필요 (설정 > 손쉬운 사용 > 음성 콘텐츠 > 음성)

## 다음 개선
- 잠금화면 커버아트, 다음/이전 챕터
- .docx 지원 (ZIP 파서 추가)
- 속도 슬라이더 0.3~0.7

Bundle ID 변경 후 빌드하세요!


## Auto Build
Push to main -> Actions -> IPA download -> SideStore install
