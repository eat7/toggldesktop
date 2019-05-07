//
//  EditorViewController.swift
//  TogglDesktop
//
//  Created by Nghia Tran on 3/21/19.
//  Copyright © 2019 Alari. All rights reserved.
//

import Cocoa

final class EditorViewController: NSViewController {

    private struct Constans {

        static let TokenViewSpacing: CGFloat = 5.0
        static let MaximumTokenWidth: CGFloat = 260.0
        static let TimerNotification = NSNotification.Name("TimerForRunningTimeEntryOnTicket")
    }

    // MARK: OUTLET

    @IBOutlet weak var projectBox: NSBox!
    @IBOutlet weak var projectTextField: ProjectAutoCompleteTextField!
    @IBOutlet weak var descriptionTextField: DescriptionAutoCompleteTextField!
    @IBOutlet weak var tagTextField: TagAutoCompleteTextField!
    @IBOutlet weak var billableCheckBox: NSButton!
    @IBOutlet weak var projectDotImageView: DotImageView!
    @IBOutlet weak var closeBtn: CursorButton!
    @IBOutlet weak var deleteBtn: NSButton!
    @IBOutlet weak var tagAutoCompleteContainerView: NSBox!
    @IBOutlet weak var tagStackView: NSStackView!
    @IBOutlet weak var tagAddButton: NSButton!
    @IBOutlet weak var tagInputContainerView: NSBox!
    @IBOutlet weak var datePickerView: NSDatePicker!
    @IBOutlet weak var dayNameButton: CursorButton!
    @IBOutlet weak var nextDateBtn: NSButton!
    @IBOutlet weak var previousDateBtn: NSButton!
    @IBOutlet weak var durationTextField: NSTextField!
    @IBOutlet weak var startAtBtn: CursorButton!
    @IBOutlet weak var endAtBtn: CursorButton!
    @IBOutlet weak var dateSelectionBox: NSBox!
    @IBOutlet weak var workspaceLbl: NSTextField!

    @IBOutlet weak var timeContainerView: NSView!
    @IBOutlet weak var arrowBtn: NSButton!
    
    // MARK: Variables

    var timeEntry: TimeEntryViewItem! {
        didSet {
            fillData()
        }
    }
    private var selectedProjectItem: ProjectContentItem?
    private lazy var projectDatasource = ProjectDataSource(items: ProjectStorage.shared.items,
                                                           updateNotificationName: .ProjectStorageChangedNotification)
    private lazy var descriptionDatasource = DescriptionDataSource(items: DescriptionTimeEntryStorage.shared.items,
                                                                   updateNotificationName: .DescrptionTimeEntryStorageChangedNotification)
    private lazy var tagDatasource = TagDataSource(items: TagStorage.shared.tags,
                                                   updateNotificationName: .TagStorageChangedNotification)

    private lazy var borderColor: NSColor = {
        if #available(OSX 10.13, *) {
            return NSColor(named: NSColor.Name("upload-border-color"))!
        } else {
            return ConvertHexColor.hexCode(toNSColor: "#ACACAC")
        }
    }()
    private lazy var calendarViewControler: CalendarViewController = {
        let controller = CalendarViewController(nibName: NSNib.Name("CalendarViewController"), bundle: nil)
        controller.delegate = self
        return controller
    }()
    private lazy var calendarPopover: NoVibrantPopoverView = {
        let popover = NoVibrantPopoverView()
        popover.behavior = .semitransient
        popover.contentViewController = calendarViewControler
        return popover
    }()
    private lazy var timeInputViewController: TimeInputViewController = {
        let controller = TimeInputViewController(nibName: NSNib.Name("TimeInputViewController"), bundle: nil)
        return controller
    }()
    private lazy var timePopover: NoVibrantPopoverView = {
        let popover = NoVibrantPopoverView()
        popover.behavior = .semitransient
        popover.contentViewController = timeInputViewController
        return popover
    }()
    private lazy var dayNameAttribute: [NSAttributedString.Key : Any] = {
        return [NSAttributedString.Key.font : NSFont.systemFont(ofSize: 14),
                NSAttributedString.Key.foregroundColor: NSColor.labelColor]
    }()
    fileprivate var isRegisterTimerNotification = false

    // MARK: View Cyclex

    override func viewDidLoad() {
        super.viewDidLoad()

        initCommon()
        initDatasource()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.makeFirstResponder(descriptionTextField)
        updateNextKeyViews()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        unregisterTimerNotification()
    }

    @IBAction func closeBtnOnTap(_ sender: Any) {
        DesktopLibraryBridge.shared().togglEditor()
    }

    @IBAction func tagAddButtonOnTap(_ sender: Any) {
        openTagAutoCompleteView()
    }

    @IBAction func nextDateBtnOnTap(_ sender: Any) {
        guard let startDate = timeEntry.started,
            let nextDate = startDate.nextDate(),
            !timeEntry.isRunning() else {
            return
        }
        DesktopLibraryBridge.shared().updateTimeEntry(withStart: nextDate, guid: timeEntry.guid)
    }

    @IBAction func previousDateBtnOnTap(_ sender: Any) {
        guard let startDate = timeEntry.started,
            let nextDate = startDate.previousDate(),
            !timeEntry.isRunning() else {
                return
        }
        DesktopLibraryBridge.shared().updateTimeEntry(withStart: nextDate, guid: timeEntry.guid)
    }

    @IBAction func datePickerChanged(_ sender: Any) {
        DesktopLibraryBridge.shared().updateTimeEntry(withStart: datePickerView.dateValue, guid: timeEntry.guid)
    }
    
    @IBAction func dayButtonOnTap(_ sender: Any) {
        guard !timeEntry.isRunning() else { return }
        calendarPopover.present(from: dateSelectionBox.bounds, of: dateSelectionBox, preferredEdge: .maxY)
    }

    @IBAction func durationTextFieldOnChange(_ sender: Any) {
        guard durationTextField.stringValue != timeEntry.duration else { return }
        DesktopLibraryBridge.shared().updateTimeEntry(withDuration: durationTextField.stringValue,
                                                      guid: timeEntry.guid)
    }

    @IBAction func endAtBtnOnTap(_ sender: Any) {
        timeInputViewController.selectedComponent = .end
        presentTimeInputPopover()
    }

    @IBAction func billableCheckBoxOnChange(_ sender: Any) {
        guard let timeEntryGUID = timeEntry.guid else { return }
        let isBillable = billableCheckBox.state == .on
        DesktopLibraryBridge.shared().setBillableForTimeEntryWithTimeEntryGUID(timeEntryGUID,
                                                                               isBillable: isBillable)
    }

    @IBAction func deleteBtnOnTap(_ sender: Any) {
        DesktopLibraryBridge.shared().deleteTimeEntryImte(timeEntry)
    }
    
    @IBAction func startBtnOnTap(_ sender: Any) {
        timeInputViewController.selectedComponent = .start
        presentTimeInputPopover()
    }

    @IBAction func billableCheckBoxOnChange(_ sender: Any) {
        guard let timeEntryGUID = timeEntry.guid else { return }
        let isBillable = billableCheckBox.state == .on
        DesktopLibraryBridge.shared().setBillableForTimeEntryWithTimeEntryGUID(timeEntryGUID,
                                                                               isBillable: isBillable)
    }

    @IBAction func deleteBtnOnTap(_ sender: Any) {
        
    }
    
    private func presentTimeInputPopover() {
        if !timePopover.isShown {
            timePopover.present(from: timeContainerView.bounds, of: timeContainerView, preferredEdge: .maxY)
        }
    }
}

// MARK: Private

extension EditorViewController {

    fileprivate func initCommon() {
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        closeBtn.cursor = .pointingHand
        startAtBtn.cursor = .pointingHand

        descriptionTextField.autoCompleteDelegate = self
        projectTextField.autoCompleteDelegate = self
        projectTextField.dotImageView = projectDotImageView
        projectTextField.layoutArrowBtn(with: view)
        dayNameButton.cursor = .pointingHand

        durationTextField.delegate = self
        startAtTextField.delegate = self
        endAtTextField.delegate = self

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
    }

    fileprivate func initDatasource() {
        projectDatasource.delegate = self
        projectDatasource.setup(with: projectTextField)
        descriptionDatasource.delegate = self
        descriptionDatasource.setup(with: descriptionTextField)

        tagTextField.autoCompleteDelegate = self
        tagDatasource.delegate = self
        tagDatasource.tagDelegte = self
        tagDatasource.setup(with: tagTextField)
    }

    fileprivate func fillData() {
        guard let timeEntry = timeEntry else { return }
        workspaceLbl.stringValue = timeEntry.workspaceName
        descriptionTextField.stringValue = timeEntry.descriptionName
        billableCheckBox.state = timeEntry.billable ? .on : .off
        billableCheckBox.isHidden = !timeEntry.canSeeBillable
        projectTextField.setTimeEntry(timeEntry)
        calendarViewControler.prepareLayout(with: timeEntry.started)

        // Disable if it's running entry
        let isRunning = timeEntry.isRunning()
        endAtTextField.isHidden = isRunning
        datePickerView.isEnabled = !isRunning

        // Update Timer
        if isRunning {
            registerTimerNotification()
        } else {
            unregisterTimerNotification()
        }

        // Render other views
        renderTagsView()
        renderDatePicker()
        renderTime()
    }

    private func renderTagsView() {

        // Remove all
        tagStackView.subviews.forEach { $0.removeFromSuperview() }
        tagStackView.isHidden = true
        tagAddButton.isHidden = false
        tagInputContainerView.borderColor = borderColor

        // Add tag token if need
        if let tagNames = timeEntry.tags as? [String] {
            let tags = tagNames.map { Tag(name: $0) }

            // Update selected tags
            tagDatasource.updateSelectedTags(tags)

            // Render tag token
            let tokens = tags.map { tag -> TagTokenView in
                let view = TagTokenView.xibView() as TagTokenView
                view.delegate = self
                view.render(tag)
                return view
            }

            var width: CGFloat = 0
            for token in tokens {
                let size = token.fittingSize
                width += size.width + Constans.TokenViewSpacing
                if width <= Constans.MaximumTokenWidth {
                    tagStackView.addArrangedSubview(token)
                } else {
                    let moreToken = TagTokenView.xibView() as TagTokenView
                    moreToken.delegate = self
                    moreToken.render(Tag.moreTag)
                    tagStackView.addArrangedSubview(moreToken)
                    break
                }
            }

            tagStackView.isHidden = false
            tagAddButton.isHidden = true
            tagInputContainerView.borderColor = .clear
        }
        else {
            tagDatasource.updateSelectedTags([])
        }
    }

    private func renderDatePicker() {
        let isRunning = timeEntry.isRunning()
        let startDay = timeEntry.started!
        datePickerView.dateValue = startDay
        datePickerView.isEnabled = isRunning
        let dayName = startDay.dayOfWeekString() ?? "Unknown"
        dayNameButton.attributedTitle = NSAttributedString(string: "\(dayName),", attributes: dayNameAttribute)
    }

    private func renderTime() {
        durationTextField.stringValue = timeEntry.duration
        startAtBtn.title = timeEntry.startTimeString
        endAtBtn.title = timeEntry.endTimeString
        startAtBtn.setTextColor(NSColor.labelColor)
        endAtBtn.setTextColor(NSColor.labelColor)

        // Time controller
        timeInputViewController.timeEntry = timeEntry
    }

    fileprivate func updateNextKeyViews() {
        deleteBtn.nextKeyView = descriptionTextField
    }

    fileprivate func openTagAutoCompleteView() {
        tagTextField.openSuggestion()

        // Reload again to active the NSTrackingArea in TagCell
        // At the first time the cells are loaded, the view doesn't appear yet.
        // So TrackingArea doesn't work when hovering the mouse
        tagDatasource.tableView.reloadData()
    }

    fileprivate func registerTimerNotification() {
        guard !isRegisterTimerNotification else { return }

        isRegisterTimerNotification = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.timerOnTick),
                                               name: Constans.TimerNotification,
                                               object: nil)
    }

    fileprivate func unregisterTimerNotification() {
        guard isRegisterTimerNotification else { return }

        isRegisterTimerNotification = false
        NotificationCenter.default.removeObserver(self,
                                                  name: Constans.TimerNotification,
                                                  object: nil)
    }

    @objc private func timerOnTick() {
        // Ignore if the TE isn't running
        guard let timeEntry = timeEntry, timeEntry.isRunning() else { return }

        // Ignore if the user is editing
        guard durationTextField.currentEditor() == nil else { return }

        // Update
        let durationText = DesktopLibraryBridge.shared().convertDuraton(inSecond: timeEntry.duration_in_seconds)
        durationTextField.stringValue = durationText
    }
}

// MARK: AutoCompleteViewDataSourceDelegate

extension EditorViewController: AutoCompleteViewDataSourceDelegate {

    func autoCompleteSelectionDidChange(sender: AutoCompleteViewDataSource, item: Any) {
        if sender == projectDatasource {
            if let projectItem = item as? ProjectContentItem {
                selectedProjectItem = projectItem
                projectTextField.projectItem = projectItem
                projectTextField.closeSuggestion()

                // Update
                let item = projectItem.item
                let projectGUID = projectTextField.lastProjectGUID ?? ""
                DesktopLibraryBridge.shared().setProjectForTimeEntryWithGUID(timeEntry.guid,
                                                                             taskID: item.taskID,
                                                                             projectID: item.projectID,
                                                                             projectGUID: projectGUID)
            }
            return
        }

        if sender == descriptionDatasource {
            if let descriptionTimeEntry = item as? DescriptionTimeEntry {
                DesktopLibraryBridge.shared().updateDescription(forTimeEntry: timeEntry,
                                                                autocomplete: descriptionTimeEntry.item)
                descriptionTextField.closeSuggestion()
            }
        }
    }
}

extension EditorViewController: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        // Duration
        if textField == durationTextField {
            durationTextFieldOnChange(durationTextField)
            return
        }

        // Start at
        if textField == startAtTextField {
            startTextFieldOnChange(startAtTextField)
            return
        }

        // End at
        if textField == endAtTextField {
            endTextFieldOnChange(endAtTextField)
        }
    }
}

// MARK: AutoCompleteTextFieldDelegate

extension EditorViewController: AutoCompleteTextFieldDelegate {

    func autoCompleteDidTapOnCreateButton(_ sender: AutoCompleteTextField) {
        if sender == tagTextField {
            let newTag = Tag(name: sender.stringValue)
            var selectedTags = tagDatasource.selectedTags
            selectedTags.append(newTag)
            tagDatasource.updateSelectedTags(selectedTags)
            TagStorage.shared.addNewTag(newTag)
            DesktopLibraryBridge.shared().updateTimeEntry(withTags: selectedTags.toNames(), guid: timeEntry.guid)
        }
    }

    func autoCompleteViewDidClose(_ sender: AutoCompleteTextField) {
        if sender == tagTextField {
            tagTextField.removeFromSuperview()
            tagAutoCompleteContainerView.addSubview(tagTextField)
            tagTextField.edgesToSuperView()
        }
    }
    
    func shouldClearCurrentSelection(_ sender: AutoCompleteTextField) {
        if sender == projectTextField {
            selectedProjectItem = nil
            projectTextField.projectItem = nil
            projectTextField.closeSuggestion()

            // Update
            DesktopLibraryBridge.shared().setProjectForTimeEntryWithGUID(timeEntry.guid,
                                                                         taskID: 0,
                                                                         projectID: 0,
                                                                         projectGUID: "")
        }
    }

    func autoCompleteTextFieldDidEndEditing(_ sender: AutoCompleteTextField) {
        if sender == descriptionTextField {
            guard let timeEntry = timeEntry,
                timeEntry.descriptionName != descriptionTextField.stringValue else { return }
            let name = descriptionTextField.stringValue
            let guid = timeEntry.guid!
            DesktopLibraryBridge.shared().updateTimeEntry(withDescription: name, guid: guid)
        }
    }
}

// MARK: TagTokenViewDelegate

extension EditorViewController: TagTokenViewDelegate {

    func tagTokenShouldDelete(with tag: Tag, sender: TagTokenView) {
        guard !tag.isMoreTag && !tag.isEmptyTag else { return }
        sender.removeFromSuperview()
        if let tags = timeEntry.tags as? [String] {
            let remainingTags = tags.compactMap { (tagName) -> String? in
                if tagName == tag.name {
                    return nil
                }
                return tagName
            }
            DesktopLibraryBridge.shared().updateTimeEntry(withTags: remainingTags, guid: timeEntry.guid)
        }
    }

    func tagTokenShouldOpenAutoCompleteView() {
        openTagAutoCompleteView()
    }
}

// MARK: TagDataSourceDelegate

extension EditorViewController: TagDataSourceDelegate {

    func tagSelectionChanged(with selectedTags: [Tag]) {
        let tags = selectedTags.toNames()
        DesktopLibraryBridge.shared().updateTimeEntry(withTags: tags, guid: timeEntry.guid)
    }
}

// MARK: CalendarViewControllerDelegate

extension EditorViewController: CalendarViewControllerDelegate {

    func calendarViewControllerDidSelect(date: Date) {
        DesktopLibraryBridge.shared().updateTimeEntry(withStart: date, guid: timeEntry.guid)
    }
}
