//
//  FavoriteViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-6.
//

import UIKit
import Combine
import CoreData
import CoreDataStack
import GameplayKit

final class FavoriteViewModel {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let activeMastodonAuthenticationBox: CurrentValueSubject<MastodonAuthenticationBox?, Never>
    let statusFetchedResultsController: StatusFetchedResultsController
    let listBatchFetchViewModel = ListBatchFetchViewModel()

    // output
    var diffableDataSource: UITableViewDiffableDataSource<StatusSection, StatusItem>?
    private(set) lazy var stateMachine: GKStateMachine = {
        let stateMachine = GKStateMachine(states: [
            State.Initial(viewModel: self),
            State.Reloading(viewModel: self),
            State.Fail(viewModel: self),
            State.Idle(viewModel: self),
            State.Loading(viewModel: self),
            State.NoMore(viewModel: self),
        ])
        stateMachine.enter(State.Initial.self)
        return stateMachine
    }()
    
    init(context: AppContext) {
        self.context = context
        self.activeMastodonAuthenticationBox = CurrentValueSubject(context.authenticationService.activeMastodonAuthenticationBox.value)
        self.statusFetchedResultsController = StatusFetchedResultsController(
            managedObjectContext: context.managedObjectContext,
            domain: nil,
            additionalTweetPredicate: nil
        )
        
        context.authenticationService.activeMastodonAuthenticationBox
            .assign(to: \.value, on: activeMastodonAuthenticationBox)
            .store(in: &disposeBag)
        
        activeMastodonAuthenticationBox
            .map { $0?.domain }
            .assign(to: \.value, on: statusFetchedResultsController.domain)
            .store(in: &disposeBag)
    }
    
}
