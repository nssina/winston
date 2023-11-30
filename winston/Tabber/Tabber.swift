//
//  Tabber.swift
//  winston
//
//  Created by Igor Marcossi on 24/06/23.
//

import SwiftUI
import Defaults
import SpriteKit


class TempGlobalState: ObservableObject {
  static var shared = TempGlobalState()
  @Published var editingCredential: RedditCredential? = nil
  @Published var globalLoader = GlobalLoader()
  @Published var tabBarHeight: CGFloat? = nil
  @Published var inAppBrowserURL: URL? = nil
}

enum TabIdentifier {
  case posts, inbox, me, search, settings
}

class TabPayload: ObservableObject {
  @Published var reset = false
  var router = Router(id: "FeedThemingPanel")
  
  init(_ id: String, reset: Bool = false) {
    self.reset = reset
    self.router = Router(id: id)
  }
}

class GlobalNavPathWrapper: ObservableObject {
  @Published var path = NavigationPath()
}

struct Tabber: View, Equatable {
  static func == (lhs: Tabber, rhs: Tabber) -> Bool { true }
  
  @ObservedObject private var tempGlobalState = TempGlobalState.shared
  @ObservedObject private var redditCredentialsManager = RedditCredentialsManager.shared
  @State private var activeTab: TabIdentifier = .posts
  
  @State private var credModalOpen = false
  @State private var importedThemeAlert = false
  
  //  @State var tabBarHeight: CGFloat?
  @StateObject private var inboxPayload = TabPayload("inboxRouter")
  @StateObject private var mePayload = TabPayload("meRouter")
  @StateObject private var postsPayload = TabPayload("postsRouter")
  @StateObject private var searchPayload = TabPayload("searchRouter")
  @StateObject private var settingsPayload = TabPayload("settingsRouter")
  @Environment(\.useTheme) private var currentTheme
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject var themeStoreAPI: ThemeStoreAPI
  @Default(.showUsernameInTabBar) private var showUsernameInTabBar
  @Default(.showTipJarModal) private var showTipJarModal
  
  
  @State var sharedTheme: ThemeData? = nil
  @State var showingSharedThemeSheet: Bool = false
  
  @State var showingAnnouncement: Bool = false
  @State var testAnnouncement: Announcement? = nil
  @EnvironmentObject var winstonAPI: WinstonAPI
  
  var payload: [TabIdentifier:TabPayload] { [
    .inbox: inboxPayload,
    .me: mePayload,
    .posts: postsPayload,
    .search: searchPayload,
    .settings: settingsPayload,
  ] }
  
  func meTabTap() {
    if activeTab == .me {
      payload[.me]!.reset.toggle()
    } else {
      activeTab = .me
    }
  }
  
  init(theme: WinstonTheme, cs: ColorScheme) {
    // MANDRAKE
    // _activeTab = State(initialValue: activeTab) // Initialize activeTab
    Tabber.updateTabAndNavBar(tabTheme: theme.general.tabBarBG, navTheme: theme.general.navPanelBG, cs)
  }
  
  static func updateTabAndNavBar(tabTheme: ThemeForegroundBG, navTheme: ThemeForegroundBG, _ cs: ColorScheme) {
    let toolbarAppearence = UINavigationBarAppearance()
    if !navTheme.blurry {
      toolbarAppearence.configureWithOpaqueBackground()
    }
    toolbarAppearence.backgroundColor = UIColor(navTheme.color.cs(cs).color())
    UINavigationBar.appearance().standardAppearance = toolbarAppearence
    let transparentAppearence = UITabBarAppearance()
    if !tabTheme.blurry {
      transparentAppearence.configureWithOpaqueBackground()
    }
    transparentAppearence.backgroundColor = UIColor(tabTheme.color.cs(cs).color())
    UITabBar.appearance().standardAppearance = transparentAppearence
  }
  
  var body: some View {
    let tabBarHeight = tempGlobalState.tabBarHeight
    let tabHeight = (tabBarHeight ?? 0) - getSafeArea().bottom
    TabView(selection: $activeTab.onUpdate { newTab in if activeTab == newTab { payload[newTab]!.reset.toggle() } }) {
      
      SubredditsStack(reset: payload[.posts]!.reset, router: payload[.posts]!.router)
        .background(TabBarAccessor { tabBar in
          if tabBarHeight != tabBar.bounds.height { tempGlobalState.tabBarHeight = tabBar.bounds.height }
        })
        .tag(TabIdentifier.posts)
        .tabItem {
          VStack {
            Image(systemName: "doc.text.image")
            Text("Posts")
          }
        }
      
      Inbox(reset: payload[.inbox]!.reset, router: payload[.inbox]!.router)
        .background(TabBarAccessor { tabBar in
          if tabBarHeight != tabBar.bounds.height { tempGlobalState.tabBarHeight = tabBar.bounds.height }
        })
        .tag(TabIdentifier.inbox)
        .tabItem {
          VStack {
            Image(systemName: "bell.fill")
            Text("Inbox")
          }
        }
      
      Me(reset: payload[.me]!.reset, router: payload[.me]!.router)
        .background(TabBarAccessor { tabBar in
          if tabBarHeight != tabBar.bounds.height { tempGlobalState.tabBarHeight = tabBar.bounds.height }
        })
        .tag(TabIdentifier.me)
        .tabItem {
          VStack {
            Image(systemName: "person.fill")
            if showUsernameInTabBar, let me = RedditAPI.shared.me, let data = me.data {
              Text(data.name)
            } else {
              Text("Me")
            }
          }
        }
      
      Search(reset: payload[.search]!.reset, router: payload[.search]!.router)
        .background(TabBarAccessor { tabBar in
          if tabBarHeight != tabBar.bounds.height { tempGlobalState.tabBarHeight = tabBar.bounds.height }
        })
        .tag(TabIdentifier.search)
        .tabItem {
          VStack {
            Image(systemName: "magnifyingglass")
            Text("Search")
          }
        }
      
      Settings(reset: payload[.settings]!.reset, router: payload[.settings]!.router)
        .background(TabBarAccessor { tabBar in
          if tabBarHeight != tabBar.bounds.height { tempGlobalState.tabBarHeight = tabBar.bounds.height }
        })
        .tag(TabIdentifier.settings)
        .tabItem {
          VStack {
            Image(systemName: "gearshape.fill")
            Text("Settings")
          }
        }
      
    }
    .sheet(item: $tempGlobalState.editingCredential) { cred in
      CredentialView(credential: cred)
    }
    .replyModalPresenter(routerProxy: RouterProxy(payload[activeTab]!.router))
    .overlay(
      GeometryReader { geo in
        GlobalLoaderView()
          .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
      }
        .ignoresSafeArea(.keyboard)
      , alignment: .bottom
    )
    .overlay(
      tabBarHeight == nil
      ? nil
      : TabBarOverlay(router: payload[activeTab]!.router, tabHeight: tabHeight, meTabTap: meTabTap).id(payload[activeTab]!.router.id)
      , alignment: .bottom
    )
    .background(OFWOpener(router: payload[TabIdentifier.posts]!.router))
    .fullScreenCover(isPresented: Binding(get: { tempGlobalState.inAppBrowserURL != nil }, set: { val in
      tempGlobalState.inAppBrowserURL = nil
    })) {
      if let url = tempGlobalState.inAppBrowserURL {
        SafariWebView(url: url)
          .ignoresSafeArea()
      }
    }
    .environmentObject(tempGlobalState)
    .alert("Success!", isPresented: $importedThemeAlert) {
      Button("Nice!", role: .cancel) {
        importedThemeAlert = false
      }
    } message: {
      Text("The theme was imported successfully. Enable it in \"Themes\" section in the Settings tab.")
    }
    .onAppear {
      removeDefaultThemeFromThemes()
      
      removeLegacySubsAndMultisCache()
      
      Task(priority: .background) { await updatePostsInBox(RedditAPI.shared) }
      
      if redditCredentialsManager.credentials.count == 0 {
        withAnimation(spring) {
          credModalOpen = true
        }
      } else if redditCredentialsManager.selectedCredential != nil {
        Task(priority: .background) {
          await RedditAPI.shared.fetchMe(force: true)
        }
      }
      
      //Check for announcements
      Task(priority: .background){
        testAnnouncement = await winstonAPI.getAnnouncement()
        if let testAnnouncement{
          showingAnnouncement = testAnnouncement.timestamp != Defaults[.lastSeenAnnouncementTimeStamp]
        } else {
          showingAnnouncement = false
        }
      }
      
    }
    .onChange(of: redditCredentialsManager.credentials) { creds in
      if creds.count == 0 {
        withAnimation(spring) {
          credModalOpen = true
        }
      }
    }
    .sheet(isPresented: $showingAnnouncement, content: {
      if let testAnnouncement {
        AnnouncementSheet(showingAnnouncement: $showingAnnouncement,announcement: testAnnouncement)
      } else {
        ProgressView()
      }
    })
    .sheet(isPresented: $showingSharedThemeSheet, content: {
      if let theme = sharedTheme {
        ThemeStoreDetailsView(themeData: theme)
      } else {
        HStack {
          VStack{
            ProgressView()
          }
        }
      }
    })
    .onOpenURL { url in
      
      if let queryParams = url.queryParameters, let appID = queryParams["appID"], let appSecret = queryParams["appSecret"] {
        credModalOpen = false
        if let foundCred = redditCredentialsManager.credentials.first(where: { $0.apiAppID == appID }) {
          tempGlobalState.editingCredential = foundCred
        } else {
          tempGlobalState.editingCredential = .init(apiAppID: appID, apiAppSecret: appSecret)
        }
      }
      
      if url.absoluteString.contains("winstonapp://theme/") {
        let themeID = url.lastPathComponent
        Task {
          sharedTheme = await themeStoreAPI.fetchThemeByID(id: themeID)
          showingSharedThemeSheet.toggle()
        }
      }
      
      if url.absoluteString.hasSuffix(".winston") || url.absoluteString.hasSuffix(".zip") {
        TempGlobalState.shared.globalLoader.enable("Importing...")
        let result = importTheme(at: url)
        TempGlobalState.shared.globalLoader.dismiss()
        if result {
          importedThemeAlert = true
        }
        return
      }
      let parsed = parseRedditURL(url.absoluteString)
      withAnimation {
        switch parsed {
        case .post(_, _):
          OpenFromWeb.shared.data = parsed
          activeTab = .posts
        case .subreddit(_):
          OpenFromWeb.shared.data = parsed
          activeTab = .posts
        case .user(_):
          OpenFromWeb.shared.data = parsed
          activeTab = .posts
        default:
          break
        }
      }
    }
    .sheet(isPresented: $showTipJarModal) {
      TipJar()
    }
    .sheet(isPresented: $credModalOpen) {
      Onboarding(open: $credModalOpen)
        .interactiveDismissDisabled(true)
    }
    .accentColor(currentTheme.general.accentColor.cs(colorScheme).color())
    //    .id(currentTheme.general.tabBarBG)
  }
}


struct BlurRadialGradientView: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    addBlurWithGradient(view: view)
    return view
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
  }
  
  private func addBlurWithGradient(view: UIView) {
    let gradient = CAGradientLayer()
    gradient.frame = view.bounds
    gradient.colors = [UIColor.blue.cgColor, UIColor.blue.withAlphaComponent(0.0).cgColor]
    gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
    gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
    gradient.locations = [0, 1]
    
    let blurEffect = UIBlurEffect.init(style: .systemMaterial)
    let visualEffectView = UIVisualEffectView.init(effect: blurEffect)
    visualEffectView.frame = gradient.bounds
    
    gradient.mask = visualEffectView.layer
    view.layer.addSublayer(gradient)
  }
}

struct TabBarAccessor: UIViewControllerRepresentable {
  var callback: (UITabBar) -> Void
  private let proxyController = ViewController()
  
  func makeUIViewController(context: UIViewControllerRepresentableContext<TabBarAccessor>) ->
  UIViewController {
    proxyController.callback = callback
    return proxyController
  }
  
  func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<TabBarAccessor>) {
  }
  
  typealias UIViewControllerType = UIViewController
  
  private class ViewController: UIViewController {
    var callback: (UITabBar) -> Void = { _ in }
    
    override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      if let tabBar = self.tabBarController {
        Task(priority: .background) {
          self.callback(tabBar.tabBar)
        }
      }
    }
  }
}