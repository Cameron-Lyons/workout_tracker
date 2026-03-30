import SwiftUI

enum TodayViewMetrics {
    static let spotlightCornerRadius: CGFloat = 22
}

struct SessionStartRequest: Identifiable {
    let planID: UUID
    let templateID: UUID
    let templateName: String

    var id: String {
        "\(planID.uuidString)-\(templateID.uuidString)"
    }
}

func handleSessionStart(
    activeDraft: SessionDraft?,
    pendingStartRequest: Binding<SessionStartRequest?>,
    planID: UUID,
    templateID: UUID,
    templateName: String,
    onResumeCurrent: () -> Void,
    onStartNew: (_ planID: UUID, _ templateID: UUID) -> Void
) {
    if activeDraft?.planID == planID, activeDraft?.templateID == templateID {
        onResumeCurrent()
        return
    }

    guard activeDraft != nil else {
        onStartNew(planID, templateID)
        return
    }

    pendingStartRequest.wrappedValue = SessionStartRequest(
        planID: planID,
        templateID: templateID,
        templateName: templateName
    )
}

func setTargetRepSummary(for targets: [SetTarget]) -> String {
    let labels = targets.reduce(into: [String]()) { partialResult, target in
        let label = target.repRange.displayLabel
        if partialResult.last != label {
            partialResult.append(label)
        }
    }

    return labels.isEmpty ? "-" : labels.joined(separator: "/")
}

func weekdaySummary(_ weekdays: [Weekday], emptyLabel: String) -> String {
    guard !weekdays.isEmpty else {
        return emptyLabel
    }

    return weekdays.map { $0.shortLabel.uppercased() }.joined(separator: " • ")
}

private struct SessionStartConfirmationDialogModifier: ViewModifier {
    @Binding var pendingStartRequest: SessionStartRequest?
    let activeDraft: SessionDraft?
    let onResumeCurrent: () -> Void
    let onReplace: (_ request: SessionStartRequest) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Replace current session?",
            isPresented: Binding(
                get: { pendingStartRequest != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingStartRequest = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingStartRequest {
                Button("Resume Current Session") {
                    onResumeCurrent()
                    self.pendingStartRequest = nil
                }

                Button("Replace and Start \(pendingStartRequest.templateName)", role: .destructive) {
                    onReplace(pendingStartRequest)
                    self.pendingStartRequest = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingStartRequest = nil
            }
        } message: {
            if let activeDraft, let pendingStartRequest {
                Text(
                    "\(activeDraft.templateNameSnapshot) is still autosaved. "
                        + "Replacing it will discard that session and start "
                        + "\(pendingStartRequest.templateName) instead."
                )
            }
        }
    }
}

extension View {
    func sessionStartConfirmationDialog(
        pendingStartRequest: Binding<SessionStartRequest?>,
        activeDraft: SessionDraft?,
        onResumeCurrent: @escaping () -> Void,
        onReplace: @escaping (_ request: SessionStartRequest) -> Void
    ) -> some View {
        modifier(
            SessionStartConfirmationDialogModifier(
                pendingStartRequest: pendingStartRequest,
                activeDraft: activeDraft,
                onResumeCurrent: onResumeCurrent,
                onReplace: onReplace
            )
        )
    }
}
