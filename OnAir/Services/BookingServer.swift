import Foundation
import Network
import EventKit

final class BookingServer {

    private var listener: NWListener?
    private let calendarService: CalendarService
    private let settings: UserSettings
    private let port: UInt16

    var isRunning: Bool { listener != nil }

    var bookingURL: String { "http://localhost:\(port)" }

    init(calendarService: CalendarService, settings: UserSettings, port: UInt16 = 8432) {
        self.calendarService = calendarService
        self.settings = settings
        self.port = port
    }

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }
            listener?.start(queue: .main)
        } catch {
            listener = nil
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let response = self.route(request)
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - Router

    private func route(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return httpResponse(400, "Bad Request") }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return httpResponse(400, "Bad Request") }
        let method = String(parts[0])
        let path = String(parts[1])

        if method == "OPTIONS" { return corsResponse() }

        switch (method, path) {
        case ("GET", "/"):
            return httpResponse(200, bookingPageHTML(), contentType: "text/html")
        case ("GET", "/api/slots"):
            return httpResponse(200, slotsJSON(), contentType: "application/json")
        case ("POST", "/api/book"):
            let body = extractBody(raw)
            return handleBooking(body)
        default:
            return httpResponse(404, "Not Found")
        }
    }

    // MARK: - Slots API

    private func slotsJSON() -> String {
        let slots = availableSlots()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(slots) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    struct BookableSlot: Codable {
        let date: String
        let dayLabel: String
        let start: String
        let end: String
        let startISO: Date
    }

    private func availableSlots() -> [BookableSlot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEE, MMM d"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        var slots: [BookableSlot] = []

        for dayOffset in 1...settings.bookingDaysAhead {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let weekday = cal.component(.weekday, from: date)
            guard settings.isBookingDay(weekday) else { continue }

            let dayStart = cal.startOfDay(for: date)
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let events = calendarService.fetchEvents(from: dayStart, to: dayEnd, disabledCalendarIds: [])

            let slotDuration = settings.bookingSlotMinutes
            let buffer = settings.bookingBufferMinutes
            var hour = settings.bookingStartHour
            var minute = 0

            while hour < settings.bookingEndHour || (hour == settings.bookingEndHour && minute == 0) {
                guard let slotStart = cal.date(bySettingHour: hour, minute: minute, second: 0, of: date),
                      let slotEnd = cal.date(byAdding: .minute, value: slotDuration, to: slotStart) else {
                    minute += slotDuration + buffer
                    if minute >= 60 { hour += minute / 60; minute = minute % 60 }
                    continue
                }

                let endHour = cal.component(.hour, from: slotEnd)
                let endMinute = cal.component(.minute, from: slotEnd)
                if endHour > settings.bookingEndHour || (endHour == settings.bookingEndHour && endMinute > 0) {
                    break
                }

                let bufferStart = cal.date(byAdding: .minute, value: -buffer, to: slotStart)!
                let bufferEnd = cal.date(byAdding: .minute, value: buffer, to: slotEnd)!
                let hasConflict = events.contains { event in
                    event.startDate < bufferEnd && event.endDate > bufferStart
                }

                if !hasConflict {
                    slots.append(BookableSlot(
                        date: df.string(from: date),
                        dayLabel: dayFmt.string(from: date),
                        start: timeFmt.string(from: slotStart),
                        end: timeFmt.string(from: slotEnd),
                        startISO: slotStart
                    ))
                }

                minute += slotDuration + buffer
                if minute >= 60 { hour += minute / 60; minute = minute % 60 }
            }
        }

        return slots
    }

    // MARK: - Booking API

    private func handleBooking(_ body: String) -> String {
        guard let data = body.data(using: .utf8),
              let json = try? JSONDecoder().decode(BookingRequest.self, from: data) else {
            return httpResponse(400, "{\"error\":\"Invalid request\"}", contentType: "application/json")
        }

        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        guard let startDate = df.date(from: "\(json.date) \(json.start)") else {
            return httpResponse(400, "{\"error\":\"Invalid date\"}", contentType: "application/json")
        }
        let endDate = cal.date(byAdding: .minute, value: settings.bookingSlotMinutes, to: startDate)!

        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "\(json.name) — Booking"
        event.startDate = startDate
        event.endDate = endDate
        var noteLines = ["Booked via OnAir", "Email: \(json.email)"]
        if let notes = json.notes, !notes.isEmpty { noteLines.append(notes) }
        event.notes = noteLines.joined(separator: "\n")
        event.calendar = store.defaultCalendarForNewEvents

        do {
            try store.save(event, span: .thisEvent)
            return httpResponse(200, "{\"success\":true}", contentType: "application/json")
        } catch {
            return httpResponse(500, "{\"error\":\"Failed to create event\"}", contentType: "application/json")
        }
    }

    struct BookingRequest: Codable {
        let date: String
        let start: String
        let name: String
        let email: String
        let notes: String?
    }

    // MARK: - HTTP Helpers

    private func extractBody(_ raw: String) -> String {
        guard let range = raw.range(of: "\r\n\r\n") else { return "" }
        return String(raw[range.upperBound...])
    }

    private func httpResponse(_ code: Int, _ body: String, contentType: String = "text/plain") -> String {
        let status = code == 200 ? "OK" : code == 400 ? "Bad Request" : code == 404 ? "Not Found" : "Error"
        return "HTTP/1.1 \(code) \(status)\r\nContent-Type: \(contentType); charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(body)"
    }

    private func corsResponse() -> String {
        return "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n"
    }

    // MARK: - Fetch Events (all calendars)

    // MARK: - Booking Page

    private func bookingPageHTML() -> String {
        let displayName = settings.bookingName.isEmpty ? "Guest" : escapeHTML(settings.bookingName)
        let initials = settings.bookingName.split(separator: " ").prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
        let slotMins = settings.bookingSlotMinutes
        let tzFull = TimeZone.current.identifier.replacingOccurrences(of: "_", with: " ")
        let tz = TimeZone.current.abbreviation() ?? "Local"

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Book time with \(displayName)</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Satoshi:wght@300;400;500;700;900&display=swap" rel="stylesheet">
        <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
            --accent: #e84030; --accent2: #ff6b4a;
            --accent-soft: rgba(232,64,48,0.08); --accent-glow: rgba(232,64,48,0.2);
            --text: #f0ece4; --text2: rgba(255,255,255,0.45); --text3: rgba(255,255,255,0.2);
            --bg: #08070a; --surface: #0f0e12; --surface2: #16141a;
            --border: rgba(255,255,255,0.05); --border2: rgba(255,255,255,0.08);
        }
        body {
            font-family: 'Satoshi', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg); color: var(--text);
            min-height: 100vh; display: flex; align-items: center; justify-content: center;
            padding: 24px; -webkit-font-smoothing: antialiased;
        }
        body::after {
            content: '';
            position: fixed; inset: 0;
            background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.025'/%3E%3C/svg%3E");
            pointer-events: none; z-index: 9999;
        }
        .card {
            background: var(--surface); border-radius: 14px;
            border: 1px solid var(--border2);
            box-shadow: 0 2px 4px rgba(0,0,0,0.3), 0 8px 32px rgba(0,0,0,0.5);
            display: grid; grid-template-columns: 280px 1fr;
            max-width: 1000px; width: 100%; min-height: 500px; overflow: hidden;
            transition: grid-template-columns 0.3s ease;
        }
        .card.with-times { grid-template-columns: 280px 1fr 260px; }

        /* Left sidebar */
        .sidebar {
            padding: 0; border-right: 1px solid var(--border);
            display: flex; flex-direction: column; background: var(--surface);
        }
        .sidebar-accent { height: 3px; background: var(--accent); border-radius: 0 0 2px 2px; margin: 0 24px; }
        .sidebar-content { padding: 28px 28px 32px; }
        .avatar {
            width: 52px; height: 52px; border-radius: 50%;
            background: var(--accent); display: flex; align-items: center;
            justify-content: center; font-size: 18px; font-weight: 700;
            color: #fff; margin-bottom: 18px;
            box-shadow: 0 2px 12px var(--accent-glow), 0 0 30px rgba(232,64,48,0.1);
        }
        .host-name { font-size: 14px; color: var(--text2); margin-bottom: 4px; font-weight: 500; }
        .event-title {
            font-family: 'Instrument Serif', serif;
            font-size: 26px; font-weight: 400; color: var(--text);
            margin-bottom: 24px; line-height: 1.2; letter-spacing: -0.02em;
        }
        .meta-row {
            display: flex; align-items: center; gap: 10px;
            margin-bottom: 12px; color: var(--text2); font-size: 14px; font-weight: 500;
        }
        .meta-icon {
            width: 32px; height: 32px; border-radius: 8px;
            background: var(--accent-soft); display: flex; align-items: center;
            justify-content: center; font-size: 14px; flex-shrink: 0;
        }

        /* Calendar center */
        .calendar-section { padding: 28px 32px; border-right: 1px solid var(--border); background: var(--surface); }
        .cal-header {
            font-family: 'Instrument Serif', serif;
            font-size: 18px; font-weight: 400; margin-bottom: 20px; color: var(--text);
            letter-spacing: -0.01em;
        }
        .month-nav { display: flex; align-items: center; justify-content: center; gap: 16px; margin-bottom: 16px; }
        .month-nav .label { font-size: 15px; font-weight: 600; min-width: 140px; text-align: center; color: var(--text); }
        .month-nav button {
            width: 32px; height: 32px; border-radius: 50%; border: 1px solid var(--border2);
            background: var(--surface2); cursor: pointer; font-size: 14px; color: var(--text2);
            display: flex; align-items: center; justify-content: center; transition: all 0.15s;
        }
        .month-nav button:hover { border-color: var(--accent); color: var(--accent); }
        .cal-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 0; text-align: center; }
        .cal-grid .dow { font-size: 10px; font-weight: 700; color: var(--text3); text-transform: uppercase; padding: 8px 0; letter-spacing: 0.1em; }
        .cal-grid .day-cell {
            padding: 6px; display: flex; align-items: center; justify-content: center;
        }
        .cal-grid .day-inner {
            width: 36px; height: 36px; border-radius: 50%;
            display: flex; align-items: center; justify-content: center;
            font-size: 14px; color: var(--text3); transition: all 0.15s; position: relative;
        }
        .cal-grid .day-inner.available { color: var(--text); font-weight: 600; cursor: pointer; }
        .cal-grid .day-inner.available:hover { background: var(--surface2); }
        .cal-grid .day-inner.selected { background: var(--accent); color: #fff; font-weight: 700; box-shadow: 0 2px 10px var(--accent-glow), 0 0 24px rgba(232,64,48,0.12); }
        .cal-grid .day-inner.other-month { color: rgba(255,255,255,0.08); }
        .cal-grid .day-inner.available::after {
            content: ''; position: absolute; bottom: 2px; left: 50%; transform: translateX(-50%);
            width: 4px; height: 4px; border-radius: 50%; background: var(--accent); opacity: 0.5;
        }
        .cal-grid .day-inner.selected::after { opacity: 0; }
        .tz-row { margin-top: 24px; font-size: 13px; color: var(--text2); display: flex; align-items: center; gap: 6px; }
        .tz-row strong { font-weight: 600; color: var(--text); }

        /* Time slots right */
        .times-section { padding: 28px 20px; display: none; overflow-y: auto; max-height: 500px; background: var(--surface); }
        .times-section.active { display: block; }
        .times-date { font-family: 'Instrument Serif', serif; font-size: 17px; font-weight: 400; margin-bottom: 16px; color: var(--text); }
        .time-slot {
            width: 100%; padding: 13px; margin-bottom: 0; border: 1px solid var(--border2);
            border-radius: 8px; background: var(--surface2); color: var(--text);
            font-family: 'Satoshi', sans-serif; font-size: 15px; font-weight: 600;
            cursor: pointer; transition: all 0.2s; text-align: center;
        }
        .time-slot:hover { background: rgba(255,255,255,0.06); border-color: rgba(255,255,255,0.12); }
        .time-slot-row { display: flex; gap: 6px; margin-bottom: 8px; opacity: 0; animation: slotIn 0.25s ease-out forwards; }
        .time-slot-row .time-slot { margin-bottom: 0; }
        .time-slot-row .time-slot.picked { background: var(--accent); border-color: var(--accent); color: #fff; }
        .confirm-btn {
            padding: 13px 20px; border: none; border-radius: 8px;
            background: var(--accent); color: #fff; font-family: 'Satoshi', sans-serif;
            font-size: 15px; font-weight: 600; cursor: pointer; flex-shrink: 0;
            transition: all 0.2s;
            box-shadow: 0 1px 2px rgba(0,0,0,0.4), 0 4px 16px rgba(232,64,48,0.15);
        }
        .confirm-btn:hover { box-shadow: 0 1px 2px rgba(0,0,0,0.4), 0 8px 28px rgba(232,64,48,0.25); transform: translateY(-1px); }
        @keyframes slotIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }

        /* Form overlay */
        .form-view { display: none; padding: 32px; background: var(--surface); }
        .form-view.active { display: block; }
        .form-view h3 { font-family: 'Instrument Serif', serif; font-size: 22px; font-weight: 400; margin-bottom: 4px; color: var(--text); }
        .form-view .form-meta { color: var(--text2); font-size: 14px; margin-bottom: 24px; font-weight: 500; }
        .form-field { margin-bottom: 16px; }
        .form-field label { display: block; font-size: 12px; font-weight: 700; color: var(--text2); margin-bottom: 6px; letter-spacing: 0.04em; text-transform: uppercase; }
        .form-field input, .form-field textarea {
            width: 100%; border: 1px solid var(--border2); border-radius: 8px;
            padding: 10px 12px; font-size: 14px; font-family: 'Satoshi', sans-serif;
            outline: none; transition: border-color 0.15s; color: var(--text);
            background: var(--surface2);
        }
        .form-field input::placeholder, .form-field textarea::placeholder { color: var(--text3); }
        .form-field input:focus, .form-field textarea:focus { border-color: var(--accent); }
        .form-field textarea { resize: vertical; min-height: 60px; }
        .schedule-btn {
            width: 100%; padding: 14px; border: none; border-radius: 8px;
            background: var(--accent); color: #fff; font-size: 15px;
            font-weight: 700; cursor: pointer; font-family: 'Satoshi', sans-serif;
            box-shadow: 0 1px 2px rgba(0,0,0,0.4), 0 8px 28px rgba(232,64,48,0.2);
            transition: all 0.2s;
        }
        .schedule-btn:hover { box-shadow: 0 1px 2px rgba(0,0,0,0.4), 0 14px 40px rgba(232,64,48,0.25); transform: translateY(-1px); }
        .schedule-btn:disabled { opacity: 0.4; cursor: not-allowed; transform: none; box-shadow: none; }
        .back-link2 { display: inline-block; margin-top: 12px; color: var(--text2); font-size: 13px; cursor: pointer; border: none; background: none; font-family: 'Satoshi', sans-serif; font-weight: 500; }
        .back-link2:hover { color: var(--text); }

        /* Success */
        .success-card { display: none; text-align: center; padding: 60px 40px; }
        .success-card h2 { font-family: 'Instrument Serif', serif; font-size: 28px; font-weight: 400; margin-bottom: 8px; color: var(--text); }
        .success-card p { color: var(--text2); font-size: 15px; font-weight: 500; }
        .success-check { font-size: 40px; margin-bottom: 16px; }

        /* Nav */
        .onair-nav {
            position: fixed; top: 0; width: 100%; z-index: 100;
            padding: 0.85rem 2rem; display: flex; align-items: center; justify-content: space-between;
            backdrop-filter: blur(24px) saturate(1.4); -webkit-backdrop-filter: blur(24px) saturate(1.4);
            background: rgba(8,7,10,0.65); border-bottom: 1px solid var(--border);
        }
        .nav-brand {
            display: flex; align-items: center; gap: 0.5rem;
            text-decoration: none; color: var(--text);
        }
        .nav-dot {
            width: 7px; height: 7px; border-radius: 50%; background: var(--accent);
            box-shadow: 0 0 8px var(--accent), 0 0 24px rgba(232,64,48,0.12);
            animation: pulse 2.5s ease-in-out infinite;
        }
        .nav-brand span { font-weight: 700; font-size: 0.92rem; letter-spacing: -0.02em; }
        .nav-links { display: flex; gap: 1.5rem; align-items: center; }
        .nav-links a {
            color: var(--text3); text-decoration: none; font-size: 0.82rem;
            font-weight: 500; transition: color 0.2s; letter-spacing: 0.01em;
        }
        .nav-links a:hover { color: var(--text); }
        .nav-links .active { color: var(--accent2); font-size: 0.82rem; font-weight: 500; }

        /* Footer */
        .onair-footer {
            position: fixed; bottom: 0; width: 100%; z-index: 100;
            padding: 0.75rem 2rem; display: flex; align-items: center; justify-content: space-between;
            border-top: 1px solid var(--border); background: rgba(8,7,10,0.7);
            backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px);
        }
        .footer-brand { display: flex; align-items: center; gap: 0.4rem; }
        .footer-brand .nav-dot { width: 5px; height: 5px; animation: none; }
        .footer-brand span { font-weight: 600; font-size: 0.78rem; color: var(--text2); }
        .footer-right { font-size: 0.72rem; color: var(--text3); }
        .footer-right a { color: var(--text2); text-decoration: none; }
        .footer-right a:hover { color: var(--text); }

        @keyframes pulse {
            0%, 100% { opacity: 1; box-shadow: 0 0 8px var(--accent), 0 0 24px rgba(232,64,48,0.12); }
            50% { opacity: 0.4; box-shadow: 0 0 3px var(--accent); }
        }

        /* Adjust body for fixed nav/footer */
        body { padding: 72px 24px 56px; }
        </style>
        </head>
        <body>
        <nav class="onair-nav">
            <a href="javascript:history.back()" class="nav-brand"><div class="nav-dot"></div><span>OnAir</span></a>
            <div class="nav-links">
                <span class="active">Book a meeting</span>
            </div>
        </nav>
        <div>
        <div class="card" id="card">
            <div class="sidebar">
                <div class="sidebar-accent"></div>
                <div class="sidebar-content">
                    <div class="avatar">\(initials.isEmpty ? "?" : initials)</div>
                    <div class="host-name">\(displayName)</div>
                    <div class="event-title">Meeting</div>
                    <div class="meta-row"><span class="meta-icon">&#9201;</span> <span>\(slotMins) min</span></div>
                    <div class="meta-row"><span class="meta-icon">&#9654;</span> <span>Video call</span></div>
                </div>
            </div>
            <div class="calendar-section" id="cal-section">
                <div class="cal-header">Select a Date &amp; Time</div>
                <div class="month-nav">
                    <button id="prev-month">&#8249;</button>
                    <span class="label" id="month-label"></span>
                    <button id="next-month">&#8250;</button>
                </div>
                <div class="cal-grid" id="cal-grid"></div>
                <div class="tz-row"><strong>Time zone</strong></div>
                <div class="tz-row" style="margin-top:4px">\(escapeHTML(tzFull)) (\(tz))</div>
            </div>
            <div class="times-section" id="times-section">
                <div class="times-date" id="times-date"></div>
                <div id="times-list"></div>
            </div>
            <div class="form-view" id="form-view">
                <h3>Enter Details</h3>
                <p class="form-meta" id="form-meta"></p>
                <div class="form-field"><label>Name *</label><input id="f-name" placeholder="Your name"></div>
                <div class="form-field"><label>Email *</label><input type="email" id="f-email" placeholder="you@company.com"></div>
                <div class="form-field"><label>Notes</label><textarea id="f-notes" placeholder="Share anything that will help prepare for the meeting"></textarea></div>
                <button class="schedule-btn" id="schedule-btn">Schedule Event</button>
                <button class="back-link2" id="back-btn2">&larr; Back</button>
            </div>
        </div>
        <div class="card success-card" id="success-card">
            <div class="success-check">&#9989;</div>
            <h2>Confirmed</h2>
            <p>You are scheduled. A calendar event has been created.</p>
        </div>
        </div>
        <footer class="onair-footer">
            <div class="footer-brand"><div class="nav-dot"></div><span>OnAir</span></div>
            <div class="footer-right">Built by <a href="#">\(displayName)</a></div>
        </footer>

        <script>
        let allSlots=[], groups={}, viewDate=new Date(), selectedDate=null, selectedSlot=null, availableDates=new Set();

        async function init(){
            const res=await fetch('/api/slots');
            allSlots=await res.json();
            allSlots.forEach(s=>{
                if(!groups[s.date]) groups[s.date]={label:s.dayLabel,slots:[]};
                groups[s.date].slots.push(s);
                availableDates.add(s.date);
            });
            if(allSlots.length){
                const first=allSlots[0].startISO||allSlots[0].date;
                viewDate=new Date(first);
            }
            renderCalendar();
            if(allSlots.length){ selectDate(allSlots[0].date); }
            document.getElementById('prev-month').addEventListener('click',()=>{viewDate.setMonth(viewDate.getMonth()-1);renderCalendar();});
            document.getElementById('next-month').addEventListener('click',()=>{viewDate.setMonth(viewDate.getMonth()+1);renderCalendar();});
        }

        function renderCalendar(){
            const y=viewDate.getFullYear(), m=viewDate.getMonth();
            const months=['January','February','March','April','May','June','July','August','September','October','November','December'];
            document.getElementById('month-label').textContent=months[m]+' '+y;
            const grid=document.getElementById('cal-grid');
            grid.textContent='';
            ['SUN','MON','TUE','WED','THU','FRI','SAT'].forEach(d=>{
                const el=document.createElement('div');el.className='dow';el.textContent=d;grid.appendChild(el);
            });
            const first=new Date(y,m,1), startDay=first.getDay();
            const lastDay=new Date(y,m+1,0).getDate();
            const prevLast=new Date(y,m,0).getDate();
            for(let i=0;i<startDay;i++){
                const cell=document.createElement('div');cell.className='day-cell';
                const inner=document.createElement('div');inner.className='day-inner other-month';
                inner.textContent=prevLast-startDay+1+i;cell.appendChild(inner);grid.appendChild(cell);
            }
            for(let d=1;d<=lastDay;d++){
                const dateStr=y+'-'+String(m+1).padStart(2,'0')+'-'+String(d).padStart(2,'0');
                const cell=document.createElement('div');cell.className='day-cell';
                const inner=document.createElement('div');inner.className='day-inner';
                inner.textContent=d;
                if(availableDates.has(dateStr)){
                    inner.classList.add('available');
                    if(selectedDate===dateStr) inner.classList.add('selected');
                    inner.addEventListener('click',()=>selectDate(dateStr));
                }
                cell.appendChild(inner);grid.appendChild(cell);
            }
            const total=startDay+lastDay;
            const target=42;
            for(let i=1;i<=target-total;i++){
                const cell=document.createElement('div');cell.className='day-cell';
                const inner=document.createElement('div');inner.className='day-inner other-month';
                inner.textContent=i;cell.appendChild(inner);grid.appendChild(cell);
            }
        }

        function selectDate(dateStr){
            selectedDate=dateStr;
            renderCalendar();
            const card=document.getElementById('card');
            card.classList.add('with-times');
            document.getElementById('form-view').classList.remove('active');
            const ts=document.getElementById('times-section');
            ts.classList.add('active');
            const group=groups[dateStr];
            document.getElementById('times-date').textContent=group.label;
            const list=document.getElementById('times-list');
            list.textContent='';
            group.slots.forEach((s,i)=>{
                const row=document.createElement('div');
                row.className='time-slot-row';
                row.style.animationDelay=(i*40)+'ms';
                const btn=document.createElement('button');
                btn.className='time-slot';
                btn.textContent=fmt(s.start);
                const cfm=document.createElement('button');
                cfm.className='confirm-btn';
                cfm.textContent='Confirm';
                cfm.style.display='none';
                btn.addEventListener('click',()=>{
                    document.querySelectorAll('.time-slot').forEach(b=>{b.classList.remove('picked');b.parentElement.querySelector('.confirm-btn').style.display='none';});
                    btn.classList.add('picked');
                    cfm.style.display='block';
                    selectedSlot=s;
                });
                cfm.addEventListener('click',()=>showForm(s,group.label));
                row.appendChild(btn);
                row.appendChild(cfm);
                list.appendChild(row);
            });
        }

        function fmt(t){const[h,m]=t.split(':').map(Number);const s=h>=12?'pm':'am';const h2=h%12||12;return m===0?h2+':00'+s:h2+':'+String(m).padStart(2,'0')+s;}

        function showForm(slot,dayLabel){
            document.getElementById('times-section').classList.remove('active');
            const fv=document.getElementById('form-view');
            fv.classList.add('active');
            document.getElementById('form-meta').textContent=fmt(slot.start)+' \\u2013 '+fmt(slot.end)+', '+dayLabel;
            document.getElementById('f-name').focus();
        }

        document.getElementById('back-btn2').addEventListener('click',()=>{
            document.getElementById('form-view').classList.remove('active');
            document.getElementById('times-section').classList.add('active');
        });

        document.getElementById('schedule-btn').addEventListener('click',async()=>{
            const name=document.getElementById('f-name').value.trim();
            const email=document.getElementById('f-email').value.trim();
            const notes=document.getElementById('f-notes').value.trim();
            if(!name||!email||!selectedSlot)return;
            const btn=document.getElementById('schedule-btn');
            btn.disabled=true;btn.textContent='Scheduling...';
            try{
                const res=await fetch('/api/book',{method:'POST',headers:{'Content-Type':'application/json'},
                    body:JSON.stringify({date:selectedSlot.date,start:selectedSlot.start,name,email,notes:notes||null})});
                if(res.ok){
                    document.getElementById('card').style.display='none';
                    document.getElementById('success-card').style.display='block';
                }else{btn.disabled=false;btn.textContent='Schedule Event';}
            }catch(e){btn.disabled=false;btn.textContent='Schedule Event';}
        });

        init();
        </script>
        </body>
        </html>
        """
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
