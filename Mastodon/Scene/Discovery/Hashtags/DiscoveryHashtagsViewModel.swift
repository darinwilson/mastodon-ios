//
//  DiscoveryHashtagsViewModel.swift
//  Mastodon
//
//  Created by MainasuK on 2022-4-13.
//

import os.log
import UIKit
import Combine
import GameplayKit
import CoreData
import CoreDataStack
import MastodonSDK

final class DiscoveryHashtagsViewModel {
    
    let logger = Logger(subsystem: "DiscoveryHashtagsViewModel", category: "ViewModel")
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let viewDidAppeared = PassthroughSubject<Void, Never>()

    // output
    var diffableDataSource: UITableViewDiffableDataSource<DiscoverySection, DiscoveryItem>?
    @Published var hashtags: [Mastodon.Entity.Tag] = []
    
    init(context: AppContext) {
        self.context = context
        // end init
        
        Publishers.CombineLatest(
            context.authenticationService.activeMastodonAuthenticationBox,
            viewDidAppeared
        )
        .compactMap { authenticationBox, _ -> MastodonAuthenticationBox? in
            return authenticationBox
        }
        .throttle(for: 3, scheduler: DispatchQueue.main, latest: true)
        .asyncMap { authenticationBox in
            try await context.apiService.trendHashtags(domain: authenticationBox.domain, query: nil)
        }
        .retry(3)
        .map { response in Result<Mastodon.Response.Content<[Mastodon.Entity.Tag]>, Error> { response } }
        .catch { error in Just(Result<Mastodon.Response.Content<[Mastodon.Entity.Tag]>, Error> { throw error }) }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                self.hashtags = response.value.filter { !$0.name.isEmpty }
            case .failure:
                break
            }
        }
        .store(in: &disposeBag)
    }
    
    deinit {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }
    
}

extension DiscoveryHashtagsViewModel {
    
    @MainActor
    func fetch() async throws {
        guard let authenticationBox = context.authenticationService.activeMastodonAuthenticationBox.value else { return }
        let response = try await context.apiService.trendHashtags(domain: authenticationBox.domain, query: nil)
        hashtags = response.value.filter { !$0.name.isEmpty }
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): fetch tags: \(response.value.count)")
    }
    
}
