public void GunRounds_Assign(ArrayList tPlayers, ArrayList ctPlayers, Bombsite site) {
  bool helpCT = false;
  bool hurtT = false;

  if (g_NumT > g_NumCT) {
    if (Chance(0.5)) {
      hurtT = true;
    } else {
      helpCT = true;
    }
  }

  for (int i = 0; i < tPlayers.Length; i++) {
    AssignT(tPlayers.Get(i), hurtT);
  }

  for (int i = 0; i < ctPlayers.Length; i++) {
    AssignCT(ctPlayers.Get(i), helpCT);
  }
}

static void AssignCT(int client, bool helpCT) {
  int spawn = g_SpawnIndices[client];
  if (helpCT) {
    g_PlayerHelmet[client] = true;
    g_PlayerKit[client] = true;
  } else {
    g_PlayerHelmet[client] = Chance(0.6);
    g_PlayerKit[client] = Chance(0.85);
  }
  AssignCTNades(client, spawn, helpCT);

  if (client == g_CTAwper) {
    // TODO: maybe add a cvar for... 'stupid stuff' like this :)
    if (Chance(0.03)) {
      g_PlayerPrimary[client] = "weapon_scar20";
    } else {
      g_PlayerPrimary[client] = "weapon_awp";
      g_PlayerSecondary[client] = "weapon_p250";
    }

  } else {
    if (Chance(0.02)) {
      g_PlayerPrimary[client] = "weapon_famas";
    } else if (Chance(0.002)) {
      g_PlayerPrimary[client] = "weapon_aug";
    } else if (Chance(0.0005)) {
      g_PlayerPrimary[client] = "weapon_negev";
    } else if (Chance(0.0005)) {
      g_PlayerPrimary[client] = "weapon_m249";
    }

    if (HasFlag(spawn, SPAWNFLAG_MAG7) && Chance(0.15) && !helpCT) {
      g_PlayerPrimary[client] = "weapon_mag7";
    }
  }
}

static void AssignCTNades(int client, int spawn, bool help) {
  int friendliness = g_SpawnSiteFriendly[spawn][g_Bombsite];
  float f = GetRandomFloat();

  if (help) {
    if (friendliness >= 4) {
      if (f < 0.2) {
        g_PlayerNades[client] = "fh";
      } else if (f < 0.25) {
        g_PlayerNades[client] = "s";
      } else if (f < 0.35) {
        g_PlayerNades[client] = "f";
      } else if (f < 0.7) {
        g_PlayerNades[client] = "f";
      } else if (f < 0.72) {
        g_PlayerNades[client] = "i";
      }
    } else {
      if (f < 0.2) {
        g_PlayerNades[client] = "if";
      } else if (f < 0.4) {
        g_PlayerNades[client] = "s";
      } else if (f < 0.5) {
        g_PlayerNades[client] = "fh";
      } else if (f < 0.675) {
        g_PlayerNades[client] = "f";
      }
    }

  } else {
    if (friendliness >= 4) {
      if (f < 0.2) {
        g_PlayerNades[client] = "fh";
      } else if (f < 0.25) {
        g_PlayerNades[client] = "s";
      } else if (f < 0.35) {
        g_PlayerNades[client] = "f";
      } else if (f < 0.75) {
        g_PlayerNades[client] = "f";
      } else if (f < 0.8) {
        g_PlayerNades[client] = "i";
      }

    } else {
      if (f < 0.2) {
        g_PlayerNades[client] = "if";
      } else if (f < 0.4) {
        g_PlayerNades[client] = "s";
      } else if (f < 0.5) {
        g_PlayerNades[client] = "fh";
      } else if (f < 0.7) {
        g_PlayerNades[client] = "f";
      }
    }
  }

  if (Chance(0.2)) {
    g_PlayerNades[client] = "";
  }

  if (HasFlag(spawn, SPAWNFLAG_FLASH && GetRandomFloat() < 0.75)) {
    AddNade(client, "f");
  }

  if (HasFlag(spawn, SPAWNFLAG_SMOKE && GetRandomFloat() < 0.75)) {
    AddNade(client, "s");
  }

  if (HasFlag(spawn, SPAWNFLAG_MOLOTOV && GetRandomFloat() < 0.75)) {
    AddNade(client, "i");
  }
}

static void AssignT(int client, bool hurtT) {
  int spawn = g_SpawnIndices[client];
  AssignTNades(client, spawn, hurtT);

  if (client == g_TAwper) {
    g_PlayerPrimary[client] = "weapon_awp";
    g_PlayerSecondary[client] = "weapon_p250";

  } else if (hurtT) {
    if (Chance(0.06)) {
      g_PlayerPrimary[client] = "weapon_galilar";
    }

  } else {
    if (Chance(0.02)) {
      g_PlayerPrimary[client] = "weapon_galilar";
    } else if (Chance(0.002)) {
      g_PlayerPrimary[client] = "weapon_sg556";
    } else if (Chance(0.002)) {
      g_PlayerPrimary[client] = "weapon_m249";
    }
  }
}

static void AssignTNades(int client, int spawn, bool hurt) {
  float f = GetRandomFloat();
  bool throwingSetNade = IsGrenade(g_SpawnGrenadeTypes[spawn]);

  if (hurt) {
    if (f < 0.15 && !throwingSetNade) {
      g_PlayerNades[client] = "m";
    } else if (f < 0.3 && !throwingSetNade) {
      g_PlayerNades[client] = "s";
    } else if (f < 0.6) {
      g_PlayerNades[client] = "f";
    }

  } else {
    if (f < 0.25) {
      g_PlayerNades[client] = "f";
    } else if (f < 0.4 && !throwingSetNade) {
      g_PlayerNades[client] = "s";
    } else if (f < 0.6 && !throwingSetNade) {
      g_PlayerNades[client] = "m";
    } else if (f < 0.6) {
      g_PlayerNades[client] = "f";
    } else if (f < 0.7) {
      g_PlayerNades[client] = "h";
    } else if (f < 0.76 && !throwingSetNade) {
      g_PlayerNades[client] = "fs";
    } else if (f < 0.82 && !throwingSetNade) {
      g_PlayerNades[client] = "f";
    }

    if (!throwingSetNade && HasFlag(spawn, SPAWNFLAG_MOLOTOV)) {
      if (f < 0.6)
        g_PlayerNades[client] = "m";
      else if (f < 0.8)
        g_PlayerNades[client] = "fm";
      else if (f < 0.9)
        g_PlayerNades[client] = "s";
    }
  }

  if (HasFlag(spawn, SPAWNFLAG_FLASH)) {
    if (f < 0.8) {
      AddNade(client, "f");
    }
  }

  if (!throwingSetNade && HasFlag(spawn, SPAWNFLAG_SMOKE)) {
    if (f < 0.8) {
      AddNade(client, "s");
    }
  }
}
