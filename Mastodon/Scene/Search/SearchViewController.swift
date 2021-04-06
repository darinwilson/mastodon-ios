//
//  SearchViewController.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/3/31.
//

import Combine
import GameplayKit
import MastodonSDK
import UIKit

final class SearchViewController: UIViewController, NeedsDependency {
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    var disposeBag = Set<AnyCancellable>()
    private(set) lazy var viewModel = SearchViewModel(context: context)
    
    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = L10n.Scene.Search.Searchbar.placeholder
        searchBar.tintColor = Asset.Colors.buttonDefault.color
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        let micImage = UIImage(systemName: "mic.fill")
        searchBar.setImage(micImage, for: .bookmark, state: .normal)
        searchBar.showsBookmarkButton = true
        searchBar.showsScopeBar = false
        searchBar.scopeButtonTitles = [L10n.Scene.Search.Searching.Segment.all, L10n.Scene.Search.Searching.Segment.people, L10n.Scene.Search.Searching.Segment.hashtags]
        return searchBar
    }()
    
    // recommend
    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.clipsToBounds = false
        return scrollView
    }()
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 68, right: 0)
        stackView.isLayoutMarginsRelativeArrangement = true
        return stackView
    }()
    
    let hashTagCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        let view = ControlContainableCollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let accountsCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        let view = ControlContainableCollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.layer.masksToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // searching
    let searchingTableView: UITableView = {
        let tableView = UITableView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = .white
        return tableView
    }()
}

extension SearchViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Asset.Colors.Background.search.color
        searchBar.delegate = self
        navigationItem.titleView = searchBar
        navigationItem.hidesBackButton = true
        setupScrollView()
        setupHashTagCollectionView()
        setupAccountsCollectionView()
        setupSearchingTableView()
        setupDataSource()
    }

    func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.constrain([
            scrollView.frameLayoutGuide.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.frameLayoutGuide.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.frameLayoutGuide.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.frameLayoutGuide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        
        scrollView.addSubview(stackView)
        stackView.constrain([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.contentLayoutGuide.widthAnchor),
            scrollView.contentLayoutGuide.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
        ])
    }
    
    func setupDataSource() {
        viewModel.hashTagDiffableDataSource = RecommendHashTagSection.collectionViewDiffableDataSource(for: hashTagCollectionView)
        viewModel.accountDiffableDataSource = RecommendAccountSection.collectionViewDiffableDataSource(for: accountsCollectionView)
        viewModel.searchResultDiffableDataSource = SearchResultSection.tableViewDiffableDataSource(for: searchingTableView)
    }
}

extension SearchViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == searchingTableView {
            handleScrollViewDidScroll(scrollView)
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
        searchBar.showsScopeBar = true
        viewModel.isSearching.value = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.showsScopeBar = false
        viewModel.isSearching.value = true
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.showsScopeBar = false
        searchBar.text = ""
        searchBar.resignFirstResponder()
        viewModel.isSearching.value = false
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.searchText.send(searchText)
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        switch selectedScope {
        case 0:
            viewModel.searchScope.value = ""
        case 1:
            viewModel.searchScope.value = Mastodon.API.Search.Scope.accounts.rawValue
        case 2:
            viewModel.searchScope.value = Mastodon.API.Search.Scope.hashTags.rawValue
        default:
            break
        }
    }

    func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {}
}

extension SearchViewController: LoadMoreConfigurableTableViewContainer {
    typealias BottomLoaderTableViewCell = SearchBottomLoader
    typealias LoadingState = SearchViewModel.LoadOldestState.Loading
    var loadMoreConfigurableTableView: UITableView { searchingTableView }
    var loadMoreConfigurableStateMachine: GKStateMachine { viewModel.loadoldestStateMachine }
}

#if canImport(SwiftUI) && DEBUG
import SwiftUI

struct SearchViewController_Previews: PreviewProvider {
    static var previews: some View {
        UIViewControllerPreview {
            let viewController = SearchViewController()
            return viewController
        }
        .previewLayout(.fixed(width: 375, height: 800))
    }
}

#endif
