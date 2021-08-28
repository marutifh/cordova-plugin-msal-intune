// import UIKit
import MSAL

@objc(MSALIntune) class MSALIntune : CDVPlugin {
    // MARK: Properties
    
    // public init(_ application: UIApplication) {
    //     // Store application and app delegate for later
    //     self.application = application
    //     self.appDelegate = application.delegate!
        
    //     // Initialize Pushy instance before accessing the self object
    //     super.init()
    // }

    /*
    self.commandDelegate!.run(inBackground: {

    })

    */

    var accessToken:String?
    var applicationContext : MSALPublicClientApplication?
    var webViewParamaters : MSALWebviewParameters?
    var currentAccount: MSALAccount?
    var pluginResult = CDVPluginResult(status: .error)
    var kClientID = String()
    var bundleID:String?
    var kAuthority = String()
    let kGraphEndpoint = "https://graph.microsoft.com/"
    let kScopes: [String] = ["user.read"]
    var kRedirectUri:String?

    override func pluginInitialize() {
        let akClientID = self.commandDelegate.settings["msalClientId".lowercased()] as? String
        self.kClientID = akClientID ?? "abc";
        let kTenantID = self.commandDelegate.settings["msalTenantId".lowercased()] as? String
        kAuthority = "https://login.microsoftonline.com/" + kTenantID!
        bundleID = Bundle.main.bundleIdentifier!
        kRedirectUri = "msauth." + bundleID! + "://auth"
        print("kAuthority")
        print(self.kAuthority);
        print("bundleID")
        print(bundleID! as String)
        print("kRedirectUri")
        print(kRedirectUri! as String);
    }

    @objc(add:) 
    func add(_ command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(status: .error)
        let param1 = (command.arguments[0] as? NSObject)?.value(forKey: "param1") as? Int
        let param2 = (command.arguments[0] as? NSObject)?.value(forKey: "param2") as? Int
        if let p1 = param1 , let p2 = param2 {
            if p1 >= 0 && p1 >= 0{
                let total = String(p1 + p2)
                pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: total)
            }
            else {
                pluginResult = CDVPluginResult(status: .error, messageAs: "Something wrong")
            }
        }
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }
    
    @objc(initMSALIntune:) 
    func initMSALIntune(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {
            do {
                guard let authorityURL = URL(string: self.kAuthority) else {
                    self.pluginResult = CDVPluginResult(status: .error, messageAs: "Unable to create authority URL!")
                    self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                    return
                }
                
                let authority = try MSALAADAuthority(url: authorityURL)
                
                let msalConfiguration = MSALPublicClientApplicationConfig(clientId: self.kClientID,
                                                                          redirectUri: self.kRedirectUri,
                                                                        authority: authority)
                self.applicationContext = try MSALPublicClientApplication(configuration: msalConfiguration)
                self.initWebViewParams()
                self.pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Initialised, Okay!")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
            } catch let error {
                self.pluginResult = CDVPluginResult(status: .error, messageAs: "Something wrong: \(error)")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
            }
        })
    }

    func initWebViewParams() {
        self.webViewParamaters = MSALWebviewParameters(authPresentationViewController: self.viewController)
    }
    
    func acquireToken(_ command: CDVInvokedUrlCommand){
            guard let applicationContext = self.applicationContext else {
                self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not find applicationContext")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                return
            }
            guard let webViewParameters = self.webViewParamaters else {
                self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not find webViewParameters")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                return
            }
            print("SCOPES::")
            let parameters = MSALInteractiveTokenParameters(scopes: ["user.read"], webviewParameters: webViewParameters)
            parameters.promptType = .selectAccount
            
            applicationContext.acquireToken(with: parameters) { (result, error) in
                
                if let error = error {
                    self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not acquire token:\(error)")
                    self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                    return
                }
                
                guard let result = result else {
                    self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not acquire token: No result returned")
                    self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                    return
                }
                
                self.accessToken = result.accessToken
                self.pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: self.accessToken)
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
            }
        
    }

    @objc(signInInteractive:) 
    func signInInteractive(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {
            self.acquireToken(command);
        })
    }
    
    @objc(signIn:) 
    func signIn(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {
            self.acquireToken(command);
        })
    }
    
    func acquireTokenSilently(_ account : MSALAccount!, _ command: CDVInvokedUrlCommand) {
        
        guard let applicationContext = self.applicationContext else {
            self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not find applicationContext")
            self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
            return
        }
        
        let parameters = MSALSilentTokenParameters(scopes: ["user.read"], account: account)
        
        applicationContext.acquireTokenSilent(with: parameters) { (result, error) in
            
            if let error = error {
                
                let nsError = error as NSError
                
                // interactionRequired means we need to ask the user to sign-in. This usually happens
                // when the user's Refresh Token is expired or if the user has changed their password
                // among other possible reasons.
                
                if (nsError.domain == MSALErrorDomain) {
                    
                    if (nsError.code == MSALError.interactionRequired.rawValue) {
                        
                        DispatchQueue.main.async {
                            self.acquireToken(command);
                        }
                        return
                    }
                }
                self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not acquire token silently: \(error)")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                return
            }
            
            guard let result = result else {
                self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not acquire token: No result returned")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                return
            }
            
            self.accessToken = result.accessToken
            self.pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: self.accessToken)
            self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
            // self.updateLogging(text: "Refreshed Access token is \(self.accessToken)")
        }
    }
    

    typealias AccountCompletion = (MSALAccount?) -> Void
    
    func loadCurrentAccount(_ command: CDVInvokedUrlCommand) {
        
        guard let applicationContext = self.applicationContext else {
            self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not find applicationContext")
            self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
            return
        }
        
        let msalParameters = MSALParameters()
        msalParameters.completionBlockQueue = DispatchQueue.main
        
        do{
            if try applicationContext.allAccounts().count > 0
            {
                self.acquireTokenSilently(try applicationContext.allAccounts().first, command)
            }else{
                DispatchQueue.main.async {
                    self.acquireToken(command);
                }
            }
        }catch  {
            self.pluginResult = CDVPluginResult(status: .error, messageAs: "No current accounts")
            self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
        }
    }
    
    @objc(silentSignIn:) 
    func silentSignIn(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {
            self.loadCurrentAccount(command)
        })
    }

    @objc(signOut:) 
    func signOut(_ command: CDVInvokedUrlCommand) {
        self.commandDelegate!.run(inBackground: {
            guard let applicationContext = self.applicationContext else {
                self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not find applicationContext")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                return
            }
            
            guard let account = self.currentAccount else {
                self.pluginResult = CDVPluginResult(status: .error, messageAs: "Could not load current account")
                self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                return
            }
            
            do {
                
                /**
                Removes all tokens from the cache for this application for the provided account
                
                - account:    The account to remove from the cache
                */
                
                let signoutParameters = MSALSignoutParameters(webviewParameters: self.webViewParamaters!)
                signoutParameters.signoutFromBrowser = false
                
                applicationContext.signout(with: account, signoutParameters: signoutParameters, completionBlock: {(success, error) in
                    
                    if let error = error {
                        // self.updateLogging(text: "Couldn't sign out account with error: \(error)")
                        self.pluginResult = CDVPluginResult(status: .error, messageAs: "Couldn't sign out account with error: \(error)")
                        self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                        return
                    }
                    
                    // self.updateLogging(text: "Sign out completed successfully")
                    self.pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Sign out completed successfully")
                    self.commandDelegate!.send(self.pluginResult, callbackId: command.callbackId)
                    self.accessToken = ""
                    // self.updateCurrentAccount(account: nil)
                })
                
            }
        })
    }
}
