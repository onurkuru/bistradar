import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(FeedService.self) private var feed
    @Query private var prefsList: [AppPrefs]
    @Query private var followed: [FollowedStock]
    @State private var notifGranted = false

    private var prefs: AppPrefs? { prefsList.first }

    var body: some View {
        Form {
            if let prefs {
                bindablePrefs(prefs)
            }

            Section {
                LabeledContent("Son güncelleme", value: feed.lastUpdated.map { TRFormat.date($0) } ?? "—")
                Button {
                    Task { await feed.refresh() }
                } label: {
                    if feed.isLoading {
                        HStack { ProgressView(); Text("Güncelleniyor…") }
                    } else {
                        Label("Şimdi güncelle", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(feed.isLoading)
            } header: {
                Text("Veri")
            } footer: {
                if let err = feed.lastError {
                    Text("Güncelleme hatası: \(err)")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                LabeledContent("Sürüm", value: appVersion)
            } footer: {
                Text("Veriler KAP (resmi) ve İş Yatırım kaynaklıdır. BIST Radar bir bilgilendirme aracıdır; yatırım tavsiyesi değildir.")
            }
        }
        .navigationTitle("Ayarlar")
        .task {
            notifGranted = await NotificationService.requestAuthorization()
        }
    }

    @ViewBuilder
    private func bindablePrefs(_ prefs: AppPrefs) -> some View {
        @Bindable var prefs = prefs
        Section {
            Toggle(isOn: $prefs.notifyAllIPOs) {
                Label("Yeni halka arz bildirimi", systemImage: "sparkles")
            }
            Picker(selection: $prefs.remindDaysBefore) {
                Text("Aynı gün").tag(0)
                Text("1 gün önce").tag(1)
                Text("2 gün önce").tag(2)
                Text("3 gün önce").tag(3)
            } label: {
                Label("Hatırlatma zamanı", systemImage: "bell.badge")
            }
        } header: {
            Text("Bildirimler")
        } footer: {
            Text(notifGranted
                 ? "Takip ettiğin \(followed.count) hisse için temettü hak kullanım tarihinden önce hatırlatılırsın. Tüm bildirimler cihazında oluşturulur."
                 : "Bildirimlere izin verilmedi. Ayarlar > BIST Radar üzerinden açabilirsin.")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
