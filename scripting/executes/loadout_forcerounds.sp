public void ForceRounds_Assign(ArrayList tPlayers, ArrayList ctPlayers, Bombsite site) {
  for (int i = 0; i < tPlayers.Length; i++) {
    AssignT(tPlayers.Get(i));
  }

  for (int i = 0; i < ctPlayers.Length; i++) {
    AssignCT(ctPlayers.Get(i));
  }
}

static void AssignCT(int client) {
  int spawn = g_SpawnIndices[client];
  g_PlayerHelmet[client] = true;
  g_PlayerKit[client] = true;

  AssignCTNades(client, spawn);

  if (client == g_CTAwper) {
    g_PlayerPrimary[client] = "weapon_awp";
    g_PlayerSecondary[client] = "weapon_p250";

  } else {
    float f = GetRandomFloat();
    if (f < 0.1) {
      g_PlayerPrimary[client] = "weapon_famas";
      AssignRandomNades(client, 1);

    } else if (f < 0.2) {
      g_PlayerPrimary[client] = "weapon_mp9";
      AssignRandomNades(client, 2);

    } else if (f < 0.3) {
      g_PlayerPrimary[client] = "weapon_mp7";
      AssignRandomNades(client, 2);

    } else if (f < 0.4) {
      g_PlayerPrimary[client] = "weapon_m4a1";
      AssignRandomNades(client, 0);

    } else if (f < 0.5) {
      GiveUpgradedSecondary(client, CS_TEAM_CT);
      AssignRandomNades(client, 2);

    } else if (f < 0.6) {
      g_PlayerPrimary[client] = "weapon_famas";
      AssignRandomNades(client, 1);

    } else if (f < 0.7) {
      g_PlayerPrimary[client] = "weapon_ump45";
      AssignRandomNades(client, 1);

    } else if (f < 0.8) {
      g_PlayerPrimary[client] = "weapon_ump45";
      AssignRandomNades(client, 2);
    } else if (f < 0.87) {
      g_PlayerPrimary[client] = "weapon_p90";
      AssignRandomNades(client, 1);

    } else {
      g_PlayerPrimary[client] = "weapon_famas";
      AssignRandomNades(client, 1);
    }

    // Alternate distribution for close spawns
    if (g_SpawnAwpFriendly[spawn] <= 2) {
      f = GetRandomFloat();
      if (f < 0.55) {
        g_PlayerPrimary[client] = "weapon_ump45";
        AssignRandomNades(client, 2);
      } else if (f < 0.7) {
        g_PlayerPrimary[client] = "weapon_p90";
        AssignRandomNades(client, 0);
      } else {
        g_PlayerPrimary[client] = "weapon_mp9";
        AssignRandomNades(client, 2);
      }
    }

    if (HasFlag(spawn, SPAWNFLAG_MAG7) && Chance(0.2)) {
      g_PlayerPrimary[client] = "weapon_mag7";
      if (Chance(0.1)) {
        g_PlayerPrimary[client] = "weapon_p90";
      }
    }

    if (StrEqual(g_PlayerPrimary[client], "weapon_m4a1") && g_SilencedM4[client]) {
      g_PlayerPrimary[client] = "weapon_m4a1_silencer";
    }

    if (StrEqual(g_LastItemPickup[client], "ak47")) {
      g_PlayerPrimary[client] = "weapon_ak47";
    }
  }
}

static void AssignCTNades(int client, int spawn) {
  int friendliness = g_SpawnSiteFriendly[spawn][g_Bombsite];
  float f = GetRandomFloat();

  if (friendliness >= 4) {
    if (f < 0.3) {
      g_PlayerNades[client] = "f";
    } else if (f < 0.25) {
      g_PlayerNades[client] = "s";
    } else if (f < 0.35) {
      g_PlayerNades[client] = "h";
    } else if (f < 0.42) {
      g_PlayerNades[client] = "f";
    } else if (f < 0.45) {
      g_PlayerNades[client] = "i";
    }

  } else {
    if (f < 0.2) {
      g_PlayerNades[client] = "f";
    } else if (f < 0.3) {
      g_PlayerNades[client] = "s";
    } else if (f < 0.4) {
      g_PlayerNades[client] = "h";
    } else if (f < 0.5) {
      g_PlayerNades[client] = "f";
    } else if (f < 0.6) {
      g_PlayerNades[client] = "i";
    }
  }

  if (HasFlag(spawn, SPAWNFLAG_FLASH && GetRandomFloat() < 0.5)) {
    AddNade(client, "f");
  }

  if (HasFlag(spawn, SPAWNFLAG_SMOKE && GetRandomFloat() < 0.5)) {
    AddNade(client, "s");
  }

  if (HasFlag(spawn, SPAWNFLAG_MOLOTOV && GetRandomFloat() < 0.5)) {
    AddNade(client, "i");
  }
}

static void AssignT(int client) {
  float f = GetRandomFloat();
  if (f < 0.1) {
    g_PlayerPrimary[client] = "weapon_ak47";
    g_PlayerNades[client] = "f";
  } else if (f < 0.3) {
    g_PlayerPrimary[client] = "weapon_ak47";
    g_PlayerNades[client] = "";

  } else if (f < 0.35) {
    g_PlayerPrimary[client] = "weapon_galilar";
    g_PlayerNades[client] = "m";

  } else if (f < 0.5) {
    g_PlayerPrimary[client] = "weapon_ump45";
    g_PlayerNades[client] = "f";

  } else if (f < 0.8) {
    g_PlayerPrimary[client] = "";
    GiveUpgradedSecondary(client, CS_TEAM_T);
    g_PlayerNades[client] = "fm";

  } else {
    g_PlayerPrimary[client] = "";
    GiveUpgradedSecondary(client, CS_TEAM_T);
    g_PlayerNades[client] = "f";
  }
}
