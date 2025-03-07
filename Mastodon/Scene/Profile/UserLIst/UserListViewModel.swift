//
//  UserListViewModel.swift
//  Mastodon
//
//  Created by MainasuK on 2022-5-17.
//

import os.log
import UIKit
import Combine
import CoreDataStack
import GameplayKit

final class UserListViewModel {
    
    let logger = Logger(subsystem: "UserListViewModel", category: "ViewModel")
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let kind: Kind
    let userFetchedResultsController: UserFetchedResultsController
    let listBatchFetchViewModel = ListBatchFetchViewModel()

    // output
    var diffableDataSource: UITableViewDiffableDataSource<UserSection, UserItem>!
    @MainActor private(set) lazy var stateMachine: GKStateMachine = {
        let stateMachine = GKStateMachine(states: [
            State.Initial(viewModel: self),
            State.Fail(viewModel: self),
            State.Idle(viewModel: self),
            State.Loading(viewModel: self),
            State.NoMore(viewModel: self),
        ])
        stateMachine.enter(State.Initial.self)
        return stateMachine
    }()
    
    init(
        context: AppContext,
        kind: Kind
    ) {
        self.context = context
        self.kind = kind
        self.userFetchedResultsController = UserFetchedResultsController(
            managedObjectContext: context.managedObjectContext,
            domain: nil,
            additionalPredicate: nil
        )
        // end init

        context.authenticationService.activeMastodonAuthenticationBox
            .map { $0?.domain }
            .assign(to: \.domain, on: userFetchedResultsController)
            .store(in: &disposeBag)
    }
    
}

extension UserListViewModel {
    // TODO: refactor follower and following into user list
    enum Kind {
        case rebloggedBy(status: ManagedObjectRecord<Status>)
        case favoritedBy(status: ManagedObjectRecord<Status>)
    }
}
