import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(FeedService.self) private var feed
    @Environment(PremiumStore.self) private var premium
    @Query private var prefsList: [AppPrefs]
    @Query private var followed: [FollowedStock]
    @State private var notifGranted = false
    @State private var showPaywall = false

    private var prefs: AppPrefs? { prefsList.first }

    var body: some View {
        Form {
            premiumSection

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
                Text("Veriler KAP (resmi) ve İş Yatırım kaynaklıdır. Arz Radar bir bilgilendirme aracıdır; yatırım tavsiyesi değildir.")
            }
        }
        .navigationTitle("Ayarlar")
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task {
            notifGranted = await NotificationService.requestAuthorization()
        }
    }

    @ViewBuilder
    private var premiumSection: some View {
        Section {
            if premium.isPremium {
                Label {
                    Text("Premium aktif — teşekkürler!").font(.body.weight(.medium))
                } icon: {
                    Image(systemName: "crown.fill").foregroundStyle(Brand.accent)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title3).foregroundStyle(Brand.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium’a geç")
                                .font(.body.weight(.semibold)).foregroundStyle(.primary)
                            Text("Reklamsız + sınırsız takip. Tek seferlik.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                Button("Satın alımları geri yükle") { Task { await premium.restore() } }
            }
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
                 : "Bildirimlere izin verilmedi. Ayarlar > Arz Radar üzerinden açabilirsin.")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
