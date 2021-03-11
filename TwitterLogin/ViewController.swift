//
// ViewController.swift
//
// Created by Ben for TwitterLogin on 2021/3/11.
// Copyright © 2021 Alien. All rights reserved.
//

import UIKit
import Alamofire
import OAuthSwift
import AuthenticationServices

enum TwitterInfo {
    static let consumerKey = ""
    static let consumerKeySecret = ""
}
class ViewController: UIViewController {
    
    @IBOutlet weak var tokenLabel: UILabel!
    @IBOutlet weak var uidLabel: UILabel!
    @IBOutlet weak var secretLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
    }
    
    @IBAction func pressLogin(_ sender: Any) {
        login()
    }
    
    private func login() {
        assert(TwitterInfo.consumerKey.count > 0, "Consumer Key 尚未設定。")
        assert(TwitterInfo.consumerKeySecret.count > 0, "Consumer Key Secret 尚未設定。")
        let url = URL(string: "https://api.twitter.com/oauth/request_token")!
        let credential = OAuthSwiftCredential(consumerKey: TwitterInfo.consumerKey, consumerSecret: TwitterInfo.consumerKeySecret)
        let header =  credential.makeHeaders(url, method: .POST, parameters: ["oauth_callback":"\(callbackScheme())://"])
        let headers = HTTPHeaders(header)
        AF.request(url, method: .post, headers: headers).responseString { [weak self] (response) in
            print(response.value ?? "")
            guard let v = response.value else { return }
            let response = v.parametersFromQueryString
            guard let oauthToken = response["oauth_token"],
                  let oauthTokenSecret = response["oauth_token_secret"] else { return }
            
            self?.loginWebAuth(token: oauthToken, secret: oauthTokenSecret)
        }
        
        
    }
    private func loginWebAuth(token: String, secret: String) {
        let url = URL(string: "https://api.twitter.com/oauth/authorize?oauth_token=\(token)")!
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: nil) { [weak self] (url, error) in
            print(url?.query ?? "")
            
            guard let qeuryString = url?.query?.parametersFromQueryString else { return }
            
            guard let oauthToken = qeuryString["oauth_token"],
                  let oauthTokenSecret = qeuryString["oauth_verifier"] else { return }
            self?.loginAccessToken(token: oauthToken, verify: oauthTokenSecret)
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }
    
    func loginAccessToken(token: String, verify: String) {
        let url = URL(string: "https://api.twitter.com/oauth/access_token?oauth_token=\(token)&oauth_verifier=\(verify)")!
        AF.request(url, method: .post).responseString { [weak self] (response) in
            print(response.value ?? "")
            guard let values = response.value?.parametersFromQueryString,
                  let token = values["oauth_token"],
                  let secret = values["oauth_token_secret"],
                  let userID = values["user_id"]
                  else { return }
            self?.uidLabel.text = userID
            self?.tokenLabel.text = token
            self?.secretLabel.text = secret
            self?.userInfo(token: token, tokenSecret: secret)
        }
        
    }
    
    private func userInfo(token: String, tokenSecret: String) {
        let url = URL(string: "https://api.twitter.com/1.1/account/verify_credentials.json")!
        let credential = OAuthSwiftCredential(consumerKey: TwitterInfo.consumerKey, consumerSecret: TwitterInfo.consumerKeySecret)
        credential.oauthToken = token
        credential.oauthTokenSecret = tokenSecret
        let param = ["include_email":"true"]
        let header =  credential.makeHeaders(url, method: .GET, parameters: param)
        let headers = HTTPHeaders(header)
        AF.request(url, method: .get, parameters: param, headers: headers).responseJSON { [weak self] (response) in
            if let data = response.value as? [String:Any],
                let email = data["email"] as? String {
                self?.emailLabel.text = email
            }
        }
        
    }
    
    private func callbackScheme() -> String {
        if let dict = Bundle.main.infoDictionary,
           let urlTypes = (dict["CFBundleURLTypes"] as? [Dictionary<String,Any>])?.first,
           let scheme = (urlTypes["CFBundleURLSchemes"] as? [String])?.first
        {
            return scheme
        }
        assertionFailure("尚未設定 Callback URL Scheme，請至 Target > Info 設定。")
        return ""
    }
}


extension ViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let window = UIApplication.shared.windows.filter { $0.isKeyWindow }.first!
        return window
    }
}
