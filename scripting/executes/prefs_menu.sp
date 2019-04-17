public void GivePreferencesMenu(int client) {
  Menu menu = new Menu(PreferencesMenuHandler);
  char buffer[128];

  menu.SetTitle("Select weapon preferences");

  buffer = "M4 choice: M4A4";
  if (g_SilencedM4[client])
    buffer = "M4 choice: M4A1-S";
  menu.AddItem("silenced_m4", buffer);

  buffer = "Allow receiving awps: no";
  if (g_AllowAWP[client])
    buffer = "Allow receiving awps: yes";
  menu.AddItem("allow_awp", buffer);

  char choice[8];
  switch (g_SitePreference[client]) {
    case SitePref_A:
      choice = "A";
    case SitePref_B:
      choice = "B";
    case SitePref_Mid:
      choice = "Mid";
    default:
      choice = "none";
  }
  Format(buffer, sizeof(buffer), "CT site preference: %s", choice);
  menu.AddItem("site_pref", buffer);

  buffer = "CZ/Five-Seven choice: Five-Seven";
  if (g_CZCTSide[client]) {
    buffer = "CZ/Five-Seven choice: CZ";
  }
  menu.AddItem("cz_ct", buffer);

  buffer = "CZ/Tec9 choice: Tec9";
  if (g_CZTSide[client]) {
    buffer = "CZ/Tec9 choice: CZ";
  }
  menu.AddItem("cz_t", buffer);

  menu.Display(client, 15);
}

public int PreferencesMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char choice[64];
    menu.GetItem(param2, choice, sizeof(choice));

    if (StrEqual(choice, "silenced_m4")) {
      g_SilencedM4[client] = !g_SilencedM4[client];
      SetCookieBool(client, g_SilencedM4Cookie, g_SilencedM4[client]);
      GivePreferencesMenu(client);

    } else if (StrEqual(choice, "allow_awp")) {
      g_AllowAWP[client] = !g_AllowAWP[client];
      SetCookieBool(client, g_AllowAWPCookie, g_AllowAWP[client]);
      GivePreferencesMenu(client);

    } else if (StrEqual(choice, "site_pref")) {
      if (g_SitePreference[client] == SitePref_A)
        g_SitePreference[client] = SitePref_B;
      else if (g_SitePreference[client] == SitePref_B)
        g_SitePreference[client] = SitePref_Mid;
      else if (g_SitePreference[client] == SitePref_Mid)
        g_SitePreference[client] = SitePref_None;
      else
        g_SitePreference[client] = SitePref_A;

      SetSitePrefCookie(client, g_SitePreference[client]);
      GivePreferencesMenu(client);

    } else if (StrEqual(choice, "cz_ct")) {
      g_CZCTSide[client] = !g_CZCTSide[client];
      SetCookieBool(client, g_CZCTSideCookie, g_CZCTSide[client]);
      GivePreferencesMenu(client);

    } else if (StrEqual(choice, "cz_t")) {
      g_CZTSide[client] = !g_CZTSide[client];
      SetCookieBool(client, g_CZTSideCookie, g_CZTSide[client]);
      GivePreferencesMenu(client);

    } else {
      LogError("unknown pref string = %s", choice);
    }

  } else if (action == MenuAction_End) {
    delete menu;
  }
}

public void OnClientCookiesCached(int client) {
  if (IsFakeClient(client))
    return;

  g_AllowAWP[client] = GetCookieBool(client, g_AllowAWPCookie);
  g_SilencedM4[client] = GetCookieBool(client, g_SilencedM4Cookie);
  g_SitePreference[client] = GetSitePrefCookie(client);
  g_CZCTSide[client] = GetCookieBool(client, g_CZCTSideCookie, true);
  g_CZTSide[client] = GetCookieBool(client, g_CZTSideCookie, true);
}

public void SetSitePrefCookie(int client, SitePref site) {
  char mapName[32];
  GetCleanMapName(mapName, sizeof(mapName));
  char cookieName[128];
  Format(cookieName, sizeof(cookieName), "exec_%s_ct_site", mapName);
  SetCookieIntByName(client, cookieName, view_as<int>(site));
}

public SitePref GetSitePrefCookie(int client) {
  char mapName[32];
  GetCleanMapName(mapName, sizeof(mapName));
  char cookieName[128];
  Format(cookieName, sizeof(cookieName), "exec_%s_ct_site", mapName);
  return view_as<SitePref>(GetCookieIntByName(client, cookieName));
}
