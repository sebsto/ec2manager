//
//  BAckend.swift
//  EC2Manager
//
//  Created by Stormacq, Sebastien on 22/12/2023.
//

import Foundation

import Logging

import Amplify
import AWSPluginsCore
import AWSCognitoAuthPlugin

import AWSClientRuntime
import AwsCommonRuntimeKit // to access runtime errors
import AWSEC2
import AWSBedrockRuntime

//import AWSSotoSigner
//import BedrockMiniSDK

import ClientRuntime // to control verbosity of AWS SDK

enum BackendError: Error {
    
    case canNotCreateClient(Error)
    case serviceError(Error, String)
    case canNotFindCredentials
    case unauthorized(String)
    case invalidParameterValue(String)
    case unknwonError(String)
    case mock(String) // just for the Previews
    
}

struct Backend {
    
    private var logger = Logger(label: "Backend")
    
    private let region = "eu-west-1" // hardcoded on Ireland for now

    // class to ensure Amplify is initialized only once
    public init() throws {
#if DEBUG
        self.logger.logLevel = .trace
#endif
                
        configureAmplify()
    }
    
    func configureAmplify() {
        
        Amplify.Logging.logLevel = .info
        
        // control verbosity of AWS SDK
        SDKLoggingSystem.initialize(logLevel: .warning)
        
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
            logger.debug("Successfully configured Amplify")
        } catch {
            logger.error("Failed to initialize Amplify: \(error)")
        }
        
    }
    
    // generic function to call an AWS service, this allows to have all the error handling in one place
    private func callService<Output>(closure: () async throws -> Output) async throws -> Output {
        
        var result: Output
        
        do {
            
            result = try await closure()
            
        } catch CommonRunTimeError.crtError(let error) {
            
            // this shoud not happen, it is a programming error
            // I received this when I do not provide a CredentialsProvider for example
            logger.error("\(error.message)")
            throw BackendError.serviceError(error, error.message)
            
        } catch let error as AWSServiceError {
            
            logger.debug("\(error.errorCode ?? "can't extract error code")")
            logger.debug("\(error.message ?? "can't extract error message")")

            // this is how to manage SDK errors, see
            // https://github.com/awslabs/aws-sdk-swift/issues/1278
            switch error.errorCode {
            case "ValidationException":
                let msg =  error.message ?? "no message"
                logger.error("\(msg)")
                throw BackendError.invalidParameterValue(msg)
            case "UnauthorizedOperation":
                let msg = error.message?.split(separator: ". ").joined(separator: ".\n\n") ?? "no message"
                logger.error("\(msg)")
                throw BackendError.unauthorized(msg)
            case "AccessDeniedException":
                let msg =  error.message ?? "no message"
                logger.error("\(msg)")
                throw BackendError.unauthorized(msg)
            default:
                print("\(error.errorCode ?? "no error code")")
                logger.error("Unhandled error : \(error)")
                throw BackendError.unknwonError(error.message ?? "no message")
            }
            
        } catch {
            logger.error("Unmanaged error: \(error)")
            throw BackendError.unknwonError(error.localizedDescription)
        }
        
        return result
    }

    
    // there is no condition keys on ec2:DescribeInstances
    // https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
    // this function requires this IAM policy
    /*
     {
                 "Sid": "VisualEditor0",
                 "Effect": "Allow",
                 "Action": "ec2:DescribeInstances",
                 "Resource": "*"
             }
     */
    
    func listInstances(user: String) async throws -> [EC2Instance] {
        
        var result: [EC2Instance] = []
        return try await callService {
            let userFilter = EC2ClientTypes.Filter(name: "tag:User", values: [user])
            let request = AWSEC2.DescribeInstancesInput(filters:[userFilter])
            let response = try await ec2Client().describeInstances(input: request)
    
            result = response.reservations?.reduce(into: []) { tempResult, reservation in
                tempResult.append(contentsOf: reservation.instances?.map { EC2Instance.from(instance: $0) } ?? [] )
            } ?? []
            
            // fetch OSes
            result = try await osForInstance(user: user, instances: result)
            
            return result
        }
    }
    
    
    // there is no condition keys on ec2:DescribeImages
    // https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazonec2.html
    // this function requires this IAM policy
    /*
     {
                 "Sid": "VisualEditor0",
                 "Effect": "Allow",
                 "Action": "ec2:DescribeImages",
                 "Resource": "*"
             }
     */
    private func osForInstance(user: String, instances: [EC2Instance]) async throws -> [EC2Instance] {
        
        
        return try await callService {
            
            var result: [EC2Instance] = []

            let imageIds = instances.map { $0.ami }
            let request = AWSEC2.DescribeImagesInput(imageIds: imageIds)
            let response = try await ec2Client().describeImages(input: request)
                        
            guard response.images != nil else {
                return instances
            }
            
            instances.forEach {
                var instance = $0
                if let os = response.images!.os(for: instance) {
                    instance.os = os
                }
                result.append(instance)
            }
            
            return result
        }
    }
    
    func stopInstance(ec2: EC2Instance) async throws -> Void {
        
        return try await callService {
            let request = AWSEC2.StopInstancesInput(instanceIds: [ec2.id])
            let _ = try await ec2Client().stopInstances(input: request)
            
            //TODO: should I do something with the response ?
        }
    }
    
    func startInstance(ec2: EC2Instance) async throws -> Void {
        
        return try await callService {
            let request = AWSEC2.StartInstancesInput(instanceIds: [ec2.id])
            let _ = try await ec2Client().startInstances(input: request)
            
            //TODO: should I do something with the response ?
        }
    }
    
    func terminateInstance(ec2: EC2Instance) async throws -> Void {
        
        return try await callService {
            let request = AWSEC2.TerminateInstancesInput(instanceIds: [ec2.id])
            let _ = try await ec2Client().terminateInstances(input: request)
            
            //TODO: should I do something with the response ?
        }
    }
    
    func describeInstance(ec2: EC2Instance) async throws -> String {
        
        return try await callService {
            
            guard let type = EC2ClientTypes.InstanceType(rawValue: ec2.type) else {
                return "Unknown instance type: \(ec2.type)"
            }
            
            let request = DescribeInstanceTypesInput(instanceTypes: [type])
            let response = try await ec2Client().describeInstanceTypes(input: request)
            guard response.instanceTypes?.count == 1 else {
                return "Could not retrieve a valid instance type description"
            }
            
            let d = response.instanceTypes![0]
            let architecture = d.processorInfo?.supportedArchitectures?.map { a in
                switch a {
                case .x8664: "x64"
                case .arm64: "Graviton (Arm)"
                case .arm64Mac: "Apple silicon"
                case .x8664Mac: "x86 Mac"
                default: ""
                }
            }.joined(separator: " / ")
            
            let gpu = d.gpuInfo?.gpus?.count ?? 0 >= 1 ? "\n- \(d.gpuInfo?.gpus?.count ?? 0) GPU from \(d.gpuInfo?.gpus?[0].manufacturer ?? "") (\(d.gpuInfo?.gpus?[0].name ?? "")) with \(d.gpuInfo?.gpus?[0].memoryInfo?.sizeInMiB ?? 0) MiB memory" : ""
            
            // TODO: return raw data and let the ViewModel create the presentation view
            return """
A \(ec2.type) instance is has the following characteristics:

- a \(architecture ?? "") architecture.
- \(d.vCpuInfo?.defaultVCpus ?? 0) vCPUs (\(d.processorInfo?.sustainedClockSpeedInGhz ?? 0.0) Ghz).
- \(d.vCpuInfo?.defaultCores ?? 0) \((d.vCpuInfo?.defaultCores ?? 0) > 1 ? "cores" : "core").
- \(d.vCpuInfo?.defaultThreadsPerCore ?? 0) threads per core.\(gpu)
- \(d.memoryInfo?.sizeInMiB ?? 0) MiB memory.
- \(d.networkInfo?.networkPerformance ?? "") network bandwidth.
"""
        }
    }

//    func describeInstance(ec2: EC2Instance) async throws -> String {
//        
//        // https://instances.vantage.sh/
//        // https://www.convertcsv.com/csv-to-json.htm
//        
//        let prompt =
//"""
//You are an AWS expert writing a technical textual description for a mobile app. Describe in user friendly terms what is a \(ec2.type) EC2 instance type with key points listed first. Be brief and factual. Just report the top 4 characteristics that have impact on performance. Your response includes first a one line phrase that summarise the strengths, then the four bullet points you choose. Double check the response to ensure it is technically correct.
//"""
//        return try await callService {
//            let claudeResponse = try await self.invokeModel(withId: .claude_instant_v1, prompt: prompt)
//            return claudeResponse.completion
//        }
//    }
    
/**
    func describeInstanceWithKnowledgeBase(ec2: EC2Instance) async throws -> String {
//        let request = AWSBedrockAgentRuntime.  // not available in SDK 0.31. Available in SDK 0.34
        
        // get amplify session
        let session = try await Amplify.Auth.fetchAuthSession()
        
        //check if this is a CredentialsProvider and fetch temporary credentials
        guard let awsCredentialsProvider = session as? AuthAWSCredentialsProvider,
              let amplifyCredentials = try awsCredentialsProvider.getAWSCredentials().get() as? AWSTemporaryCredentials else {
            
            throw BackendError.canNotFindCredentials
        }

        let creds = StaticCredential(accessKeyId: amplifyCredentials.accessKeyId,
                                     secretAccessKey: amplifyCredentials.secretAccessKey,
                                     sessionToken: amplifyCredentials.sessionToken)
        let sdk : BedrockSDK = BedrockMiniSDK(withCredential: creds)

        do {
            let response = try await sdk.invokeKnowledgeBase(withId: "VO5GN6JHSU",
                                                             prompt: "You're a skilled AWS expert. Describe what is an \(ec2.type) EC2 instance type. Your response includes the amount of memory, the number of vCPU, and the networking performance",
                                                             modelArn: ClaudeModelArn.instant.rawValue)
            // print(response)
            // print("")
           return response.output.text
        } catch {
            print(error)
            throw BackendError.serviceError(error, "Fail to call knoweldge base")
        }
    }
 */
    
    private func ec2Client() async throws -> EC2Client  {
        let config = try await EC2Client.EC2ClientConfiguration(region: region, credentialsProvider: getCredentialsProvider())
        // TODO: should cache the client for performance ?
        return EC2Client(config: config)
    }
    
    //TODO: replace with the new AWS SDK STS Credentials provider ?
    
    // Authentication happens with Amplify. EC2 API are exposed through AWS SDK and AWS SDK doesn't consume Amplify's credendentials classes.
    // This method converts Amplify's credentials to a CrednetialProvider class that the AWS SDK can consume
    private func getCredentialsProvider() async throws -> AWSClientRuntime.CredentialsProviding {
        
        // get amplify session
        let session = try await Amplify.Auth.fetchAuthSession()
        
        //check if this is a CredentialsProvider and fetch temporary credentials
        if let awsCredentialsProvider = session as? AuthAWSCredentialsProvider,
           let amplifyCredentials = try awsCredentialsProvider.getAWSCredentials().get() as? AWSTemporaryCredentials {
            
            // create an AWS SDK static credentials provider with the temporary credentials
            return try StaticCredentialsProvider(Credentials(accessKey: amplifyCredentials.accessKeyId,
                                                                      secret: amplifyCredentials.secretAccessKey,
                                                                      expirationTimeout: amplifyCredentials.expiration,
                                                                      sessionToken: amplifyCredentials.sessionToken))
        }
        
        throw BackendError.canNotFindCredentials
    }
        
    private func invokeModel(withId modelId: BedrockClaudeModel, prompt: String) async throws -> InvokeClaudeResponse {
        
        let params = ClaudeModelParameters(prompt: prompt)
        let body: Data = try self.encode(params)
//        logger.debug("\(String(data: body, encoding: .utf8) ?? "")")
        let request = InvokeModelInput(body: body,
                                       contentType: "application/json",
                                       modelId: modelId.rawValue)
        let config = try await BedrockRuntimeClient
            .BedrockRuntimeClientConfiguration(credentialsProvider: getCredentialsProvider(),
                                               region: "us-east-1")
        let client = BedrockRuntimeClient(config: config)
        let response = try await client.invokeModel(input: request)
        
        guard response.contentType == "application/json",
              let data = response.body else {
            logger.error("Invalid Bedrock response: \(response)")
            throw BedrockError.invalidResponse(response.body)
        }
        return try self.decode(data)
    }
    
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    private func decode<T: Decodable>(json: String) throws -> T {
        let data = json.data(using: .utf8)!
        return try self.decode(data)
    }
    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }
    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data : Data =  try self.encode(value)
        return String(data: data, encoding: .utf8) ?? "error when encoding the string"
    }
}

extension Array<EC2ClientTypes.Image> {
    func os(for instance: EC2Instance) -> String? {
        
        var result: String? = nil
        
        let images = self.filter { $0.imageId == instance.ami }
        if images.count == 1 {
            if let desc = images[0].description?.split(separator: " AMI "),
               desc.count == 2 {
               result = String(desc[0])
            }
        }

        return result
    }
}

extension EC2Instance {
    static func from(instance: EC2ClientTypes.Instance) -> EC2Instance {
        
        var nameTag = "unknown"
        if let nameTags = instance.tags?.filter({ $0.key == "Name" }) {
            if nameTags.count >= 1 {
                if let value = nameTags[0].value {
                    nameTag = value
                }
            }
        }
        
        return EC2Instance(id: instance.instanceId ?? "unknown id",
                           name: nameTag,
                           platform: instance.platformDetails ?? "unknown platform",
                           os: instance.platformDetails ?? "unknown os",
                           ip: instance.publicIpAddress ?? "no public ip",
                           state: .from(instance),
                           ami: instance.imageId ?? "no ami id",
                           type: instance.instanceType?.rawValue ?? "no instance type")
    }
}


extension EC2Instance.EC2InstanceState {
    static func from(_ instance: EC2ClientTypes.Instance) -> EC2Instance.EC2InstanceState {
        return switch instance.state?.name {
        case .running: .running
        case .pending: .pending
        case .shuttingDown: .shuttingDown
        case .stopped: .stopped
        case .stopping: .stopping
        case .terminated: .terminated
        default: .unknown
        }
    }
}
