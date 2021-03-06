//
//  TestCommon.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/8/18.
//

import XCTest
@testable import DNWebSocket

class TestCommon: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testMasking() {
        let inputString = "String to test mask/unmask String to test mask/unmask String to test mask/unmask String to test mask/unmask"
        var data = inputString.data(using: .utf8)
        XCTAssertNotNil(data, "String data is empty")
        var mask = Data.randomMask()
        
        data!.mask(with: mask)
        data!.unmask(with: mask)
        
        let outputString = String(data: data!, encoding: .utf8) ?? ""
        
        XCTAssertEqual(inputString, outputString)
    }
    
    func testHandshakeCodingEncoding() {
        let url = URL(string: "wss://www.testwebsocket.com/chat/superchat")!
        var request = URLRequest(url: url)
        let secKey = String.generateSecKey()
        request.prepare(secKey: secKey, url: url, useCompression: true, protocols: ["chat", "superchat"])
        
        let decodedHandshake = request.webSocketHandshake()
        let data = decodedHandshake.data(using: .utf8)!
        let encodedHandshake = Handshake(data: data)
        XCTAssertNotNil(encodedHandshake)
        XCTAssertEqual(decodedHandshake, encodedHandshake!.rawBodyString)
    }
    
    func testFrameIOAllOccasions() {
        let useCompression = [true, false]
        let maskData = [true, false]
        let opCode: [WebSocket.Opcode] = [.binaryFrame, .textFrame, .continuationFrame,
                                          .connectionCloseFrame, .pingFrame, .pongFrame]
        let addPayload = [true, false]
        
        opCode.forEach { (oc) in
            addPayload.forEach { (ap) in
                useCompression.forEach { (uc) in
                    maskData.forEach { (md) in
                        testFrameIO(addPayload: ap, useCompression: uc, maskData: md, opCode: oc)
                    }
                }
            }
        }
    }
    
    func testFrameIO(addPayload: Bool, useCompression: Bool, maskData: Bool, opCode: WebSocket.Opcode) {
        print("payload: \(addPayload), compression: \(useCompression), mask: \(maskData), op: \(opCode)")
        let possiblePayload = """
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD
                                 PAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOADPAYLOAD"
                                 """
        
        let payloadString = addPayload ? possiblePayload : ""
        let payload = addPayload ? payloadString.data(using: .utf8)! : Data()
        let inputFrame = prepareFrame(payload: payload, opCode: opCode, useC: useCompression, mask: maskData)
        let inputFrameData = Frame.encode(inputFrame)
        
        let result = Frame.decode(from: inputFrameData.unsafeBuffer(), fromOffset: 0)
        XCTAssertNotNil(result)
        let outputFrame = result!.0
        
        if outputFrame.isMasked && outputFrame.fin {
            outputFrame.payload.unmask(with: outputFrame.mask)
        }
        
        let outputString =  String(data: outputFrame.payload, encoding: .utf8)
        XCTAssertNotNil(outputString)
        XCTAssertEqual(payloadString, outputString)
    }
    
    fileprivate func prepareFrame(payload: Data, opCode: WebSocket.Opcode, useC: Bool, mask: Bool) -> Frame {
        var payload = payload
        
        let frame = Frame(fin: true, opCode: opCode)
        frame.rsv1 = useC
        frame.isMasked = mask
        frame.mask = Data.randomMask()
        
        frame.payload = payload
        
        if frame.isMasked {
            frame.payload.mask(with: frame.mask)
        }
        
        frame.payloadLength = UInt64(frame.payload.count)
        
        return frame
    }
}
