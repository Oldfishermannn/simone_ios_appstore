import Testing
@testable import Simone

@Test func buildPromptsWithStyleOnly() {
    let prompts = PromptBuilder.build(scene: nil, style: .jazz)
    #expect(prompts.count == 1)
    #expect(prompts[0].text == "Smooth jazz with walking upright bass and brushed drums")
    #expect(prompts[0].weight == 1.0)
}

@Test func buildPromptsWithSceneOnly() {
    let prompts = PromptBuilder.build(scene: .study, style: nil)
    #expect(prompts.count == 1)
    #expect(prompts[0].text == "study background quiet unobtrusive")
    #expect(prompts[0].weight == 0.3)
}

@Test func buildPromptsWithBothMixed() {
    let prompts = PromptBuilder.build(scene: .drive, style: .lofi)
    #expect(prompts.count == 2)
    #expect(prompts[0].text == "Lo-fi hip hop with dusty vinyl crackle and mellow Rhodes piano")
    #expect(prompts[0].weight == 1.0)
    #expect(prompts[1].text == "driving steady rhythmic cruising")
    #expect(prompts[1].weight == 0.3)
}

@Test func buildPromptsWithNeitherReturnsEmpty() {
    let prompts = PromptBuilder.build(scene: nil, style: nil)
    #expect(prompts.isEmpty)
}

@Test func toJSONProducesValidFormat() throws {
    let prompts = PromptBuilder.build(scene: .chill, style: .ambient)
    let json = PromptBuilder.toJSON(prompts: prompts)
    let data = try JSONSerialization.jsonObject(with: json) as! [String: Any]
    #expect(data["command"] as? String == "set_prompts")
    let promptsArray = data["prompts"] as! [[String: Any]]
    #expect(promptsArray.count == 2)
}
