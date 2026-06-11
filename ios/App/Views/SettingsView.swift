import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(FeedService.self) private var feed
    @Environment(PremiumStore.self) private var premium
    @Query private var prefsList: [AppPrefs]
    @Query private var followed: [FollowedStock]
    @AppStorage("lang") private var lang = "tr"
    @State private var notifGranted = false
    @State private var showPaywall = false

    private var prefs: AppPrefs? { prefsList.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ayarlar").manrope(30, .heavy).padding(.horizontal, 6).padding(.top, 6)

                premiumBanner

                if let prefs { notificationsGroup(prefs) }

                section("Dil")
                group {
                    row {
                        AnyView(label("globe", "Dil"))
                    } trailing: {
                        AnyView(langSeg)
                    }
                }

                section("Veri")
                group {
                    row { AnyView(Text("Son güncelleme").manrope(15.5, .semibold)) }
                        trailing: { AnyView(Text(feed.lastUpdated.map { TRFormat.date($0) } ?? "—").manrope(15.5, .semibold).foregroundStyle(Brand.ink3)) }
                    divider
                    Button { Task { await feed.refresh() } } label: {
                        row { AnyView(label("arrow.clockwise", "Şimdi güncelle", tint: Brand.accent)) } trailing: { AnyView(EmptyView()) }
                    }.buttonStyle(.plain)
                    divider
                    row { AnyView(Text("Sürüm").manrope(15.5, .semibold)) }
                        trailing: { AnyView(Text(appVersion).manrope(15.5, .semibold).foregroundStyle(Brand.ink3)) }
                }

                if !premium.isPremium {
                    Button { Task { await premium.restore() } } label: {
                        Text("Satın alımları geri yükle").manrope(15, .bold).foregroundStyle(Brand.accent)
                            .frame(maxWidth: .infinity).padding(14)
                    }.buttonStyle(.plain)
                }

                Text("Veriler KAP (resmi) ve İş Yatırım kaynaklıdır. Arz Radar bir bilgilendirme aracıdır; yatırım tavsiyesi değildir.")
                    .manrope(13, .medium).foregroundStyle(Brand.ink3).padding(.horizontal, 8).padding(.top, 4)
            }
            .screenPadding()
            .padding(.bottom, 120)
        }
        .background(Brand.screen)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task { notifGranted = await NotificationService.requestAuthorization() }
    }

    private var premiumBanner: some View {
        Group {
            if premium.isPremium {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill").foregroundStyle(.white)
                    Text("Premium aktif — teşekkürler!").manrope(16, .bold).foregroundStyle(.white)
                    Spacer()
                }
                .padding(18)
                .background(LinearGradient(colors: [Brand.accent, Brand.accent2], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Button { showPaywall = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "crown.fill").font(.system(size: 24)).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium’a geç").manrope(18, .heavy).foregroundStyle(.white)
                            Text("Reklamsız + sınırsız takip. Tek seferlik.").manrope(12.5, .medium).foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(18)
                    .background(LinearGradient(colors: [Brand.accent, Color(hex: 0x6470F2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Brand.accent.opacity(0.4), radius: 16, y: 8)
                }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func notificationsGroup(_ prefs: AppPrefs) -> some View {
        @Bindable var prefs = prefs
        section("Bildirimler")
        group {
            row { AnyView(label("sparkles", "Yeni halka arz bildirimi")) } trailing: {
                AnyView(Toggle("", isOn: Binding(
                    get: { prefs.notifyAllIPOs },
                    set: { newValue in
                        guard premium.isPremium else { showPaywall = true; return }
                        prefs.notifyAllIPOs = newValue
                    })).labelsHidden().tint(Brand.accent))
            }
            divider
            row { AnyView(label("bell", "Hatırlatma zamanı")) } trailing: {
                AnyView(Menu {
                    ForEach(0...3, id: \.self) { d in
                        Button(d == 0 ? "Aynı gün" : "\(d) gün önce") { prefs.remindDaysBefore = d }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(prefs.remindDaysBefore == 0 ? "Aynı gün" : "\(prefs.remindDaysBefore) gün önce").manrope(14.5, .bold)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Brand.accent)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Brand.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                })
            }
        }
        Text("Takip ettiğin \(followed.count) hisse için temettü tarihinden önce hatırlatılırsın. Tüm bildirimler cihazında oluşturulur.")
            .manrope(13, .medium).foregroundStyle(Brand.ink3).padding(.horizontal, 8)
    }

    private var langSeg: some View {
        HStack(spacing: 2) {
            ForEach(["tr", "en"], id: \.self) { code in
                Button { lang = code } label: {
                    Text(code.uppercased()).manrope(14, .bold)
                        .foregroundStyle(lang == code ? Brand.accent : Brand.ink2)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(lang == code ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .shadow(color: lang == code ? Brand.ink.opacity(0.1) : .clear, radius: 2, y: 1)
                }.buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Brand.line, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: building blocks

    private func section(_ title: String) -> some View {
        Text(title.uppercased()).manrope(12.5, .bold).foregroundStyle(Brand.ink3)
            .tracking(0.5).padding(.horizontal, 6).padding(.top, 6)
    }

    private func group<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .background(Brand.card)
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Brand.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(@ViewBuilder _ leading: () -> AnyView, @ViewBuilder trailing: () -> AnyView) -> some View {
        HStack { leading(); Spacer(); trailing() }
            .padding(.horizontal, 16).padding(.vertical, 15)
            .contentShape(Rectangle())
    }

    private var divider: some View { Rectangle().fill(Brand.line).frame(height: 1).padding(.leading, 16) }

    private func label(_ icon: String, _ text: String, tint: Color = Brand.accent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint)
            Text(text).manrope(15.5, .semibold).foregroundStyle(tint == Brand.accent ? Brand.ink : tint)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
