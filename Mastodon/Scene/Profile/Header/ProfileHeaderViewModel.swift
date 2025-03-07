//
//  ProfileHeaderViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-4-9.
//

import os.log
import UIKit
import Combine
import CoreDataStack
import Kanna
import MastodonSDK
import MastodonMeta
import MastodonUI

final class ProfileHeaderViewModel {
    
    static let avatarImageMaxSizeInPixel = CGSize(width: 400, height: 400)
    static let maxProfileFieldCount = 4
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    @Published var user: MastodonUser?
    @Published var relationshipActionOptionSet: RelationshipActionOptionSet = .none

    @Published var isEditing = false
    @Published var isUpdating = false
    
    @Published var accountForEdit: Mastodon.Entity.Account?

//    let needsFiledCollectionViewHidden = CurrentValueSubject<Bool, Never>(false)
    
    // output
    let profileInfo        = ProfileInfo()
    let profileInfoEditing = ProfileInfo()

    @Published var isTitleViewDisplaying = false
    @Published var isTitleViewContentOffsetSet = false    

    init(context: AppContext) {
        self.context = context
    
        $accountForEdit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] account in
                guard let self = self else { return }
                guard let account = account else { return }
                // avatar
                self.profileInfo.avatar = nil
                self.profileInfoEditing.avatar = nil
                // name
                let name = account.displayNameWithFallback
                self.profileInfo.name = name
                self.profileInfoEditing.name = name
                // bio
                let note = ProfileHeaderViewModel.normalize(note: account.note)
                self.profileInfo.note = note
                self.profileInfoEditing.note = note
            }
            .store(in: &disposeBag)
    }
    
}

extension ProfileHeaderViewModel {
    class ProfileInfo {
        // input
        @Published var avatar: UIImage?
        @Published var name: String?
        @Published var note: String?
    }
}

extension ProfileHeaderViewModel {
    
    static func normalize(note: String?) -> String? {
        let _note = note?.replacingOccurrences(of: "<br>|<br />", with: "\u{2028}", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "</p>", with: "</p>\u{2029}", range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let note = _note, !note.isEmpty else {
            return nil
        }
        
        let html = try? HTML(html: note, encoding: .utf8)
        return html?.text
    }

}

// MARK: - ProfileViewModelEditable
extension ProfileHeaderViewModel: ProfileViewModelEditable {
    var isEdited: Bool {
        guard isEditing else { return false }
        
        guard profileInfoEditing.avatar == nil else { return true }
        guard profileInfo.name == profileInfoEditing.name else { return true }
        guard profileInfo.note == profileInfoEditing.note else { return true }

        return false
    }
}
