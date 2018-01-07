stock void AssignRandomNades(int client, int strength = 1) {
  char buffer[NADE_STRING_LENGTH];
  int idx = 0;
  while (strength > 0) {
    char c = RandomNade();
    buffer[idx] = c;
    strength -= NadeStrength(c);
    idx++;
  }
  buffer[idx] = '\0';

  g_PlayerNades[client] = buffer;
}

public int NadeStrength(char c) {
  switch (c) {
    case 'f':
      return 1;
    case 'h':
      return 1;
    case 's':
      return 2;
    case 'i':
      return 2;
    case 'm':
      return 2;
  }
  return 0;
}

public char RandomNade() {
  float f = GetRandomFloat();
  if (f < 0.5) {
    // TODO: why the view_as here?
    return view_as<char>('f');
  } else if (f < 0.55) {
    return view_as<char>('h');
  } else if (f < 0.8) {
    return view_as<char>('s');
  } else {
    return view_as<char>('m');
  }
}

//
public void GiveUpgradedSecondary(int client, int team) {
  if (team == CS_TEAM_CT) {
    if (g_CZCTSide[client]) {
      g_PlayerSecondary[client] = "weapon_cz75a";
    } else {
      g_PlayerSecondary[client] = "weapon_fiveseven";
    }
  } else {
    if (g_CZTSide[client]) {
      g_PlayerSecondary[client] = "weapon_cz75a";
    } else {
      g_PlayerSecondary[client] = "weapon_tec9";
    }
  }
}

public void AddNade(int client, const char[] nade) {
  if (!StrContains(g_PlayerNades[client], nade)) {
    StrCat(g_PlayerNades[client], NADE_STRING_LENGTH, nade);
  }
}
