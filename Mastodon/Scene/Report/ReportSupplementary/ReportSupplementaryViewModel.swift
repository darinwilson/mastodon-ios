//
//  ReportSupplementaryViewModel.swift
//  Mastodon
//
//  Created by MainasuK on 2022-2-7.
//

import UIKit
import Combine
import CoreDataStack
import MastodonSDK

class ReportSupplementaryViewModel {
    
    weak var delegate: ReportSupplementaryViewControllerDelegate?

    // Input
    var context: AppContext
    let user: ManagedObjectRecord<MastodonUser>
    let commentContext = ReportItem.CommentContext()
    
    @Published var isSkip = false
    @Published var isBusy = false
    
    // output
    var diffableDataSource: UITableViewDiffableDataSource<ReportSection, ReportItem>?
    @Published var isNextButtonEnabled = false
    
    init(
        context: AppContext,
        user: ManagedObjectRecord<MastodonUser>
    ) {
        self.context = context
        self.user = user
        // end init
        
        Publishers.CombineLatest(
            commentContext.$comment,
            $isBusy
        )
        .map { comment, isBusy -> Bool in
            guard !isBusy else { return false }
            return !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .assign(to: &$isNextButtonEnabled)
    }
    
}
