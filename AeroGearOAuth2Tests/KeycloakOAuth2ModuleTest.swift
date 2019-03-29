/*
* JBoss, Home of Professional Open Source.
* Copyright Red Hat, Inc., and individual contributors
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import UIKit
import XCTest
import AeroGearOAuth2
import AeroGearHttp
import OHHTTPStubs

let KEYCLOAK_TOKEN = "eyJhbGciOiJSUzI1NiJ9.eyJuYW1lIjoiU2FtcGxlIFVzZXIiLCJlbWFpbCI6InNhbXBsZS11c2VyQGV4YW1wbGUiLCJqdGkiOiI5MTEwNjAwZS1mYTdiLTRmOWItOWEwOC0xZGJlMGY1YTY5YzEiLCJleHAiOjE0MTc2ODg1OTgsIm5iZiI6MCwiaWF0IjoxNDE3Njg4Mjk4LCJpc3MiOiJzaG9vdC1yZWFsbSIsImF1ZCI6InNob290LXJlYWxtIiwic3ViIjoiNzJhN2Q0NGYtZDcxNy00MDk3LWExMWYtN2FhOWIyMmM5ZmU3IiwiYXpwIjoic2hhcmVkc2hvb3QtdGhpcmQtcGFydHkiLCJnaXZlbl9uYW1lIjoiU2FtcGxlIiwiZmFtaWx5X25hbWUiOiJVc2VyIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlciIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwic2Vzc2lvbl9zdGF0ZSI6Ijg4MTJlN2U2LWQ1ZGYtNDc4Yi1iNDcyLTNlYWU5YTI2ZDdhYSIsImFsbG93ZWQtb3JpZ2lucyI6W10sInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJ1c2VyIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnt9fQ.ZcNu8C4yeo1ALqnLvEOK3NxnaKm2BR818B4FfqN3WQd3sc6jvtGmTPB1C0MxF6ku_ELVs2l_HJMjNdPT9daUoau5LkdCjSiTwS5KA-18M5AUjzZnVo044-jHr_JsjNrYEfKmJXX0A_Zdly7el2tC1uPjGoeBqLgW9GowRl3i4wE"

class KeycloakOAuth2ModuleTests: XCTestCase {

    var givenRefreshExpiresIn:Int?
    var mockedSession:MockOAuth2SessionWithRefreshToken!
    var sut:KeycloakOAuth2Module!
    
    override func setUp() {
        super.setUp()
        givenRefreshExpiresIn = 1800
        OHHTTPStubs.removeAllStubs()
        setupStubKeycloakWithNSURLSessionDefaultConfiguration()
        
        let keycloakConfig = KeycloakConfig(
            clientId: "shoot-third-party",
            host: "http://localhost:8080",
            realm: "shoot-realm")
        
        mockedSession = MockOAuth2SessionWithRefreshToken()
        sut = KeycloakOAuth2Module(config: keycloakConfig, session: mockedSession)
    }

    
    override func tearDown() {
        super.tearDown()
        OHHTTPStubs.removeAllStubs()
        givenRefreshExpiresIn = nil
        sut = nil
        mockedSession = nil
    }
    
    func setupStubKeycloakWithNSURLSessionDefaultConfiguration() {
        // set up http stub
        _ = stub(condition: {_ in return true}, response: { (request: URLRequest!) -> OHHTTPStubsResponse in
            print(request.url!.path)
            switch request.url!.path {
            case "/auth/realms/shoot-realm/protocol/openid-connect/token":
                let string = "{\"access_token\":\"NEWLY_REFRESHED_ACCESS_TOKEN\", \"refresh_token\":\"\(KEYCLOAK_TOKEN)\",\"expires_in\":23, \"refresh_expires_in\": \(self.givenRefreshExpiresIn ?? 0)}"
                let data = string.data(using: String.Encoding.utf8)
                return OHHTTPStubsResponse(data:data!, statusCode: 200, headers: ["Content-Type" : "text/json"])
            case "/auth/realms/shoot-realm/protocol/openid-connect/logout":
                let string = "{\"access_token\":\"NEWLY_REFRESHED_ACCESS_TOKEN\", \"refresh_token\":\"nnn\",\"expires_in\":23}"
                let data = string.data(using: String.Encoding.utf8)
                return OHHTTPStubsResponse(data:data!, statusCode: 200, headers: ["Content-Type" : "text/json"])
            default: return OHHTTPStubsResponse(data:Data(), statusCode: 404, headers: ["Content-Type" : "text/json"])
            }
        })
    }
    
    
    func testRefreshAccessWithKeycloak() {
        //given
        let expectation = self.expectation(description: "KeycloakRefresh");
       
        //when
        sut.refreshAccessToken (completionHandler: { (response: AnyObject?, error:NSError?) -> Void in
            //then
            XCTAssertEqual(response as! String, "NEWLY_REFRESHED_ACCESS_TOKEN", "If access token not valid but refresh token present and still valid")
            XCTAssertEqual(self.mockedSession.savedRefreshedToken, KEYCLOAK_TOKEN, "Saved newly issued refresh token")
            XCTAssertEqual(self.mockedSession.savedRefreshTokenExpiration, "\(self.givenRefreshExpiresIn!)")
            expectation.fulfill()
        })
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testRefreshTokenExpirationSetAs0WithKeycloak() {
        //given
        givenRefreshExpiresIn = 0
        
        let expectation = self.expectation(description: "KeycloakRefresh");
        
        //when
        sut.refreshAccessToken (completionHandler: { (response: AnyObject?, error:NSError?) -> Void in
            //then
            XCTAssertEqual(response as! String, "NEWLY_REFRESHED_ACCESS_TOKEN", "If access token not valid but refresh token present and still valid")
            XCTAssertEqual(self.mockedSession.savedRefreshedToken, KEYCLOAK_TOKEN, "Saved newly issued refresh token")
            XCTAssertEqual(self.mockedSession.savedRefreshTokenExpiration, "\(60*60*24*365)")
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testRevokeAccess() {
        //given
        let expectation = self.expectation(description: "KeycloakRevoke");
       
        //when
        sut.revokeAccess(completionHandler: {(response: AnyObject?, error:NSError?) -> Void in
            //then
            XCTAssertTrue(self.mockedSession.initCalled == 1, "revoke token reset session")
            expectation.fulfill()
        })
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testExchangeAuthorizationCodeForAccessToken() {
       //given
        let givenCode = "C_0_D_3"
        let expectation = self.expectation(description: "exchangeAuthorizationCodeForAccessToken")
        
        sut.exchangeAuthorizationCodeForAccessToken(code: givenCode) { (response: AnyObject?, error:NSError?) in
            //then
            XCTAssertEqual(response as! String, "NEWLY_REFRESHED_ACCESS_TOKEN", "If access token not valid but refresh token present and still valid")
            XCTAssertEqual(self.mockedSession.savedRefreshedToken, KEYCLOAK_TOKEN, "Saved newly issued refresh token")
            XCTAssertEqual(self.mockedSession.savedRefreshTokenExpiration, "\(self.givenRefreshExpiresIn!)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testExchangeAuthorizationCodeForAccessTokenWithExpirationSetAs0() {
        //given
        givenRefreshExpiresIn = 0
        let givenCode = "C_0_D_3"
        let expectation = self.expectation(description: "exchangeAuthorizationCodeForAccessToken")
        
        sut.exchangeAuthorizationCodeForAccessToken(code: givenCode) { (response: AnyObject?, error:NSError?) in
            //then
            XCTAssertEqual(response as! String, "NEWLY_REFRESHED_ACCESS_TOKEN", "If access token not valid but refresh token present and still valid")
            XCTAssertEqual(self.mockedSession.savedRefreshedToken, KEYCLOAK_TOKEN, "Saved newly issued refresh token")
            XCTAssertEqual(self.mockedSession.savedRefreshTokenExpiration, "\(60*60*24*365)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }
}
