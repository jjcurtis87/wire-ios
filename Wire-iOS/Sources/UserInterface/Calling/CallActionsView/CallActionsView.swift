//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import UIKit

protocol CallActionsViewDelegate: class {
    func callActionsView(_ callActionsView: CallActionsView, perform action: CallActionsViewAction)
}

enum MediaState {
    case sendingVideo, notSendingVideo(speakerEnabled: Bool)
    
    var isSendingVideo: Bool {
        guard case .sendingVideo = self else { return false }
        return true
    }
    
    var showSpeaker: Bool {
        guard case .notSendingVideo = self else { return false }
        return true
    }
    
    var isSpeakerEnabled: Bool {
        guard case .notSendingVideo(true) = self else { return false }
        return true
    }
}

// This protocol describes the input for a `CallActionsView`.
protocol CallActionsViewInputType {
    var canToggleMediaType: Bool { get }
    var isAudioCall: Bool { get }
    var isMuted: Bool { get }
    var isTerminating: Bool { get }
    var canAccept: Bool { get }
    var mediaState: MediaState { get }
}

extension CallActionsViewInputType {
    func appearance(with variant: ColorSchemeVariant) -> CallActionAppearance {
        return isAudioCall && variant == .light ? .light : .dark
    }
}

// The ouput actions a `CallActionsView` can perform.
enum CallActionsViewAction {
    case toggleMuteState
    case toggleVideoState
    case toggleSpeakerState
    case acceptCall
    case terminateCall
    case flipCamera
}

// A view showing multiple buttons depenging on the given `CallActionsView.Input`.
// Button touches result in `CallActionsView.Action` cases to be sent to the objects delegate.
final class CallActionsView: UIView {
    
    weak var delegate: CallActionsViewDelegate?
    
    var isCompact = false {
        didSet {
            lastInput.apply(update)
        }
    }

    var variant: ColorSchemeVariant = .light {
        didSet {
            lastInput.apply(update)
        }
    }

    private let verticalStackView = UIStackView(axis: .vertical)
    private let topStackView = UIStackView(axis: .horizontal)
    private let bottomStackView = UIStackView(axis: .horizontal)
    
    private var lastInput: CallActionsViewInputType?
    
    // Buttons
    private let muteCallButton = IconLabelButton.muteCall()
    private let videoButton = IconLabelButton.video()
    private let speakerButton = IconLabelButton.speaker()
    private let flipCameraButton = IconLabelButton.flipCamera()
    private let firstBottomRowSpacer = UIView()
    private let endCallButton = IconButton.endCall()
    private let secondBottomRowSpacer = UIView()
    private let acceptCallButton = IconButton.acceptCall()
    
    private var allButtons: [UIButton] {
        return [muteCallButton, videoButton, speakerButton, flipCameraButton, endCallButton, acceptCallButton]
    }
    
    // MARK: - Setup
    
    init() {
        super.init(frame: .zero)
        setupViews()
        createConstraints()
    }
    
    @available(*, unavailable) required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        topStackView.distribution = .equalSpacing
        bottomStackView.distribution = .equalSpacing
        bottomStackView.alignment = .top
        addSubview(verticalStackView)
        [muteCallButton, videoButton, flipCameraButton, speakerButton].forEach(topStackView.addArrangedSubview)
        [firstBottomRowSpacer, endCallButton, secondBottomRowSpacer, acceptCallButton].forEach(bottomStackView.addArrangedSubview)
        [topStackView, bottomStackView].forEach(verticalStackView.addArrangedSubview)
        allButtons.forEach { $0.addTarget(self, action: #selector(performButtonAction), for: .touchUpInside) }
    }
    
    private func createConstraints() {
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: verticalStackView.leadingAnchor),
            topAnchor.constraint(equalTo: verticalStackView.topAnchor),
            trailingAnchor.constraint(equalTo: verticalStackView.trailingAnchor),
            bottomAnchor.constraint(equalTo: verticalStackView.bottomAnchor),
            firstBottomRowSpacer.widthAnchor.constraint(equalToConstant: IconButton.width),
            firstBottomRowSpacer.heightAnchor.constraint(equalToConstant: IconButton.height),
            secondBottomRowSpacer.widthAnchor.constraint(equalToConstant: IconButton.width),
            secondBottomRowSpacer.heightAnchor.constraint(equalToConstant: IconButton.height)
        ])
    }
    
    // MARK: - State Input
    
    // Entry single point for all state changes.
    // All side effects should be started from this method.
    func update(with input: CallActionsViewInputType) {
        muteCallButton.isSelected = input.isMuted
        videoButton.isEnabled = input.canToggleMediaType
        videoButton.isSelected = input.mediaState.isSendingVideo
        flipCameraButton.isHidden = input.mediaState.showSpeaker
        speakerButton.isHidden = !input.mediaState.showSpeaker
        speakerButton.isSelected = input.mediaState.isSpeakerEnabled
        acceptCallButton.isHidden = !input.canAccept
        firstBottomRowSpacer.isHidden = input.canAccept || isCompact
        secondBottomRowSpacer.isHidden = isCompact
        verticalStackView.axis = isCompact ? .horizontal : .vertical
        [muteCallButton, videoButton, flipCameraButton, speakerButton].forEach { $0.appearance = input.appearance(with: variant) }
        alpha = input.isTerminating ? 0.4 : 1
        isUserInteractionEnabled = !input.isTerminating
        lastInput = input
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        verticalStackView.spacing = {
            guard isCompact else { return 64 } // Calculate the spacing manually in compact mode
            let iconCount = topStackView.visibleSubviews.count + bottomStackView.visibleSubviews.count
            return (bounds.width - (CGFloat(iconCount) * IconButton.width)) / CGFloat(iconCount - 1)
        }()
        topStackView.spacing = isCompact ? verticalStackView.spacing : 0
        bottomStackView.spacing = isCompact ? verticalStackView.spacing : 0
    }
    
    // MARK: - Action Output
    
    @objc private func performButtonAction(_ sender: IconLabelButton) {
        delegate?.callActionsView(self, perform: action(for: sender))
    }
    
    private func action(for button: IconLabelButton) -> CallActionsViewAction {
        switch button {
        case muteCallButton: return .toggleMuteState
        case videoButton: return .toggleVideoState
        case speakerButton: return .toggleSpeakerState
        case flipCameraButton: return .flipCamera
        case endCallButton: return .terminateCall
        case acceptCallButton: return .acceptCall
        default: fatalError("Unexpected Button: \(button)")
        }
    }
    
}