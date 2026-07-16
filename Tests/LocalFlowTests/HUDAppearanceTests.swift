import CoreGraphics
import Testing
@testable import LocalFlowCore

@Suite struct HUDAppearanceTests {

    // MARK: Size

    @Test func everySizeRoundTripsAndHasADisplayName() {
        for size in HUDSize.allCases {
            #expect(HUDSize(rawValue: size.rawValue) == size)
            #expect(!size.displayName.isEmpty)
            #expect(size.id == size.rawValue)
        }
    }

    @Test func standardSizeReproducesLegacyHUD() {
        #expect(HUDSize.standard.panelSize == CGSize(width: 230, height: 52))
        #expect(HUDSize.standard.scale == 1.0)
    }

    @Test func compactIsSmallerAndLargeIsBigger() {
        #expect(HUDSize.compact.panelSize.width < HUDSize.standard.panelSize.width)
        #expect(HUDSize.large.panelSize.width > HUDSize.standard.panelSize.width)
        #expect(HUDSize.compact.scale < 1.0)
        #expect(HUDSize.large.scale > 1.0)
    }

    // MARK: Style

    @Test func everyStyleRoundTripsAndHasADisplayName() {
        for style in HUDStyle.allCases {
            #expect(HUDStyle(rawValue: style.rawValue) == style)
            #expect(!style.displayName.isEmpty)
        }
    }

    @Test func systemStyleShowsAColorLabel() {
        let spec = HUDStyle.system.spec
        #expect(spec.showLabel)
        #expect(spec.backgroundOpacity == 1.0)
    }

    @Test func minimalStyleHidesLabelAndDimsBackground() {
        let spec = HUDStyle.minimal.spec
        #expect(!spec.showLabel)
        #expect(spec.backgroundOpacity < 1.0)
    }

    // MARK: Behavior

    @Test func fullPipelineShowsForEveryActiveState() {
        let b = HUDBehavior.fullPipeline
        #expect(!b.shouldShow(state: .idle))
        #expect(b.shouldShow(state: .recording))
        #expect(b.shouldShow(state: .transcribing))
        #expect(b.shouldShow(state: .cleaning))
        #expect(b.shouldShow(state: .error("boom")))
    }

    @Test func recordingOnlyHidesDuringPostProcessing() {
        let b = HUDBehavior.recordingOnly
        #expect(!b.shouldShow(state: .idle))
        #expect(b.shouldShow(state: .recording))
        #expect(!b.shouldShow(state: .transcribing))
        #expect(!b.shouldShow(state: .cleaning))
        #expect(b.shouldShow(state: .error("boom")))
    }

    @Test func behaviorAndSizeAndStyleAllHaveDisplayNames() {
        for b in HUDBehavior.allCases { #expect(!b.displayName.isEmpty) }
    }

    // MARK: Appearance

    @Test func appearancePairsSizeAndStyle() {
        let a = HUDAppearance(size: .large, style: .vibrant)
        #expect(a.size == .large)
        #expect(a.style == .vibrant)
    }
}
