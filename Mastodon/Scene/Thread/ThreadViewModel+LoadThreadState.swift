//
//  ThreadViewModel+LoadThreadState.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-12.
//

import os.log
import Foundation
import Combine
import GameplayKit
import CoreDataStack
import MastodonSDK

extension ThreadViewModel {
    class LoadThreadState: GKState, NamingState {
        
        let logger = Logger(subsystem: "ThreadViewModel.LoadThreadState", category: "StateMachine")

        let id = UUID()

        var name: String {
            String(describing: Self.self)
        }
        
        weak var viewModel: ThreadViewModel?
                
        init(viewModel: ThreadViewModel) {
            self.viewModel = viewModel
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            let previousState = previousState as? ThreadViewModel.LoadThreadState
            logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): [\(self.id.uuidString)] enter \(self.name), previous: \(previousState?.name  ?? "<nil>")")
        }
        
        @MainActor
        func enter(state: LoadThreadState.Type) {
            stateMachine?.enter(state)
        }
        
        deinit {
            logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): [\(self.id.uuidString)] \(self.name)")
        }
    }
}

extension ThreadViewModel.LoadThreadState {
    class Initial: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Loading.Type:   return true
            default:                return false
            }
        }
    }
    
    class Loading: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Fail.Type:      return true
            case is NoMore.Type:    return true
            default:                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)

            guard let viewModel = viewModel, let stateMachine = stateMachine else { return }
            guard let authenticationBox = viewModel.context.authenticationService.activeMastodonAuthenticationBox.value else {
                stateMachine.enter(Fail.self)
                return
            }

            guard let threadContext = viewModel.threadContext else {
                stateMachine.enter(Fail.self)
                return
            }
            
            Task {
                do {
                    let response = try await viewModel.context.apiService.statusContext(
                        statusID: threadContext.statusID,
                        authenticationBox: authenticationBox
                    )
                    
                    await enter(state: NoMore.self)
                    
                    // assert(!Thread.isMainThread)
                    // await Task.sleep(1_000_000_000)     // 1s delay to prevent UI render issue
                    
                    viewModel.mastodonStatusThreadViewModel.appendAncestor(
                        domain: threadContext.domain,
                        nodes: MastodonStatusThreadViewModel.Node.replyToThread(
                            for: threadContext.replyToID,
                            from: response.value.ancestors
                        )
                    )
                    viewModel.mastodonStatusThreadViewModel.appendDescendant(
                        domain: threadContext.domain,
                        nodes: MastodonStatusThreadViewModel.Node.children(
                            of: threadContext.statusID,
                            from: response.value.descendants
                        )
                    )
                } catch {
                    logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): fetch status context for \(threadContext.statusID) fail: \(error.localizedDescription)")
                    await enter(state: Fail.self)
                }
                
            }
        }

    }
    
    class Fail: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            switch stateClass {
            case is Loading.Type:   return true
            default:                return false
            }
        }
        
        override func didEnter(from previousState: GKState?) {
            super.didEnter(from: previousState)
            
            guard let _ = viewModel, let stateMachine = stateMachine else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                stateMachine.enter(Loading.self)
            }
        }
    }
    
    class NoMore: ThreadViewModel.LoadThreadState {
        override func isValidNextState(_ stateClass: AnyClass) -> Bool {
            return false
        }
    }
    
}
