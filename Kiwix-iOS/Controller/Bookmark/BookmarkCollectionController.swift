//
//  BookmarkCollectionController.swift
//  Kiwix
//
//  Created by Chris Li on 1/12/17.
//  Copyright © 2017 Chris Li. All rights reserved.
//

import UIKit
import CoreData
import DZNEmptyDataSet

class BookmarkCollectionController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    private(set) var itemWidth: CGFloat = 0.0
    private(set) var shouldReloadCollectionView = false
    
    var book: Book? {
        didSet {
            title = book?.title ?? "All"
        }
    }
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        collectionView.indexPathsForSelectedItems?.forEach({ collectionView.deselectItem(at: $0, animated: false) })
        if editing {
            deleteButton.isEnabled = false
            navigationItem.setRightBarButtonItems([doneButton, deleteButton], animated: animated)
        } else {
            navigationItem.setRightBarButtonItems([editButton], animated: animated)
        }
    }
    
    func configureItemWidth(collectionViewWidth: CGFloat) {
        let itemsPerRow = ((collectionViewWidth - 10) / 320).rounded()
        self.itemWidth = floor((collectionViewWidth - (itemsPerRow + 1) * 10) / itemsPerRow)
    }
    
    // MARK: - UI Control
    
    let editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editButtonTapped(sender:)))
    let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped(sender:)))
    let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteButtonTapped(sender:)))
    
    @IBAction func dismiss(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    func configureButtons() {
        // For some reason, initializing buttons with target actions does not work
        editButton.target = self
        editButton.action = #selector(editButtonTapped(sender:))
        doneButton.target = self
        doneButton.action = #selector(doneButtonTapped(sender:))
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonTapped(sender:))
    }
    
    func editButtonTapped(sender: UIBarButtonItem) {
        setEditing(true, animated: true)
    }
    
    func doneButtonTapped(sender: UIBarButtonItem) {
        setEditing(false, animated: true)
    }
    
    func deleteButtonTapped(sender: UIBarButtonItem) {
        let context = AppDelegate.persistentContainer.viewContext
        context.perform {
            self.collectionView.indexPathsForSelectedItems?.forEach({ (indexPath) in
                let article = self.fetchedResultController.object(at: indexPath)
                context.delete(article)
            })
            try? context.save()
        }
    }
    
    // MARK: - override
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Bookmarks"
        navigationItem.rightBarButtonItems = [editButton]
        collectionView.alwaysBounceVertical = true
        collectionView.allowsMultipleSelection = true
        collectionView.emptyDataSetSource = self
        collectionView.emptyDataSetDelegate = self
        
        configureButtons()
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureItemWidth(collectionViewWidth: collectionView.frame.width)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        configureItemWidth(collectionViewWidth: collectionView.frame.width)
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        setEditing(false, animated: false)
    }
    
    // MARK: - UICollectionView Data Source
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultController.sections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! BookmarkCollectionCell
        let article = fetchedResultController.object(at: indexPath)
        cell.titleLabel.text = article.title
        cell.snippetLabel.text = article.snippet
        if let data = article.thumbImageData {
            cell.thumbImageView.image = UIImage(data: data)
        }
        cell.bookTitleLabel.text = article.book?.title
        if let date = article.bookmarkDate {cell.bookmarkDetailLabel.text = dateFormatter.string(from: date)}
        
        return cell
    }
    
    // MARK: - UICollectionView Delegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditing {
            deleteButton.isEnabled = (collectionView.indexPathsForSelectedItems?.count ?? 0) > 0
        } else {
            collectionView.deselectItem(at: indexPath, animated: true)
            let article = fetchedResultController.object(at: indexPath)
            guard let url = article.url else {return}
            GlobalQueue.shared.add(articleLoadOperation: ArticleLoadOperation(url: url))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isEditing {
            deleteButton.isEnabled = (collectionView.indexPathsForSelectedItems?.count ?? 0) > 0
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: itemWidth, height: itemWidth * 0.72)
    }
    
    // MARK: - NSFetchedResultsController
    
    private var closures = [() -> Void]()
    let managedObjectContext = AppDelegate.persistentContainer.viewContext
    lazy var fetchedResultController: NSFetchedResultsController<Article> = {
        let fetchRequest = Article.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "bookmarkDate", ascending: false)]
        var predicates = [NSPredicate]()
        predicates.append(NSPredicate(format: "isBookmarked = true"))
        if let book = self.book { predicates.append(NSPredicate(format: "book == %@", book)) }
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        try? controller.performFetch()
        return controller as! NSFetchedResultsController<Article>
    }()
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard collectionView.numberOfSections > 0,
                let newIndexPath = newIndexPath,
                collectionView.numberOfItems(inSection: newIndexPath.section) > 0 else {
                    shouldReloadCollectionView = true
                    break
            }
            closures.append({ [weak self] in self?.collectionView.insertItems(at: [newIndexPath]) })
        case .delete:
            guard let indexPath = indexPath else {break}
            closures.append({ [weak self] in self?.collectionView.deleteItems(at: [indexPath]) })
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else {break}
            closures.append({ [weak self] in self?.collectionView.moveItem(at: indexPath, to: newIndexPath) })
        case .update:
            guard let indexPath = indexPath, collectionView.numberOfItems(inSection: indexPath.section) != 1 else {
                self.shouldReloadCollectionView = true
                break
            }
            closures.append({ [weak self] in self?.collectionView.reloadItems(at: [indexPath]) })
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            closures.append({ [weak self] in self?.collectionView.insertSections(IndexSet(integer: sectionIndex)) })
        case .delete:
            closures.append({ [weak self] in self?.collectionView.deleteSections(IndexSet(integer: sectionIndex)) })
        case .move:
            break
        case .update:
            closures.append({ [weak self] in self?.collectionView.reloadSections(IndexSet(integer: sectionIndex)) })
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        OperationQueue.main.addOperation({
            if self.shouldReloadCollectionView {
                self.collectionView.reloadData()
            } else {
                self.collectionView.performBatchUpdates({ 
                    self.closures.forEach({ $0() })
                }, completion: { (completed) in
                    self.closures.removeAll()
                })
            }
        })
    }
}

extension BookmarkCollectionController: DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        return UIImage(named: "BookmarkColor")
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let string = NSLocalizedString("Bookmark Your Favorite Article", comment: "Bookmark Empty Title")
        let attributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 18), NSForegroundColorAttributeName: UIColor.darkGray]
        return NSAttributedString(string: string, attributes: attributes)
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        let string = NSLocalizedString("Long press the star button after an article is loaded to bookmark it.", comment: "Library, local tab")
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .center
        let attributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 14), NSForegroundColorAttributeName: UIColor.lightGray, NSParagraphStyleAttributeName: paragraph]
        return NSAttributedString(string: string, attributes: attributes)
    }
    
}

