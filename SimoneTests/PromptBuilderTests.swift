import Testing
@testable import Simone

// 注：v1.0 之前的 scene-based API 已废弃。v1.0 PromptBuilder 只保留 build(style:)。
// 保留文件做最小化有效测试，便于将来扩展。

@Test func buildReturnsSinglePromptFromStyle() {
    guard let style = MoodStyle.presets.first else {
        Issue.record("MoodStyle.presets must not be empty")
        return
    }
    let prompts = PromptBuilder.build(style: style)
    #expect(prompts.count == 1)
    #expect(prompts[0].text == style.prompt)
    #expect(prompts[0].weight == style.promptWeight)
}
