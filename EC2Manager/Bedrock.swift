//
//  Bedrock.swift
//  EC2Manager
//
//  Created by Stormacq, Sebastien on 03/02/2024.
//

import Foundation


public enum BedrockModelProvider : String {
    case titan = "Amazon"
    case claude = "Anthropic"
    case stabledifusion = "Stability AI"
    case j2 = "AI21 Labs"
}

public enum BedrockClaudeModel : String {
    case claude_instant_v1 = "anthropic.claude-instant-v1"
    case claudev1 = "anthropic.claude-v1"
    case claudev2 = "anthropic.claude-v2"
    case claudev2_1 = "anthropic.claude-v2:1"
}

public enum BedrockClaudeModelArn: String {
    case instant_v1 = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-instant-v1"
    case claudev1 = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v1"
    case claudev2 = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2"
    case claudev2_1 = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-v2:1"

}

public struct ClaudeModelParameters: Encodable {
    public init(prompt: String) {
        self.prompt = "\n\nHuman: \(prompt)\n\nAssistant:"
    }
    public let prompt: String
    public let temperature: Double = 0.2
    public let topP: Double = 0.99
    public let topK: Int = 250
    public let maxTokensToSample: Int = 500
    public let stopSequences: [String] = ["\n\nHuman:"]
}

public struct InvokeClaudeResponse: Decodable {
    public let completion: String
    public let stop_reason: String
}

// MARK: - Errors

enum STSError: Error  {
    case invalidCredentialsResponse(String)
    case invalidAssumeRoleWithWebIdentityResponse(String)
}
enum BedrockError: Error {
    case invalidResponse(Data?)
}
