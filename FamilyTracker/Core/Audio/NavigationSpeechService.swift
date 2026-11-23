import AVFoundation
import Foundation

@MainActor
final class NavigationSpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ maneuver: RouteManeuver) {
        guard let message = Self.message(for: maneuver.code) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio,
                                                            options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: L10n.tr("route.speech.locale"))
        utterance.rate = 0.5
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func message(for code: String) -> String? {
        let key: String
        switch code {
        case "DEPART": key = "route.speech.depart"
        case "TURN_LEFT": key = "route.speech.left"
        case "TURN_RIGHT": key = "route.speech.right"
        case "BEAR_LEFT", "KEEP_LEFT": key = "route.speech.keep_left"
        case "BEAR_RIGHT", "KEEP_RIGHT": key = "route.speech.keep_right"
        case "SHARP_LEFT": key = "route.speech.sharp_left"
        case "SHARP_RIGHT": key = "route.speech.sharp_right"
        case "STRAIGHT", "FOLLOW": key = "route.speech.straight"
        case "ROUNDABOUT_CROSS": key = "route.speech.roundabout"
        case "ROUNDABOUT_LEFT": key = "route.speech.roundabout_left"
        case "ROUNDABOUT_RIGHT": key = "route.speech.roundabout_right"
        case "ROUNDABOUT_BACK": key = "route.speech.roundabout_back"
        case "MAKE_UTURN", "TRY_MAKE_UTURN": key = "route.speech.uturn"
        case "TAKE_EXIT", "ENTRANCE_RAMP": key = "route.speech.exit"
        case "MOTORWAY_EXIT_LEFT": key = "route.speech.exit_left"
        case "MOTORWAY_EXIT_RIGHT": key = "route.speech.exit_right"
        case "ENTER_MOTORWAY", "ENTER_FREEWAY", "ENTER_HIGHWAY": key = "route.speech.highway"
        case "TAKE_FERRY": key = "route.speech.ferry"
        case "SWITCH_PARALLEL_ROAD", "SWITCH_MAIN_ROAD": key = "route.speech.follow_map"
        case "WAYPOINT_LEFT", "WAYPOINT_RIGHT", "WAYPOINT_REACHED": key = "route.speech.waypoint"
        case "ARRIVE", "ARRIVE_RIGHT", "ARRIVE_LEFT": key = "route.speech.arrive"
        default: return nil
        }
        return L10n.tr(key)
    }
}
