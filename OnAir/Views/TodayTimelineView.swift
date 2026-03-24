import SwiftUI

struct TodayTimelineView: View {

    @ObservedObject var appState: AppState
    @State private var dismissedGaps: Set<String> = []
    @State private var activeMenuKey: String? = nil

    // Drag state
    @State private var draggingEvent: CalendarEvent? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var showMoveConfirm = false
    @State private var pendingMove: (event: CalendarEvent, newStart: Date, newEnd: Date)? = nil

    private var accentColor: Color { Color(hex: appState.settings.accentColorHex) }
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 56
    private let snapInterval: TimeInterval = 15 * 60 // 15 min snap

    private func gapKey(start: Date, end: Date) -> String {
        "\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.bottom, 8)

            if events.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            // Hour lines
                            hourGrid

                            // Meeting blocks + focus slots
                            eventBlocks

                            // Now indicator
                            nowIndicator
                        }
                        .frame(width: 250)
                        .padding(.leading, 40)
                    }
                    .onAppear {
                        // Scroll to current hour
                        proxy.scrollTo("now", anchor: .center)
                    }
                }
            }
        }
        .overlay {
            if showMoveConfirm, let move = pendingMove {
                moveConfirmDialog(event: move.event, newStart: move.newStart, newEnd: move.newEnd)
            }
        }
    }

    // MARK: - Move Confirmation

    private func moveConfirmDialog(event: CalendarEvent, newStart: Date, newEnd: Date) -> some View {
        let attendees = appState.calendarService.attendeeCount(eventId: event.id)
        let tf = DateFormatter()
        tf.dateFormat = appState.settings.use24HourTime ? "HH:mm" : "h:mm a"

        return ZStack {
            Color.black.opacity(0.4)
                .onTapGesture {
                    showMoveConfirm = false
                    pendingMove = nil
                }

            VStack(spacing: 0) {
                // Title
                VStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 18))
                        .foregroundStyle(accentColor)
                    Text("Move event?")
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Event details
                VStack(spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(tf.string(from: event.startDate))
                            .foregroundStyle(.white.opacity(0.4))
                            .strikethrough(true, color: .white.opacity(0.3))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundStyle(accentColor)
                        Text(tf.string(from: newStart))
                            .foregroundStyle(accentColor)
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if attendees > 0 {
                    Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5).padding(.horizontal, 12)
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("\(attendees) attendee\(attendees == 1 ? "" : "s") will be notified")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }

                Rectangle().fill(.white.opacity(0.06)).frame(height: 0.5).padding(.horizontal, 12)

                // Buttons
                HStack(spacing: 8) {
                    Button {
                        showMoveConfirm = false
                        pendingMove = nil
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        let ok = appState.calendarService.moveEvent(
                            id: event.id, newStart: newStart, newEnd: newEnd
                        )
                        if ok { appState.refreshEvents() }
                        showMoveConfirm = false
                        pendingMove = nil
                    } label: {
                        Text(attendees > 0 ? "Move & Notify" : "Move")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
                    .shadow(color: .black.opacity(0.6), radius: 20, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(accentColor)
                    .tracking(1.5)
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(events.count) meeting\(events.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                let focusMins = totalFocusMinutes
                if focusMins > 0 {
                    Text("\(focusMins)m focus available")
                        .font(.system(size: 10))
                        .foregroundStyle(accentColor.opacity(0.7))
                }
                let bookedMins = totalBookedMinutes
                if bookedMins > 0 {
                    Text("\(bookedMins)m focus booked")
                        .font(.system(size: 10))
                        .foregroundStyle(accentColor.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Hour Grid

    @State private var activeHourMenu: Int? = nil

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(displayHours, id: \.self) { hour in
                ZStack(alignment: .trailing) {
                    HStack(spacing: 8) {
                        Text(hourLabel(hour))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 36, alignment: .trailing)
                            .offset(x: -40)

                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 0.5)
                    }
                    .frame(height: hourHeight)
                    .contentShape(Rectangle())
                    .gesture(TapGesture(count: 2).onEnded {
                        withAnimation(.easeOut(duration: 0.15)) {
                            activeHourMenu = activeHourMenu == hour ? nil : hour
                        }
                    })

                    if activeHourMenu == hour {
                        VStack(alignment: .leading, spacing: 0) {
                            panelRow(icon: "brain.head.profile", label: "Focus 30m", color: accentColor) {
                                bookFocusBlock(from: dateForHour(hour), minutes: 30)
                                activeHourMenu = nil
                            }
                            panelDivider
                            panelRow(icon: "brain.head.profile", label: "Focus 60m", color: accentColor) {
                                bookFocusBlock(from: dateForHour(hour), minutes: 60)
                                activeHourMenu = nil
                            }
                            panelDivider
                            panelRow(icon: "calendar.badge.plus", label: "New event...", color: .white.opacity(0.6)) {
                                activeHourMenu = nil
                                NotificationCenter.default.post(name: .toggleTimeline, object: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    NotificationCenter.default.post(name: .toggleNewEvent, object: nil)
                                }
                            }
                        }
                        .frame(width: 170)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
                                .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .trailing)))
                        .zIndex(10)
                    }
                }
            }
        }
    }

    private func dateForHour(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Event Blocks + Focus Slots

    private var eventBlocks: some View {
        let slots = buildTimeSlots()

        return ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
            switch slot {
            case .meeting(let event):
                draggableBlock(event: event) { meetingBlock(event) }

            case .focusBlock(let event):
                draggableBlock(event: event) {
                    bookedBlock(
                        start: event.startDate,
                        end: event.endDate,
                        minutes: event.durationMinutes
                    )
                }

            case .focusGap(let start, let end):
                let mins = Int(end.timeIntervalSince(start) / 60)
                let key = gapKey(start: start, end: end)
                if mins >= 30 && !dismissedGaps.contains(key) {
                    focusBlock(start: start, end: end, minutes: mins)
                        .frame(height: heightForDuration(mins))
                        .offset(y: offsetForTime(start))
                }

            case .commute(let start, let end, let isMorning):
                let mins = Int(end.timeIntervalSince(start) / 60)
                commuteBlock(start: start, end: end, minutes: mins, isMorning: isMorning)
                    .frame(height: heightForDuration(mins))
                    .offset(y: offsetForTime(start))
            }
        }
    }

    private func meetingBlock(_ event: CalendarEvent) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.calendarColorHex))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(timeRange(event))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let link = event.meetingLink {
                    Text(link.platform.displayName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let link = event.meetingLink {
                Button {
                    NSWorkspace.shared.open(link.url)
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: event.calendarColorHex).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(hex: event.calendarColorHex).opacity(0.2), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func focusBlock(start: Date, end: Date, minutes: Int) -> some View {
        let key = gapKey(start: start, end: end)

        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.opacity(0.3))
                .frame(width: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(accentColor.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 3)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(minutes)m available")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor.opacity(0.7))

                Text("\(timeLabel(start)) – \(timeLabel(end))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Actions
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    activeMenuKey = activeMenuKey == key ? nil : key
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentColor.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(accentColor.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(focusBlockBg)
        .overlay(focusBlockBorder)
        .overlay(alignment: .topTrailing) {
            if activeMenuKey == key {
                focusActionPanel(start: start, end: end, minutes: minutes, key: key)
                    .offset(x: 4, y: 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .zIndex(activeMenuKey == key ? 10 : 0)
    }

    @ViewBuilder
    private func focusActionPanel(start: Date, end: Date, minutes: Int, key: String) -> some View {
        let now = Date()
        let isCurrent = now >= start && now < end
        let bookedToday = totalBookedMinutes
        let remaining = max(0, 240 - bookedToday)
        let autoMins = min(minutes, 60, remaining)

        VStack(alignment: .leading, spacing: 0) {
            // Start focus
            if isCurrent && !appState.focusService.isRunning {
                let remainingMins = Int(end.timeIntervalSince(now) / 60)
                panelRow(icon: "play.fill", label: "Start focus (\(remainingMins)m)", color: accentColor) {
                    appState.focusService.start(duration: remainingMins * 60, label: "Focus")
                    activeMenuKey = nil
                }
                panelDivider
            }

            // Auto block
            if remaining > 0 && autoMins >= 30 {
                panelRow(icon: "calendar.badge.plus", label: "Block \(autoMins)m", color: accentColor) {
                    bookFocusBlock(from: start, minutes: autoMins)

                    activeMenuKey = nil
                }
                panelDivider
            }

            // Custom durations
            let durations = [15, 30, 45, 60, 90, 120, 150, 180].filter { $0 <= minutes }
            if !durations.isEmpty {
                Text("CUSTOM")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.2))
                    .tracking(1)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                HStack(spacing: 4) {
                    ForEach(durations, id: \.self) { m in
                        Button {
                            bookFocusBlock(from: start, minutes: m)
        
                            activeMenuKey = nil
                        } label: {
                            Text("\(m)m")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                panelDivider
            }

            // Dismiss
            panelRow(icon: "xmark", label: "Dismiss", color: .red.opacity(0.7)) {
                withAnimation(.easeOut(duration: 0.2)) {
                    _ = dismissedGaps.insert(key)
                }
                activeMenuKey = nil
            }
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func panelRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .onHover { hovering in
            // SwiftUI handles hover highlight via contentShape
        }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, 8)
    }

    private func draggableBlock<Content: View>(event: CalendarEvent, @ViewBuilder content: () -> Content) -> some View {
        let isDragging = draggingEvent?.id == event.id
        return content()
            .frame(height: heightForDuration(event.durationMinutes))
            .offset(y: offsetForTime(event.startDate) + (isDragging ? dragOffset : 0))
            .opacity(isDragging ? 0.8 : 1)
            .zIndex(isDragging ? 100 : 1)
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 5))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if draggingEvent == nil {
                                draggingEvent = event
                                NSCursor.closedHand.push()
                            }
                            if let drag { dragOffset = drag.translation.height }
                        default: break
                        }
                    }
                    .onEnded { _ in
                        NSCursor.pop()
                        guard let evt = draggingEvent else { return }
                        let snappedMinutes = round(Double(dragOffset) / hourHeight * 60 / 15) * 15
                        let newStart = evt.startDate.addingTimeInterval(snappedMinutes * 60)
                        let newEnd = evt.endDate.addingTimeInterval(snappedMinutes * 60)
                        if abs(snappedMinutes) >= 15 {
                            pendingMove = (evt, newStart, newEnd)
                            showMoveConfirm = true
                        }
                        draggingEvent = nil
                        dragOffset = 0
                    }
            )
    }

    private func bookFocusBlock(from start: Date, minutes: Int) {
        let blockEnd = start.addingTimeInterval(Double(minutes) * 60)
        let ok = appState.calendarService.createFocusBlock(
            from: start, to: blockEnd,
            calendarId: appState.settings.focusCalendarId
        )
        if ok { appState.refreshEvents() }
    }

    private var focusBlockBg: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(accentColor.opacity(0.03))
    }

    private var focusBlockBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(accentColor.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
    }

    private func bookedBlock(start: Date, end: Date, minutes: Int) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(accentColor)
                    Text("Focus Block")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor.opacity(0.8))
                }

                Text("\(timeLabel(start)) – \(timeLabel(end)) · \(minutes)m · Busy")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(accentColor.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Now Indicator

    private func commuteBlock(start: Date, end: Date, minutes: Int, isMorning: Bool) -> some View {
        HStack(spacing: 10) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: isMorning ? "car.fill" : "house.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.blue.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isMorning ? "Commute to work" : "Commute home")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))

                Text("\(timeLabel(start)) – \(timeLabel(end)) · \(minutes)m")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.12), style: StrokeStyle(lineWidth: 0.5, dash: [6, 4]))
        )
    }

    private var nowIndicator: some View {
        let y = offsetForTime(Date())
        return HStack(spacing: 4) {
            Circle()
                .fill(accentColor)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(accentColor)
                .frame(height: 1.5)
        }
        .offset(y: y)
        .id("now")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sun.max")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(accentColor.opacity(0.4))
            Text("No meetings today")
                .font(.system(size: 14, weight: .semibold))
            Text("The whole day is yours to focus.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if !appState.focusService.isRunning {
                Button {
                    appState.focusService.start(duration: 25 * 60, label: "Focus")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("Start 25m Focus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(accentColor.opacity(0.8))
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private var events: [CalendarEvent] {
        appState.todayEvents.filter { $0.endDate > Date() || appState.settings.showPastMeetings }
    }

    /// Focus Block events from calendar (filtered out of main todayEvents by shouldShow)
    private var focusBlockEvents: [CalendarEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return appState.calendarService.fetchFocusBlocks(from: start, to: end)
    }

    private enum TimeSlot {
        case meeting(CalendarEvent)
        case focusBlock(CalendarEvent)
        case focusGap(start: Date, end: Date)
        case commute(start: Date, end: Date, isMorning: Bool)
    }

    /// Commute windows for today (if enabled and it's a commute day)
    private var commuteWindows: [(start: Date, end: Date, isMorning: Bool)] {
        var windows: [(Date, Date, Bool)] = []
        if let m = appState.settings.morningCommuteToday() { windows.append((m.start, m.end, true)) }
        if let e = appState.settings.eveningCommuteToday() { windows.append((e.start, e.end, false)) }
        return windows
    }

    /// Check if a time range overlaps with any commute window
    private func overlapsCommute(start: Date, end: Date) -> Bool {
        commuteWindows.contains { start < $0.end && end > $0.start }
    }

    /// Clamp a focus gap to work hours (9am–10pm), excluding commute windows. Returns sub-gaps.
    private func clampToWorkHours(start: Date, end: Date) -> [(Date, Date)] {
        let today = Date()
        guard let workStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today),
              let workEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today) else { return [] }
        let clamped0 = max(start, workStart)
        let clamped1 = min(end, workEnd)
        guard clamped0 < clamped1 else { return [] }

        // Subtract commute windows from the gap
        var gaps: [(Date, Date)] = [(clamped0, clamped1)]
        for commute in commuteWindows {
            gaps = gaps.flatMap { gap -> [(Date, Date)] in
                if commute.start >= gap.1 || commute.end <= gap.0 { return [gap] } // no overlap
                var result: [(Date, Date)] = []
                if gap.0 < commute.start { result.append((gap.0, commute.start)) }
                if commute.end < gap.1 { result.append((commute.end, gap.1)) }
                return result
            }
        }
        return gaps
    }

    private let focusBuffer: TimeInterval = 30 * 60 // 30 min buffer around meetings

    private func buildTimeSlots() -> [TimeSlot] {
        // Merge meetings + focus blocks to compute gaps correctly
        let allOccupied = (events + focusBlockEvents).sorted { $0.startDate < $1.startDate }
        let sorted = allOccupied
        var slots: [TimeSlot] = []
        var cursor = sorted.first?.startDate ?? Date()

        let now = Date()
        if let first = sorted.first, now < first.startDate {
            cursor = now
            // End focus 30min before meeting
            let focusEnd = first.startDate.addingTimeInterval(-focusBuffer)
            if focusEnd > now {
                for gap in clampToWorkHours(start: now, end: focusEnd) {
                    slots.append(.focusGap(start: gap.0, end: gap.1))
                }
            }
        }

        for (i, event) in sorted.enumerated() {
            // Focus gap between meetings: start 30min after previous, end 30min before next
            let gapStart = cursor.addingTimeInterval(focusBuffer)
            let gapEnd = event.startDate.addingTimeInterval(-focusBuffer)
            if gapStart < gapEnd && gapStart > cursor {
                for gap in clampToWorkHours(start: gapStart, end: gapEnd) {
                    slots.append(.focusGap(start: gap.0, end: gap.1))
                }
            }
            if event.isFocusBlock {
                slots.append(.focusBlock(event))
            } else {
                slots.append(.meeting(event))
            }
            cursor = max(cursor, event.endDate)
        }

        // Trailing focus gap: start 30min after last meeting
        if let last = sorted.last {
            let focusStart = last.endDate.addingTimeInterval(focusBuffer)
            let trailingEnd = focusStart.addingTimeInterval(3600)
            for gap in clampToWorkHours(start: focusStart, end: trailingEnd) {
                slots.append(.focusGap(start: gap.0, end: gap.1))
            }
        }

        // Insert commute blocks
        for commute in commuteWindows {
            slots.append(.commute(start: commute.start, end: commute.end, isMorning: commute.isMorning))
        }

        // Sort all slots by start time
        slots.sort { startTime($0) < startTime($1) }

        return slots
    }

    private func startTime(_ slot: TimeSlot) -> Date {
        switch slot {
        case .meeting(let e): return e.startDate
        case .focusBlock(let e): return e.startDate
        case .focusGap(let s, _): return s
        case .commute(let s, _, _): return s
        }
    }

    private var totalFocusMinutes: Int {
        let slots = buildTimeSlots()
        return slots.reduce(0) { total, slot in
            if case .focusGap(let s, let e) = slot {
                return total + Int(e.timeIntervalSince(s) / 60)
            }
            return total
        }
    }

    /// Total minutes of focus blocks booked today (from calendar events titled "Focus Block")
    private var totalBookedMinutes: Int {
        focusBlockEvents.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Layout Helpers

    private var displayHours: [Int] {
        let sorted = events.sorted { $0.startDate < $1.startDate }
        var firstHour = sorted.first.map { calendar.component(.hour, from: $0.startDate) } ?? 9
        var lastHour = sorted.last.map { calendar.component(.hour, from: $0.endDate) + 1 } ?? 18

        // Include commute windows in the range
        if let m = appState.settings.morningCommuteToday() {
            firstHour = min(firstHour, calendar.component(.hour, from: m.start))
        }
        if let e = appState.settings.eveningCommuteToday() {
            lastHour = max(lastHour, calendar.component(.hour, from: e.end) + 1)
        }

        return Array(0..<24)
    }

    private var timelineStartHour: Int {
        displayHours.first ?? 9
    }

    private func offsetForTime(_ date: Date) -> CGFloat {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let totalMinutes = CGFloat((comps.hour ?? 0) - timelineStartHour) * 60 + CGFloat(comps.minute ?? 0)
        return totalMinutes / 60 * hourHeight
    }

    private func heightForDuration(_ minutes: Int) -> CGFloat {
        max(CGFloat(minutes) / 60 * hourHeight, 32)
    }

    private func hourLabel(_ hour: Int) -> String {
        if appState.settings.use24HourTime {
            return String(format: "%02d:00", hour)
        }
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = appState.settings.use24HourTime ? "HH:mm" : "h:mm a"
        return f.string(from: date)
    }

    private func timeRange(_ event: CalendarEvent) -> String {
        "\(timeLabel(event.startDate)) - \(timeLabel(event.endDate))"
    }
}
